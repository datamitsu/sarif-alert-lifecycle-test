#!/bin/sh
# Plan 8 live check of datamitsu's SARIF renderer against GitHub code scanning.
# Run from the repository root, with gh authenticated for this repository and
# code scanning available on it. Every response is written under
# plan8/results/; commit them afterwards.
#
#   sh plan8/scripts/live.sh C1   # then C2, C5, C6, C7 in that order
#
# C3 and C4 go through github/codeql-action/upload-sarif: move
# plan8/workflows/plan8-upload-sarif.yml to .github/workflows/ first, then
#   gh workflow run plan8-upload-sarif.yml -f path=plan8/sarif/L3/datamitsu-1.sarif -f category=
#   gh workflow run plan8-upload-sarif.yml -f path=plan8/sarif/L3/datamitsu-2.sarif -f category=
#   gh workflow run plan8-upload-sarif.yml -f path=plan8/sarif/L3 -f category=          # C3b
#   gh workflow run plan8-upload-sarif.yml -f path=plan8/sarif/L4.sarif -f category=other
# and snapshot after each with `sh plan8/scripts/live.sh snapshot C3` (C3b, C4).
set -eu

REPO=datamitsu/sarif-alert-lifecycle-test
REF=refs/heads/main
OUT=plan8/results
mkdir -p "$OUT"
SHA=$(gh api "repos/$REPO/commits/main" --jq .sha)

snapshot() {
	for state in open fixed; do
		gh api "repos/$REPO/code-scanning/alerts?ref=$REF&state=$state&per_page=100" >"$OUT/$1-alerts-$state.json"
	done
	gh api "repos/$REPO/code-scanning/analyses?ref=$REF&per_page=100" >"$OUT/$1-analyses.json"
}

# upload <step> <file>: the REST upload, then its processing status.
upload() {
	sarif=$(gzip -c "$2" | base64 | tr -d '\n')
	gh api --method POST "repos/$REPO/code-scanning/sarifs" \
		-f commit_sha="$SHA" -f ref="$REF" -f sarif="$sarif" >"$OUT/$1-upload.json"
	id=$(jq -r .id "$OUT/$1-upload.json")
	while :; do
		gh api "repos/$REPO/code-scanning/sarifs/$id" >"$OUT/$1-status.json"
		[ "$(jq -r .processing_status "$OUT/$1-status.json")" = pending ] || break
		sleep 5
	done
	sleep 10
	snapshot "$1"
}

case "$1" in
C1) upload C1 plan8/sarif/L1.sarif ;; # 4 alerts: hadolint DL3018 + DL3059, typecheck TS6133 + TS2322
C2) upload C2 plan8/sarif/L2.sarif ;; # DL3059 fixed; typecheck left out, its 2 alerts still open
C5) upload C5 plan8/sarif/L5.sarif ;; # a file without a run: what the upload does, no alert changes
C6) upload C6 plan8/sarif/L6.sarif ;; # a check document: lint only, category plan8-l6
C7) upload C7 plan8/sarif/L7.sarif ;; # typecheck's run with no result and executionSuccessful false: are its alerts closed?
snapshot) snapshot "$2" ;;
*)
	echo "usage: $0 C1|C2|C5|C6|C7|snapshot <step>" >&2
	exit 2
	;;
esac
