// Supabase Edge Function: send FCM push when a knock is inserted.
// Trigger via Database Webhook on table "knocks", event INSERT.
// Requires env: FIREBASE_SERVICE_ACCOUNT_JSON (full JSON string of Firebase service account key),
// and SUPABASE_SERVICE_ROLE_KEY (Supabase auto-injects this when deployed).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_V1_URL = "https://fcm.googleapis.com/v1/projects";

interface WebhookPayload {
  type: string;
  table: string;
  schema: string;
  record: {
    id?: string;
    sender_id: string;
    receiver_id: string;
    message: string;
    created_at?: string;
  };
  old_record: null;
}

interface ProfilesRow {
  id: string;
  fcm_token: string | null;
  display_name: string | null;
}

async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const account = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: account.client_email,
    sub: account.client_email,
    // Required scope for Firebase Cloud Messaging HTTP v1 API
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const header = { alg: "RS256", typ: "JWT" };
  const encoder = new TextEncoder();
  const b64 = (b: Uint8Array) =>
    btoa(String.fromCharCode(...b))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  const part1 = b64(encoder.encode(JSON.stringify(header)));
  const part2 = b64(encoder.encode(JSON.stringify(payload)));
  const toSign = encoder.encode(`${part1}.${part2}`);

  const pem = account.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    toSign
  );
  const part3 = b64(new Uint8Array(signature));
  const jwt = `${part1}.${part2}.${part3}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) {
    const t = await tokenRes.text();
    throw new Error(`Google token error: ${tokenRes.status} ${t}`);
  }
  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

async function sendFcm(
  projectId: string,
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string
): Promise<void> {
  const url = `${FCM_V1_URL}/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        android: {
          priority: "high",
          notification: {
            channel_id: "knock_channel",
            notification_priority: "PRIORITY_MAX",
            default_sound: true,
            default_vibrate_timings: true,
          },
        },
      },
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`FCM error: ${res.status} ${t}`);
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload: WebhookPayload = await req.json();
    if (payload.type !== "INSERT" || payload.table !== "knocks") {
      return new Response(
        JSON.stringify({ ok: true, skipped: "not a knock insert" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const { sender_id, receiver_id, message } = payload.record;
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    if (!serviceAccountJson) {
      console.error("FIREBASE_SERVICE_ACCOUNT_JSON not set");
      return new Response(
        JSON.stringify({ error: "Server config: FIREBASE_SERVICE_ACCOUNT_JSON missing" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const [{ data: receiverProfile }, { data: senderProfile }] = await Promise.all([
      supabase.from("profiles").select("fcm_token").eq("id", receiver_id).single(),
      supabase.from("profiles").select("display_name").eq("id", sender_id).single(),
    ]);

    const fcmToken = (receiverProfile as ProfilesRow | null)?.fcm_token;
    if (!fcmToken || typeof fcmToken !== "string") {
      return new Response(
        JSON.stringify({ ok: true, skipped: "receiver has no fcm_token" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const senderName =
      (senderProfile as { display_name?: string } | null)?.display_name ?? "Someone";
    const projectId = JSON.parse(serviceAccountJson).project_id;
    const accessToken = await getGoogleAccessToken(serviceAccountJson);
    await sendFcm(
      projectId,
      accessToken,
      fcmToken,
      `Knock from ${senderName}`,
      message
    );

    return new Response(JSON.stringify({ ok: true, sent: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
