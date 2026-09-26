#!/usr/bin/env bash
# Archive generated SARIF, captured API responses and the scripts into the experiment repo.
set -uo pipefail
D="$(dirname "$(readlink -f "$0")")"
put() {
  local p="$1" f="$2" m="$3" try
  for try in 1 2 3; do
    if out=$(bash "$D/put.sh" "$p" "$f" "$m" 2>&1); then echo "$p $out"; sleep 1; return 0; fi
    echo "retry $p: $out"; sleep 20
  done
  echo "FAILED $p"
}
for f in "$D"/files/sarif/*.sarif.json; do
  put "sarif/$(basename "$f")" "$f" "chore: archive SARIF $(basename "$f")"
done
for f in "$D"/files/results/*.json; do
  put "results/$(basename "$f")" "$f" "chore: archive API snapshot $(basename "$f")"
done
for s in gen.py put.sh upload.sh snapshot.sh archive.sh; do
  put "scripts/$s" "$D/$s" "chore: archive experiment script $s"
done
