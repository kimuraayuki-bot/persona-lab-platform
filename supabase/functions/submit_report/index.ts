import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const RATE_LIMIT_COUNT = 5;
const RATE_LIMIT_WINDOW_MS = 1000 * 60 * 30;
const VALID_SOURCES = new Set(["web_ranking", "web_quiz", "ios_ranking", "ios_quiz", "ios_result"]);
const VALID_REASONS = new Set(["illegal", "sexual", "violent", "harassment", "copyright", "spam", "other"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const quizPublicID = normalizeText(body.quiz_public_id, 120);
    const source = normalizeText(body.source, 32);
    const reason = normalizeText(body.reason, 32);
    const details = normalizeText(body.details, 1000);
    const reporterEmail = normalizeText(body.reporter_email, 160);
    const pageURL = normalizeText(body.page_url, 400);
    const appVersion = normalizeText(body.app_version, 40);

    if (!quizPublicID || !VALID_SOURCES.has(source) || !VALID_REASONS.has(reason)) {
      return json({ error: "quiz_public_id, source, reason are required" }, 400);
    }

    const fingerprint = req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "unknown";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, supabaseService);

    if (await isRateLimited(admin, fingerprint)) {
      return json({ error: "too many reports" }, 429);
    }

    const { data: quiz, error: quizError } = await admin
      .from("quizzes")
      .select("id, public_id")
      .eq("public_id", quizPublicID)
      .single();

    if (quizError || !quiz) {
      return json({ error: "quiz not found" }, 404);
    }

    const { error: insertError } = await admin.from("quiz_reports").insert({
      quiz_id: quiz.id,
      quiz_public_id: quiz.public_id,
      source,
      reason,
      details,
      reporter_email: reporterEmail || null,
      page_url: pageURL || null,
      app_version: appVersion || null,
      fingerprint,
    });

    if (insertError) {
      return json({ error: insertError.message }, 500);
    }

    return json({ ok: true }, 200);
  } catch (error) {
    return json({ error: `${error}` }, 500);
  }
});

async function isRateLimited(admin: ReturnType<typeof createClient>, fingerprint: string): Promise<boolean> {
  const now = Date.now();
  const { data: row } = await admin
    .from("report_rate_limits")
    .select("fingerprint, submitted_count, window_started_at")
    .eq("fingerprint", fingerprint)
    .maybeSingle();

  if (!row) {
    await admin.from("report_rate_limits").insert({
      fingerprint,
      submitted_count: 1,
      window_started_at: new Date(now).toISOString(),
    });
    return false;
  }

  const windowStart = new Date(row.window_started_at).getTime();
  if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
    await admin.from("report_rate_limits").update({
      submitted_count: 1,
      window_started_at: new Date(now).toISOString(),
      updated_at: new Date(now).toISOString(),
    }).eq("fingerprint", fingerprint);
    return false;
  }

  if (Number(row.submitted_count) >= RATE_LIMIT_COUNT) {
    return true;
  }

  await admin.from("report_rate_limits").update({
    submitted_count: Number(row.submitted_count) + 1,
    updated_at: new Date(now).toISOString(),
  }).eq("fingerprint", fingerprint);

  return false;
}

function normalizeText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim().slice(0, maxLength);
}

function json(payload: unknown, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
