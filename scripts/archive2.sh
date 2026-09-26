#!/usr/bin/env bash
# Archive the follow-up steps (A*, B*) and their scripts into the experiment repo.
set -uo pipefail
D="$(dirname "$(readlink -f "$0")")"
put() {
  local p="$1" f="$2" m="$3" try out
  for try in 1 2 3; do
    if out=$(bash "$D/put.sh" "$p" "$f" "$m" 2>&1); then echo "$p $out"; sleep 1; return 0; fi
    echo "retry $p: $out"; sleep 20
  done
  echo "FAILED $p"
}
for s in A1 A2 A3 B1; do
  put "sarif/$s.sarif.json" "$D/files/sarif/$s.sarif.json" "chore: archive SARIF $s.sarif.json"
done
for f in "$D"/files/results/A[123]-* "$D"/files/results/B[1234]-*; do
  put "results/$(basename "$f")" "$f" "chore: archive API snapshot $(basename "$f")"
done
for s in gen2.py snapshot.sh delete.sh after-delete.sh archive2.sh; do
  put "scripts/$s" "$D/$s" "chore: archive experiment script $s"
done
