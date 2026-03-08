export type AxisScores = {
  ei: number;
  sn: number;
  tf: number;
  jp: number;
};

export function decodeMbti(scores: AxisScores): string {
  const e = scores.ei >= 0 ? "E" : "I";
  const s = scores.sn >= 0 ? "S" : "N";
  const t = scores.tf >= 0 ? "T" : "F";
  const j = scores.jp >= 0 ? "J" : "P";
  return `${e}${s}${t}${j}`;
}
