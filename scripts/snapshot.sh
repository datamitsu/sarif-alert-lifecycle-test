#!/usr/bin/env bash
# usage: snapshot.sh <step>  — captures alerts (per state), analyses and instances
set -uo pipefail
R=datamitsu/sarif-alert-lifecycle-test
REF=refs/heads/main
D="$(dirname "$(readlink -f "$0")")"
step="$1"
out="$D/files/results"
echo "== snapshot $step at $(date -u +%FT%TZ)"
for s in open fixed closed dismissed; do
  gh api "repos/$R/code-scanning/alerts?ref=$REF&state=$s&per_page=100" > "$out/$step-alerts-$s.json" 2>"$out/$step-alerts-$s.err" \
    || { echo "alerts $s failed: $(cat "$out/$step-alerts-$s.err")"; echo '[]' > "$out/$step-alerts-$s.json"; }
  [ -s "$out/$step-alerts-$s.err" ] || rm -f "$out/$step-alerts-$s.err"
done
gh api "repos/$R/code-scanning/analyses?ref=$REF&per_page=100" > "$out/$step-analyses.json"
# follow-up steps: which alerts each synthetic tool is associated with (tool_name filter)
case "$step" in A*|B*)
  for t in ${SNAP_TOOLS:-toolx tooly}; do
    gh api "repos/$R/code-scanning/alerts?ref=$REF&tool_name=$t&per_page=100" > "$out/$step-alerts-tool_name-$t.json"
    echo "-- tool_name=$t -> alerts: $(jq -c '[.[] | {n: .number, rule: .rule.id, tool: .tool.name, state}]' "$out/$step-alerts-tool_name-$t.json")"
  done;;
esac
# all alerts regardless of state, then their instances
gh api "repos/$R/code-scanning/alerts?per_page=100" > "$out/.all.json"
echo '{}' > "$out/$step-instances.json"
for n in $(jq -r '.[].number' "$out/.all.json"); do
  gh api "repos/$R/code-scanning/alerts/$n/instances?per_page=100" > "$out/.inst.json"
  jq --arg n "$n" --slurpfile i "$out/.inst.json" '. + {($n): $i[0]}' "$out/$step-instances.json" > "$out/.tmp.json" \
    && mv "$out/.tmp.json" "$out/$step-instances.json"
done
rm -f "$out/.all.json" "$out/.inst.json"

echo "-- alerts (all states, ref=$REF)"
jq -s -r 'add | unique_by(.number) | sort_by(.number) | .[] |
  [.number, .rule.id, .tool.name, .state, (.fixed_at // "-"),
   .most_recent_instance.category, .most_recent_instance.analysis_key, .most_recent_instance.state] | @tsv' \
  "$out/$step-alerts-open.json" "$out/$step-alerts-closed.json" "$out/$step-alerts-fixed.json" "$out/$step-alerts-dismissed.json"
echo "-- counts: open=$(jq length "$out/$step-alerts-open.json") fixed=$(jq length "$out/$step-alerts-fixed.json") closed=$(jq length "$out/$step-alerts-closed.json") dismissed=$(jq length "$out/$step-alerts-dismissed.json")"
echo "-- analyses"
jq -r '.[] | [.id, .category, .tool.name, .results_count, .rules_count, .deletable, (.warning|tostring), .created_at, .sarif_id] | @tsv' "$out/$step-analyses.json"
echo "-- instances per alert"
jq -r 'to_entries | sort_by(.key|tonumber) | .[] | "#\(.key): " + ([.value[] | "\(.ref)|\(.category)|\(.state)|\(.analysis_key)|tool=\(.tool.name // "n/a")|\(.message.text)"] | join("  ;  "))' "$out/$step-instances.json"
