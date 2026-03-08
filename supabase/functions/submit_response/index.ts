import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { decodeResultCode, normalizeAxisDefinitions, type AxisDefinition } from "../_shared/mbti.ts";

const RATE_LIMIT_COUNT = 20;
const RATE_LIMIT_WINDOW_MS = 1000 * 60 * 10;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, supabaseService);

    const body = await req.json();
    const quizPublicID = body.quiz_public_id as string | undefined;
    const token = body.token as string | undefined;
    const answers = body.answers as Array<{ question_id: string; choice_id: string }> | undefined;

    if (!quizPublicID || !token || !answers || answers.length === 0) {
      return json({ error: "quiz_public_id, token, answers are required" }, 400);
    }

    const fingerprint = req.headers.get("x-forwarded-for") ?? "unknown";
    const limited = await isRateLimited(admin, fingerprint);
    if (limited) {
      return json({ error: "too many requests" }, 429);
    }

    const { data: quiz, error: quizError } = await admin
      .from("quizzes")
      .select("id, public_id")
      .eq("public_id", quizPublicID)
      .single();

    if (quizError || !quiz) {
      return json({ error: "quiz not found" }, 404);
    }

    const tokenHash = await sha256(token);
    const { data: shareLink, error: linkError } = await admin
      .from("share_links")
      .select("id, expires_at")
      .eq("quiz_id", quiz.id)
      .eq("token_hash", tokenHash)
      .single();

    if (linkError || !shareLink) {
      return json({ error: "invalid token" }, 403);
    }

    if (shareLink.expires_at && new Date(shareLink.expires_at).getTime() < Date.now()) {
      return json({ error: "token expired" }, 403);
    }

    const { data: questions, error: questionError } = await admin
      .from("questions")
      .select("id")
      .eq("quiz_id", quiz.id)
      .order("order_index", { ascending: true });

    if (questionError || !questions) {
      return json({ error: "questions not found" }, 500);
    }

    if (answers.length !== questions.length) {
      return json({ error: "answer count mismatch" }, 400);
    }

    const questionIDs = new Set(questions.map((q) => q.id as string));
    if (new Set(answers.map((a) => a.question_id)).size !== answers.length) {
      return json({ error: "duplicated answers" }, 400);
    }

    for (const answer of answers) {
      if (!questionIDs.has(answer.question_id)) {
        return json({ error: "invalid question_id" }, 400);
      }
    }

    const answerChoiceIDs = answers.map((a) => a.choice_id);
    const { data: choices, error: choiceError } = await admin
      .from("choices")
      .select("id, question_id, ei_delta, sn_delta, tf_delta, jp_delta")
      .in("id", answerChoiceIDs);

    if (choiceError || !choices || choices.length !== answers.length) {
      return json({ error: "invalid choice_id" }, 400);
    }

    const choiceMap = new Map(choices.map((c) => [c.id as string, c]));

    let ei = 0;
    let sn = 0;
    let tf = 0;
    let jp = 0;

    for (const answer of answers) {
      const choice = choiceMap.get(answer.choice_id);
      if (!choice || choice.question_id !== answer.question_id) {
        return json({ error: "choice does not belong to question" }, 400);
      }
      ei += Number(choice.ei_delta ?? 0);
      sn += Number(choice.sn_delta ?? 0);
      tf += Number(choice.tf_delta ?? 0);
      jp += Number(choice.jp_delta ?? 0);
    }

    const { data: axisRows, error: axisError } = await admin
      .from("quiz_axes")
      .select("axis_key, order_index, is_enabled, positive_code, negative_code, positive_label, negative_label, tie_break")
      .eq("quiz_id", quiz.id)
      .order("order_index", { ascending: true });

    if (axisError) {
      return json({ error: axisError.message }, 500);
    }

    const axisDefinitions = normalizeAxisDefinitions((axisRows ?? []) as AxisDefinition[]);
    const resultCode = decodeResultCode({ ei, sn, tf, jp }, axisDefinitions);

    const { data: response, error: responseError } = await admin
      .from("responses")
      .insert({
        quiz_id: quiz.id,
        share_link_id: shareLink.id,
        mbti_type: resultCode,
        axis_ei: ei,
        axis_sn: sn,
        axis_tf: tf,
        axis_jp: jp,
        fingerprint,
      })
      .select("id")
      .single();

    if (responseError || !response) {
      return json({ error: responseError?.message ?? "failed to save response" }, 500);
    }

    const answerRows = answers.map((a) => ({
      response_id: response.id,
      question_id: a.question_id,
      choice_id: a.choice_id,
    }));

    const { error: answerError } = await admin.from("response_answers").insert(answerRows);
    if (answerError) {
      return json({ error: answerError.message }, 500);
    }

    const { data: resultProfile } = await admin
      .from("quiz_result_profiles")
      .select("result_code, role_name, summary, detail")
      .eq("quiz_id", quiz.id)
      .eq("result_code", resultCode)
      .maybeSingle();

    return json(
      {
        result_id: response.id,
        result_code: resultCode,
        mbti_type: resultCode,
        axis_scores: { ei, sn, tf, jp },
        role_name: resultProfile?.role_name ?? `${resultCode}タイプ`,
        summary: resultProfile?.summary ?? `${resultCode} の傾向を示す結果です。`,
        detail: resultProfile?.detail ?? "",
      },
      200,
    );
  } catch (error) {
    return json({ error: `${error}` }, 500);
  }
});

function json(payload: unknown, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function isRateLimited(admin: ReturnType<typeof createClient>, fingerprint: string): Promise<boolean> {
  const now = Date.now();

  const { data: row } = await admin
    .from("submission_rate_limits")
    .select("fingerprint, submitted_count, window_started_at")
    .eq("fingerprint", fingerprint)
    .maybeSingle();

  if (!row) {
    await admin.from("submission_rate_limits").insert({
      fingerprint,
      submitted_count: 1,
      window_started_at: new Date(now).toISOString(),
    });
    return false;
  }

  const windowStart = new Date(row.window_started_at).getTime();
  if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
    await admin.from("submission_rate_limits").update({
      submitted_count: 1,
      window_started_at: new Date(now).toISOString(),
      updated_at: new Date(now).toISOString(),
    }).eq("fingerprint", fingerprint);
    return false;
  }

  if (Number(row.submitted_count) >= RATE_LIMIT_COUNT) {
    return true;
  }

  await admin.from("submission_rate_limits").update({
    submitted_count: Number(row.submitted_count) + 1,
    updated_at: new Date(now).toISOString(),
  }).eq("fingerprint", fingerprint);

  return false;
}
