const QUIZ_SELECT =
  "id,public_id,title,description,questions(id,prompt,order_index,choices:choices!choices_question_id_fkey(id,body,order_index)),axis_definitions:quiz_axes(axis_key,order_index,is_enabled,positive_code,negative_code,positive_label,negative_label,tie_break),result_profiles:quiz_result_profiles(result_code,role_name,summary,detail,image_url)";

const AXIS_ORDER = ["ei", "sn", "tf", "jp"];
const DEFAULT_AXIS_CODES = {
  ei: { positive: "E", negative: "I" },
  sn: { positive: "S", negative: "N" },
  tf: { positive: "T", negative: "F" },
  jp: { positive: "J", negative: "P" }
};

function getConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error("NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY が未設定です");
  }

  return { url, anonKey };
}

function authHeaders(anonKey) {
  return {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`
  };
}

async function fetchJson(endpoint) {
  const { anonKey } = getConfig();

  const response = await fetch(endpoint, {
    method: "GET",
    headers: authHeaders(anonKey),
    cache: "no-store"
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Fetch failed (${response.status}): ${text}`);
  }

  return response.json();
}

function sanitizeCode(value, fallback) {
  const normalized = (value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 4);

  return normalized.length > 0 ? normalized : fallback;
}

function normalizeAxisDefinitions(rawAxisDefinitions) {
  const byKey = new Map();

  for (const axis of rawAxisDefinitions ?? []) {
    if (!AXIS_ORDER.includes(axis.axis_key)) {
      continue;
    }

    const defaults = DEFAULT_AXIS_CODES[axis.axis_key];
    const positiveCode = sanitizeCode(axis.positive_code, defaults.positive);
    const negativeCode = sanitizeCode(axis.negative_code, defaults.negative);

    byKey.set(axis.axis_key, {
      axisKey: axis.axis_key,
      orderIndex: AXIS_ORDER.indexOf(axis.axis_key),
      isEnabled: axis.is_enabled !== false,
      positiveCode,
      negativeCode,
      positiveLabel: axis.positive_label?.trim() || positiveCode,
      negativeLabel: axis.negative_label?.trim() || negativeCode,
      tieBreak: axis.tie_break === "negative" ? "negative" : "positive"
    });
  }

  return AXIS_ORDER.map((axisKey, orderIndex) => {
    const existing = byKey.get(axisKey);
    if (existing) {
      return { ...existing, orderIndex };
    }

    const defaults = DEFAULT_AXIS_CODES[axisKey];
    return {
      axisKey,
      orderIndex,
      isEnabled: true,
      positiveCode: defaults.positive,
      negativeCode: defaults.negative,
      positiveLabel: defaults.positive,
      negativeLabel: defaults.negative,
      tieBreak: "positive"
    };
  });
}

function enabledAxisDefinitions(axisDefinitions) {
  return normalizeAxisDefinitions(axisDefinitions).filter((axis) => axis.isEnabled);
}

function allResultCodes(axisDefinitions) {
  const enabledAxes = enabledAxisDefinitions(axisDefinitions);
  if (enabledAxes.length === 0) {
    return [];
  }

  let codes = [""];
  for (const axis of enabledAxes) {
    const next = [];
    for (const prefix of codes) {
      next.push(prefix + axis.positiveCode);
      next.push(prefix + axis.negativeCode);
    }
    codes = next;
  }
  return codes;
}

function normalizeResultProfiles(rawResultProfiles, axisDefinitions) {
  const byCode = new Map();

  for (const profile of rawResultProfiles ?? []) {
    const resultCode = (profile.result_code ?? "").toUpperCase();
    if (!resultCode) {
      continue;
    }

    byCode.set(resultCode, {
      resultCode,
      roleName: profile.role_name ?? `${resultCode}タイプ`,
      summary: profile.summary ?? `${resultCode} の傾向を示す結果です。`,
      detail: profile.detail ?? "",
      imageURL: profile.image_url ?? null
    });
  }

  return allResultCodes(axisDefinitions).map((code) => {
    if (byCode.has(code)) {
      return byCode.get(code);
    }

    return {
      resultCode: code,
      roleName: `${code}タイプ`,
      summary: `${code} の傾向を示す結果です。`,
      detail: "",
      imageURL: null
    };
  });
}

function normalizeQuiz(raw) {
  const axisDefinitions = normalizeAxisDefinitions(raw.axis_definitions ?? []);
  const resultProfiles = normalizeResultProfiles(raw.result_profiles ?? [], axisDefinitions);

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
    axisDefinitions,
    resultProfiles,
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

export async function fetchQuizRanking(limit = 20) {
  const { url } = getConfig();
  const endpoint = new URL(`${url}/rest/v1/quiz_response_stats`);

  endpoint.searchParams.set(
    "select",
    "quiz_id,total_responses,updated_at,quiz:quizzes!inner(public_id,title,description)"
  );
  endpoint.searchParams.set("order", "total_responses.desc,updated_at.desc");
  endpoint.searchParams.set("limit", String(limit));

  const rows = await fetchJson(endpoint);
  if (!Array.isArray(rows) || rows.length === 0) {
    return [];
  }

  const quizIds = rows
    .map((row) => row.quiz_id)
    .filter((value) => typeof value === "string" && value.length > 0);

  const resultStatsByQuiz = await fetchQuizResultStats(quizIds);

  return rows.map((row, index) => ({
    rank: index + 1,
    quizId: row.quiz_id,
    totalResponses: Number(row.total_responses ?? 0),
    updatedAt: row.updated_at ?? null,
    quiz: {
      publicId: row.quiz?.public_id ?? "",
      title: row.quiz?.title ?? "名称未設定",
      description: row.quiz?.description ?? ""
    },
    topResults: resultStatsByQuiz.get(row.quiz_id) ?? []
  }));
}

async function fetchQuizResultStats(quizIds) {
  const grouped = new Map();
  if (!Array.isArray(quizIds) || quizIds.length === 0) {
    return grouped;
  }

  const { url } = getConfig();
  const endpoint = new URL(`${url}/rest/v1/quiz_result_stats`);
  endpoint.searchParams.set("select", "quiz_id,result_code,response_count");
  endpoint.searchParams.set("quiz_id", `in.(${quizIds.join(",")})`);
  endpoint.searchParams.set("order", "response_count.desc");

  const rows = await fetchJson(endpoint);
  if (!Array.isArray(rows)) {
    return grouped;
  }

  for (const row of rows) {
    const quizId = row.quiz_id;
    if (!grouped.has(quizId)) {
      grouped.set(quizId, []);
    }

    const entries = grouped.get(quizId);
    if (entries.length >= 3) {
      continue;
    }

    entries.push({
      resultCode: (row.result_code ?? "").toUpperCase(),
      responseCount: Number(row.response_count ?? 0)
    });
  }

  return grouped;
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
