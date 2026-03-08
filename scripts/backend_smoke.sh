#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY are required"
  exit 1
fi

echo "[1/2] result_profiles を取得（DB/RLS確認）"
profiles=$(curl -sS "${SUPABASE_URL}/rest/v1/result_profiles?select=mbti_type&limit=3" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")
echo "$profiles"

if [[ "$profiles" != \[*\] ]]; then
  echo "ERROR: result_profiles query failed"
  exit 1
fi

echo "[2/2] submit_response をダミーで呼び出し（Function疎通確認）"
resp=$(curl -sS -w "\nHTTP:%{http_code}\n" "${SUPABASE_URL}/functions/v1/submit_response" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{"quiz_public_id":"dummy","token":"dummy","answers":[{"question_id":"00000000-0000-0000-0000-000000000000","choice_id":"00000000-0000-0000-0000-000000000000"}]}'
)

echo "$resp"

status=$(echo "$resp" | sed -n 's/^HTTP://p')
if [[ "$status" == "404" || "$status" == "400" ]]; then
  echo "OK: function is reachable"
  exit 0
fi

echo "WARN: unexpected status ${status}"
exit 0
