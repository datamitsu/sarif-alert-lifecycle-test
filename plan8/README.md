# Plan 8: live check of datamitsu's SARIF renderer

Status: **run on 2026-09-28**, once the repository was public (an earlier
attempt the same day answered HTTP 403, "Advanced Security must be enabled for
this repository to use code scanning": `results/00-analyses.json`,
`results/00-upload-L1.json`). Every step's API responses are under `results/`,
named after the step; the workflow runs' logs are `results/C*-run.log`.

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
analyses after each step into `results/`. C3, C3b, C4 and C5b go through
`github/codeql-action/upload-sarif` with `.github/workflows/plan8-upload-sarif.yml`
(one upload step, and a second in the same job when `path2` is given).

| Step | Upload | Expected | Observed | Held |
| --- | --- | --- | --- | --- |
| C1 | L1, REST | four open alerts, two per tool | sarif `14f66238-bb3d-11f1-8869-5761fc9b964f`; analyses 1851700507 (Hadolint, 2 results) and 1851700533 (typecheck, 2), category `datamitsu`; alerts #13 DL3018, #14 DL3059, #15 TS6133, #16 TS2322 open | yes |
| C2 | L2, REST | DL3059 `fixed`, matched on the `primaryLocationLineHash` L1 wrote; DL3018 open; both `typecheck` alerts still open, untouched (the tool is absent from the upload) | sarif `2bddbc26-bb3d-11f1-81fa-36613e0abb57`; analysis 1851704840 (Hadolint, 1 result); #14 `fixed` at 13:04:43Z; DL3018 stayed alert #13 — the same alert, matched on the fingerprint; no new typecheck analysis, #15 and #16 open | yes |
| C3 | L3's two files, one upload step each, one job (run 36426201261) | both accepted; 21 tools in `datamitsu/`; the `hadolint` and `typecheck` alerts of C2 unchanged | success; sarif `61a63d88-bb3d-11f1-9fbf-433b02ee940b` (t01–t20: analyses 1851714829 … 1851715447) and `65a925da-bb3d-11f1-85fc-843ce070b0ec` (t21: analysis 1851715799); alerts #17–#37 open; #13, #15, #16 unchanged. The action computed a fingerprint of its own for every result and, finding datamitsu's different, logged one `##[warning]Calculated fingerprint … found existing inconsistent fingerprint value` per result — and kept datamitsu's | yes |
| C3b | L3's directory as one upload (run 36426397436) | refused: the action combines a directory into one upload of 21 runs, above GitHub's 20 | failure: "Code Scanning could not process the submitted SARIF file: more runs than allowed (21 > 20)"; no analysis, no alert changed | yes |
| C4 | L4 with the action's `category: other` (run 36426502923) | the analysis is in category `plan8-l4/`: the file's own id wins | analysis 1851731787 in category `plan8-l4` — not `other`. Alerts #13 and #14 gained an instance in `plan8-l4`: #14, `fixed` in `datamitsu` since C2, is open again, because the same rule and fingerprint in another category is the same alert (`results/C4-alert-14-instances.json`) | yes |
| C5 | L5, REST | recorded as it comes | refused: HTTP 400, "Invalid SARIF document: No valid runs found." (`results/C5-upload.json`); no analysis, no alert changed | **no**: the renderer wrote this file for a narrowed run, and an upload of it fails |
| C5b | L5 through the action (run 36426761646) | — | the step fails: "Invalid request. 1 item required; only 0 were supplied." | **no**, as C5 |
| C6 | L6, REST | accepted in `plan8-l6/` (one run per tool, lint only) | sarif `23cb8846-bb3e-11f1-95c6-cba5f8b93333`; analysis 1851750984 in `plan8-l6`: Hadolint alone, 2 results — the fix tool is not in it | yes |
| C7 | L7, REST | whether GitHub closes `typecheck`'s alerts for a run with no result whose invocation did not succeed | sarif `37f62f74-bb3e-11f1-9aa2-411576881d64`; analysis 1851754729 (typecheck, 0 results, `warning: "unsuccessful tool execution, exit code 2"`) and 1851754714 (Hadolint, 1); #15 and #16 `fixed` at 13:12:13Z | the renderer's fix holds: such a run closes every alert of the tool, `executionSuccessful: false` and the notification notwithstanding, so a tool that failed without parsable output must be left out, as it now is |

## What changed in datamitsu

Commit `aea8482` on `feat/ur-08-interchange-formats`:

- C5: a SARIF report that would hold no run is no longer written — an earlier
  file at its path, or the `datamitsu-<n>.sarif` files of its directory, are
  removed, the export is recorded as `omitted`, and a warning says so — so a
  workflow's upload step, guarded by `hashFiles`, uploads nothing and changes no
  alert.
- The guide says that the upload action logs a warning per result whose
  fingerprint differs from the one it computes, and keeps datamitsu's; and that
  one finding uploaded under two categories is one alert with an instance in
  each, which closes only once every category's next upload leaves it out.
