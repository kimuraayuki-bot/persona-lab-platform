const QUIZ_SELECT =
  "id,public_id,title,description,questions(id,prompt,order_index,choices(id,body,order_index))";

function getConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY が未設定です");
  }

  return { url, anonKey };
}

function normalizeQuiz(raw) {
  const questions = (raw.questions ?? [])
    .slice()
    .sort((a, b) => a.order_index - b.order_index)
    .map((q) => ({
      id: q.id,
      prompt: q.prompt,
      orderIndex: q.order_index,
      choices: (q.choices ?? [])
        .slice()
        .sort((a, b) => a.order_index - b.order_index)
        .map((c) => ({
          id: c.id,
          body: c.body,
          orderIndex: c.order_index
        }))
    }));

  return {
    id: raw.id,
    publicId: raw.public_id,
    title: raw.title,
    description: raw.description ?? "",
    questions
  };
}

export async function fetchQuizByPublicId(quizPublicId) {
  const { url, anonKey } = getConfig();

  const endpoint = new URL(`${url}/rest/v1/quizzes`);
  endpoint.searchParams.set("select", QUIZ_SELECT);
  endpoint.searchParams.set("public_id", `eq.${quizPublicId}`);
  endpoint.searchParams.set("limit", "1");

  const response = await fetch(endpoint, {
    method: "GET",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`
    },
    cache: "no-store"
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Quiz fetch failed (${response.status}): ${text}`);
  }

  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    return null;
  }

  return normalizeQuiz(rows[0]);
}

export async function submitResponse(payload) {
  const { url, anonKey } = getConfig();

  const response = await fetch(`${url}/functions/v1/submit_response`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`
    },
    body: JSON.stringify(payload)
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message = typeof data?.error === "string" ? data.error : "submit failed";
    throw new Error(message);
  }

  return data;
}
