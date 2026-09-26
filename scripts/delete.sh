#!/usr/bin/env bash
# usage: delete.sh <analysis_id> <step> [query]   — DELETE an analysis, save status+headers+body
set -uo pipefail
R=datamitsu/sarif-alert-lifecycle-test
D="$(dirname "$(readlink -f "$0")")"
id="$1"; step="$2"; q="${3:-}"
url="repos/$R/code-scanning/analyses/$id${q:+?$q}"
out="$D/files/results/$step-delete.txt"
echo "== DELETE /$url at $(date -u +%FT%TZ)" | tee "$out"
gh api -X DELETE -i "$url" >> "$out" 2>&1
echo "gh exit=$?" | tee -a "$out"
grep -v -i -E '^(x-|access-control|content-security|strict-transport|referrer|vary|server|github-authentication|etag|cache-control|date)' "$out"
