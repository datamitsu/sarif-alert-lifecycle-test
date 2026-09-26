#!/usr/bin/env bash
# usage: after-delete.sh <step> <analysis_id> <alert numbers...>
set -uo pipefail
R=datamitsu/sarif-alert-lifecycle-test
D="$(dirname "$(readlink -f "$0")")"
step="$1"; aid="$2"; shift 2
out="$D/files/results"
SNAP_TOOLS=toolz bash "$D/snapshot.sh" "$step"
echo "-- GET analyses/$aid"
gh api -i "repos/$R/code-scanning/analyses/$aid" > "$out/$step-analysis-$aid.txt" 2>&1
head -1 "$out/$step-analysis-$aid.txt"; tail -2 "$out/$step-analysis-$aid.txt"
for n in "$@"; do
  echo "-- GET alerts/$n"
  gh api -i "repos/$R/code-scanning/alerts/$n" > "$out/$step-alert-$n.txt" 2>&1
  head -1 "$out/$step-alert-$n.txt"
  sed -n '/^{/,$p' "$out/$step-alert-$n.txt" | jq -c '{number, state, fixed_at, updated_at, tool: .tool.name, rule: .rule.id, mri: (.most_recent_instance | {category, state, analysis_key})}' 2>/dev/null || tail -2 "$out/$step-alert-$n.txt"
  echo "-- GET alerts/$n/instances"
  gh api -i "repos/$R/code-scanning/alerts/$n/instances" > "$out/$step-alert-$n-instances.txt" 2>&1
  head -1 "$out/$step-alert-$n-instances.txt"
  sed -n '/^\[/,$p' "$out/$step-alert-$n-instances.txt" | jq -c '[.[] | {category, state, analysis_key, commit_sha}]' 2>/dev/null || tail -2 "$out/$step-alert-$n-instances.txt"
done
