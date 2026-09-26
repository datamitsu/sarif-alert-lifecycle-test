#!/usr/bin/env bash
# usage: put.sh <repo-path> <local-file> <message>
set -euo pipefail
R=datamitsu/sarif-alert-lifecycle-test
p="$1"; f="$2"; m="$3"
sha=$(gh api "repos/$R/contents/$p?ref=main" --jq .sha 2>/dev/null || true)
body=$(mktemp)
if [ -n "$sha" ]; then
  jq -n --arg m "$m" --rawfile c <(base64 -w0 "$f") --arg s "$sha" '{message:$m, content:$c, branch:"main", sha:$s}' > "$body"
else
  jq -n --arg m "$m" --rawfile c <(base64 -w0 "$f") '{message:$m, content:$c, branch:"main"}' > "$body"
fi
gh api -X PUT "repos/$R/contents/$p" --input "$body" --jq '.commit.sha'
rm -f "$body"
