# Plan 8: live check of datamitsu's SARIF renderer

Status: **pending** — code scanning is not available on this repository right
now. On 2026-09-28 both the analyses endpoint and a SARIF upload answered HTTP
403, "Advanced Security must be enabled for this repository to use code
scanning" (`results/00-analyses.json`, `results/00-upload-L1.json`). The
repository is private; it needs to be public, or to have code scanning enabled,
before the checks below can run.

Every file under `sarif/` was written by datamitsu's own SARIF renderer
(branch `feat/ur-08-interchange-formats` of the core), from real `lint` and
`check` runs in a repository holding this repository's `Dockerfile` and
`src/a.ts` byte for byte, so that every result points at a real line and every
`primaryLocationLineHash` is the fingerprint the renderer computed from that
line. `generate_test.go.txt` is the harness test that produced them.

| File | Run | What it holds |
| --- | --- | --- |
| `sarif/L1.sarif` | `lint --report sarif=…` | category `datamitsu/`: `hadolint` (DL3018 line 2, DL3059 line 4) and `typecheck` (TS6133 line 1, TS2322 line 5) |
| `sarif/L2.sarif` | the same, a day later | `hadolint` without DL3059; `typecheck` failed without parsable output and is left out |
| `sarif/L3/` | 21 tools, `--report sarif=out/` | two files, one category: `datamitsu-1.sarif` with t01–t20, `datamitsu-2.sarif` with t21 |
| `sarif/L4.sarif` | `--report 'sarif=…?category=plan8-l4'` | `hadolint` under `plan8-l4/` |
| `sarif/L5.sarif` | `lint Dockerfile --report sarif=…` (narrowed) | no run at all |
| `sarif/L6.sarif` | `check --report 'sarif=…?category=plan8-l6'` | the lint operation only, one run per tool |
| `sarif/L7.sarif` | L2 as the renderer wrote it before two fixes | `typecheck`'s run with no result, an error notification and `executionSuccessful: false` (and `false` for invocations that exited on findings, since corrected) |

## Checks

`scripts/live.sh` uploads through the REST API and snapshots the alerts and the
analyses after each step into `results/`; C3 and C4 go through
`github/codeql-action/upload-sarif` with `workflows/plan8-upload-sarif.yml`,
which has to be moved to `.github/workflows/` first.

| Step | Upload | Expected |
| --- | --- | --- |
| C1 | L1 | four open alerts, two per tool |
| C2 | L2 | DL3059 `fixed`, matched on the `primaryLocationLineHash` L1 wrote; DL3018 open; both `typecheck` alerts still open, untouched (the tool is absent from the upload) |
| C3 | L3's two files, one upload each, from one job | both accepted; 21 tools in `datamitsu/`; the `hadolint` and `typecheck` alerts of C2 unchanged (absent from both uploads) |
| C3b | L3's directory as one upload | refused: the action combines a directory into one upload of 21 runs, above GitHub's 20 — the reason datamitsu's guide uploads each file in a step of its own |
| C4 | L4 with the action's `category: other` | the analysis is in category `plan8-l4/`: the file's own id wins |
| C5 | L5 | recorded as it comes: accepted or refused, and no alert changes |
| C6 | L6 | accepted in `plan8-l6/` (one run per tool, lint only) |
| C7 | L7 | whether GitHub closes `typecheck`'s alerts for a run with no result whose invocation did not succeed — the renderer leaves such a tool out since the fix, whatever this shows |

After the run, commit `results/` and write each step's outcome in this file.
