export type AxisScores = {
  ei: number;
  sn: number;
  tf: number;
  jp: number;
};

export type AxisKey = "ei" | "sn" | "tf" | "jp";
export type TieBreak = "positive" | "negative";

export type AxisDefinition = {
  axis_key: AxisKey;
  order_index: number;
  positive_code: string;
  negative_code: string;
  positive_label?: string;
  negative_label?: string;
  tie_break: TieBreak;
};

const AXIS_ORDER: AxisKey[] = ["ei", "sn", "tf", "jp"];

const DEFAULT_CODE: Record<AxisKey, { positive: string; negative: string }> = {
  ei: { positive: "E", negative: "I" },
  sn: { positive: "S", negative: "N" },
  tf: { positive: "T", negative: "F" },
  jp: { positive: "J", negative: "P" }
};

function sanitizeCode(code: string | null | undefined, fallback: string): string {
  const cleaned = (code ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 4);

  return cleaned.length > 0 ? cleaned : fallback;
}

export function defaultAxisDefinitions(): AxisDefinition[] {
  return AXIS_ORDER.map((axisKey, index) => ({
    axis_key: axisKey,
    order_index: index,
    positive_code: DEFAULT_CODE[axisKey].positive,
    negative_code: DEFAULT_CODE[axisKey].negative,
    positive_label: DEFAULT_CODE[axisKey].positive,
    negative_label: DEFAULT_CODE[axisKey].negative,
    tie_break: "positive"
  }));
}

export function normalizeAxisDefinitions(input: AxisDefinition[] | null | undefined): AxisDefinition[] {
  const byAxis = new Map<AxisKey, AxisDefinition>();

  for (const axis of input ?? []) {
    if (!AXIS_ORDER.includes(axis.axis_key)) {
      continue;
    }

    const fallback = DEFAULT_CODE[axis.axis_key];
    const positiveCode = sanitizeCode(axis.positive_code, fallback.positive);
    const negativeCode = sanitizeCode(axis.negative_code, fallback.negative);

    byAxis.set(axis.axis_key, {
      axis_key: axis.axis_key,
      order_index: typeof axis.order_index === "number" ? axis.order_index : AXIS_ORDER.indexOf(axis.axis_key),
      positive_code: positiveCode,
      negative_code: negativeCode,
      positive_label: axis.positive_label?.trim() || positiveCode,
      negative_label: axis.negative_label?.trim() || negativeCode,
      tie_break: axis.tie_break === "negative" ? "negative" : "positive"
    });
  }

  return AXIS_ORDER.map((axisKey, index) => {
    const existing = byAxis.get(axisKey);
    if (existing) {
      return { ...existing, order_index: index };
    }

    return {
      axis_key: axisKey,
      order_index: index,
      positive_code: DEFAULT_CODE[axisKey].positive,
      negative_code: DEFAULT_CODE[axisKey].negative,
      positive_label: DEFAULT_CODE[axisKey].positive,
      negative_label: DEFAULT_CODE[axisKey].negative,
      tie_break: "positive"
    };
  });
}

function axisValue(axisKey: AxisKey, scores: AxisScores): number {
  switch (axisKey) {
    case "ei":
      return scores.ei;
    case "sn":
      return scores.sn;
    case "tf":
      return scores.tf;
    case "jp":
      return scores.jp;
  }
}

export function decodeResultCode(scores: AxisScores, axisDefinitions: AxisDefinition[]): string {
  const normalized = normalizeAxisDefinitions(axisDefinitions);
  let resultCode = "";

  for (const axis of normalized) {
    const value = axisValue(axis.axis_key, scores);

    if (value > 0) {
      resultCode += axis.positive_code;
      continue;
    }

    if (value < 0) {
      resultCode += axis.negative_code;
      continue;
    }

    resultCode += axis.tie_break === "negative" ? axis.negative_code : axis.positive_code;
  }

  return resultCode;
}

export function allResultCodes(axisDefinitions: AxisDefinition[]): string[] {
  const normalized = normalizeAxisDefinitions(axisDefinitions);
  let codes = [""];

  for (const axis of normalized) {
    const next: string[] = [];
    for (const prefix of codes) {
      next.push(prefix + axis.positive_code);
      next.push(prefix + axis.negative_code);
    }
    codes = next;
  }

  return codes;
}
