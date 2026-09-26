#!/usr/bin/env bash
# usage: upload.sh <step>   — uploads files/sarif/<step>.sarif.json, polls, snapshots
set -uo pipefail
R=datamitsu/sarif-alert-lifecycle-test
SHA=3b2a3a56c7cd0b3e2ab87d8ccc8416fe7d383b75
REF=refs/heads/main
D="$(dirname "$(readlink -f "$0")")"
step="$1"
f="$D/files/sarif/$step.sarif.json"
log="$D/files/results/$step-upload.json"

body=$(mktemp)
jq -n --arg c "$SHA" --arg r "$REF" --rawfile s <(gzip -c "$f" | base64 -w0) \
  '{commit_sha:$c, ref:$r, sarif:$s}' > "$body"
echo "== $step upload at $(date -u +%FT%TZ)"
resp=$(gh api -X POST "repos/$R/code-scanning/sarifs" --input "$body" 2>&1)
rc=$?
rm -f "$body"
echo "$resp"
if [ $rc -ne 0 ]; then
  jq -n --arg r "$resp" '{post_error:$r}' > "$log"
  exit 1
fi
id=$(echo "$resp" | jq -r .id)
start=$(date +%s)
while :; do
  st=$(gh api "repos/$R/code-scanning/sarifs/$id")
  ps=$(echo "$st" | jq -r .processing_status)
  echo "$(date -u +%T) processing_status=$ps"
  if [ "$ps" = complete ] || [ "$ps" = failed ]; then break; fi
  if [ $(( $(date +%s) - start )) -gt 600 ]; then echo "timeout"; break; fi
  sleep 15
done
done_at=$(date -u +%FT%TZ)
jq -n --argjson post "$resp" --argjson status "$st" --arg done "$done_at" \
  '{post:$post, final_status:$status, observed_complete_at:$done}' > "$log"
echo "$st" | jq .
echo "waiting 30s before snapshot"
sleep 30
bash "$D/snapshot.sh" "$step"
