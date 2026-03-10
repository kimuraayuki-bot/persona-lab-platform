import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const QUIZ_SELECT =
  "id,public_id,creator_id,title,description,visibility,created_at,questions(id,prompt,order_index,choices:choices!choices_question_id_fkey(id,body,order_index,ei_delta,sn_delta,tf_delta,jp_delta)),axis_definitions:quiz_axes(axis_key,order_index,is_enabled,positive_code,negative_code,positive_label,negative_label,tie_break),result_profiles:quiz_result_profiles(result_code,role_name,summary,detail,image_url)";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const quizPublicID = body.quiz_public_id as string | undefined;
    const token = body.token as string | undefined;

    if (!quizPublicID) {
      return json({ error: "quiz_public_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseService = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, supabaseService);

    const { data: quiz, error: quizError } = await admin
      .from("quizzes")
      .select(QUIZ_SELECT)
      .eq("public_id", quizPublicID)
      .single();

    if (quizError || !quiz) {
      return json({ error: "quiz not found" }, 404);
    }

    const visibility = normalizeVisibility(quiz.visibility);
    if (visibility == "directory_public") {
      return json(quiz, 200);
    }

    if (!token) {
      return json({ error: "token required" }, 403);
    }

    const tokenHash = await sha256(token);
    const { data: shareLink, error: shareLinkError } = await admin
      .from("share_links")
      .select("id, expires_at")
      .eq("quiz_id", quiz.id)
      .eq("token_hash", tokenHash)
      .single();

    if (shareLinkError || !shareLink) {
      return json({ error: "invalid token" }, 403);
    }

    if (shareLink.expires_at && new Date(shareLink.expires_at).getTime() < Date.now()) {
      return json({ error: "token expired" }, 403);
    }

    return json(quiz, 200);
  } catch (error) {
    return json({ error: `${error}` }, 500);
  }
});

function normalizeVisibility(value: string | null | undefined): "share_link" | "directory_public" {
  return value === "directory_public" ? "directory_public" : "share_link";
}

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
