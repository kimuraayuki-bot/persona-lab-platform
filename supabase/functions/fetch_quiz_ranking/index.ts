import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

type RankingRow = {
  quiz_id: string;
  total_responses: number;
  updated_at: string | null;
  quiz: {
    public_id: string;
    title: string;
    description: string | null;
  } | null;
};

type ResultRow = {
  quiz_id: string;
  result_code: string | null;
  response_count: number;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const limit = normalizeLimit(body.limit);
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const client = createClient(supabaseUrl, supabaseAnon);

    const { data: rows, error } = await client
      .from("quiz_response_stats")
      .select("quiz_id,total_responses,updated_at,quiz:quizzes!inner(public_id,title,description)")
      .order("total_responses", { ascending: false })
      .order("updated_at", { ascending: false })
      .limit(limit);

    if (error) {
      return json({ error: error.message }, 500);
    }

    const rankingRows = (rows ?? []) as RankingRow[];
    const quizIds = rankingRows.map((row) => row.quiz_id).filter(Boolean);
    const topResultsByQuiz = await fetchTopResults(client, quizIds);

    const ranking = rankingRows.map((row, index) => ({
      rank: index + 1,
      quiz_id: row.quiz_id,
      total_responses: Number(row.total_responses ?? 0),
      updated_at: row.updated_at,
      quiz: {
        public_id: row.quiz?.public_id ?? "",
        title: row.quiz?.title ?? "名称未設定",
        description: row.quiz?.description ?? "",
      },
      top_results: topResultsByQuiz.get(row.quiz_id) ?? [],
    }));

    return json({ ranking }, 200);
  } catch (error) {
    return json({ error: `${error}` }, 500);
  }
});

async function fetchTopResults(
  client: ReturnType<typeof createClient>,
  quizIds: string[],
): Promise<Map<string, Array<{ result_code: string; response_count: number }>>> {
  const grouped = new Map<string, Array<{ result_code: string; response_count: number }>>();
  if (quizIds.length === 0) {
    return grouped;
  }

  const { data, error } = await client
    .from("quiz_result_stats")
    .select("quiz_id,result_code,response_count")
    .in("quiz_id", quizIds)
    .order("response_count", { ascending: false });

  if (error || !data) {
    return grouped;
  }

  for (const row of data as ResultRow[]) {
    if (!grouped.has(row.quiz_id)) {
      grouped.set(row.quiz_id, []);
    }

    const current = grouped.get(row.quiz_id)!;
    if (current.length >= 3) {
      continue;
    }

    current.push({
      result_code: (row.result_code ?? "").toUpperCase(),
      response_count: Number(row.response_count ?? 0),
    });
  }

  return grouped;
}

function normalizeLimit(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 20;
  }

  return Math.max(1, Math.min(50, Math.trunc(value)));
}

function json(payload: unknown, status: number) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
