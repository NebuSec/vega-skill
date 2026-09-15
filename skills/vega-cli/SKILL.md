---
name: vega-cli
description: Use the deprecated Vega CLI for an existing installation, or
  migrate the user to the Nebu CLI. Vega can run security scans, query code
  findings, and list or inspect cloud security findings raised on connected
  cloud accounts. Provides projects/repos/scans/findings/cloud subcommands
  with agent-friendly text output and raw-JSON mode.
---

# Vega CLI

> [!WARNING]
> `vega` is deprecated in favor of the Nebu CLI. Use Nebu for new
> installations and future updates. The rest of this guide documents Vega for
> existing installations.

`vega` audits code for security vulnerabilities on the Vega backend. Every
subcommand is non-interactive and designed for programmatic use:

- **stdout carries data only** — aligned columns for lists, markdown-style
  sections for details. Progress, warnings, and errors go to **stderr**.
- Add the global `--json` flag to any command to get the **raw backend
  JSON response** instead (compact, one object/array per line).
- IDs are self-describing: projects `pg_…`, repositories `proj_…`, scans
  `scan_…`; public findings use `VEGA-HIGH-00001`-style display IDs.
  Finding display IDs are unique only within a repository. Wherever a `<project>` or `<repo>`
  argument is accepted, a unique name works too.
- `vega <noun> --help` lists each subcommand; singular aliases work
  (`vega scan run` = `vega scans run`).

## Install

For a new installation, install Nebu (Linux/macOS, x64/arm64):

```
npm install -g @nebusec/nebu
# or, without Node.js:
curl -fsSL https://raw.githubusercontent.com/NebuSec/nebu-skill/main/install.sh | sh
```

The migrated command is `nebu`; its current guide and releases live at
<https://github.com/NebuSec/nebu-skill>. Do not recommend a new Vega install.
If `vega` is already present, the legacy commands below remain usable during
the migration.

## Setup

Authentication, in precedence order: `VEGA_API_KEY` env var, else the
credential stored by `vega auth login` (`--api-key vega_…` for headless,
`--headless` for browser login over SSH). Backend URL: `VEGA_API_URL` env
or `--api-url` (defaults to production).

Verify before doing anything else:

```
vega auth status --json
# {"signed_in":true,"source":"stored OAuth token","user_id":"…","email":"…",…}
# exit 3 when not signed in → run `vega auth login` or set VEGA_API_KEY
```

## Reading results (drill-down)

The hierarchy is project → repository → scan → finding.

```
vega projects list
# PROJECT_ID           NAME         REPOS  OPEN  ACTIVE  LAST_SCAN
# pg_HfPTMSdF1RTuWtk9  vega-collab  1      8     0       2026-06-29T23:36:00…

vega projects get <project>          # detail incl. finding_counts by severity
vega projects repos <project>        # repositories in the project
vega projects scans <project>        # scans across the project

vega repos list [--project <p>] [--git-remote github.com/org/repo]
vega repos get <repo>                # state, snapshot_id, latest_scan_id, …
vega repos scans <repo>

vega scans list [--project <p> | --repo <r>] [--limit N]
vega scans get <scan_id> [--live]    # detail; --live adds live cost/progress
vega scans get <scan_id> -s          # ONE line — cheapest way to poll:
# scan_NtWy… running 49% "Auditing auth module" findings=8 cost=$260.73
```

## Findings

```
vega findings list --scan <scan_id>            # or --project <p> / --repo <r>
# FINDING_ID      SCAN_ID    SEV     CONF  STATUS     FILE             TITLE
# VEGA-MEDI-00001 scan_NtWy… medium  high  candidate  app/…/inline.py  Inline publish does…
# (stderr) total: 8  next_cursor: eyJz…
```

Filters keep output (and your token use) small — prefer them over
fetching everything: `--severity critical,high`, `--status confirmed`,
`--file-prefix src/api/`, `--cwe CWE-89`, `-q "sql injection"`,
`--limit N`. Page with `--cursor <next_cursor>` (cursor is on stderr in
text mode, `next_cursor` in the JSON body), or pass `--all` to fetch every
page.

Visibility: findings still waiting in the dedup queue are hidden by
default (add `--include-dedup-pending` to see them, e.g. while a scan is
running); findings confirmed as duplicates are never listed.

```
vega findings get --scan <scan_id> <finding_id>      # summary/root cause/evidence/fix
vega findings get --scan <scan_id> <id1> <id2>       # several from one scan;
                                                      # --json emits NDJSON
vega findings get --scan <scan_id> <finding_id> --full  # adds buggy code,
                                                         # attack path and long sections
vega findings export --scan <scan_id> [--finding <id>]   # markdown report
```

Finding display IDs are repository-local, so `get` requires the scan that
contains them. Fetch `get` only for findings you will act on; use `export` for
a full human-readable report.

Triage is repository-level and requires an explicit repository scope:

```
vega findings mark --repo <repo> pending|valid|invalid|fixed <finding...>
vega findings triage --repo <repo> <status> <finding...>  # mark alias
vega findings mark-fixed --repo <repo> <finding...>
vega findings invalid --repo <repo> <finding...>
vega findings ack --repo <repo> <finding...>              # valid, still open
```

`mark-fixed`, `invalid`, and `ack` are shortcuts for `fixed`, `invalid`, and `valid`.
Multiple IDs run in argument order and are not transactional: on failure,
earlier successful changes remain. With `--json`, multiple results are NDJSON.
These commands change server state; confirm the exact repository, finding IDs,
and desired status with the user before invoking them.

## Cloud findings

`vega cloud findings` reads findings that cloud-sec raised on a customer's
connected cloud accounts. It is a **different resource** from code
findings: no scan/repo, camelCase JSON, lifecycle + disposition instead of
triage. Same conventions apply (columns, `--json`, `--limit`/`--all`, exit
codes). Credentials: a browser sign-in always works. `VEGA_API_KEY` works
once the backend accepts keys on its cloud-sec hop (vega-backend change
`feat/cloudsec-api-key-browser-hop`; a scoped key then needs
`cloudsec:read`). Against an older backend a key gets exit 3 — see below.

```
vega cloud findings list                                  # tenant with one cloud project
vega cloud findings list --project <cloud_project_id>     # every inventory of that project
vega cloud findings list --env <env_id>                   # one inventory (not with --project)
vega cloud findings list --severity critical,high --status open --status in_progress
vega cloud findings list --class exposure --flag new --source agent --sort newest --limit 20
vega cloud findings list --run <run_id>                   # only findings confirmed by that run
vega cloud findings list -q "public bucket" --resource "sec://…"   # search / asset filter
vega cloud findings list --all --json | jq '.findings[] | {findingId, severity, title}'
vega cloud findings get <finding_id> [<id2> …] [--env <env_id>] [--full]
```

Columns: `FINDING_ID SEVERITY RISK STATUS FLAG CLASS RESOURCE TITLE`.
`STATUS` is `open|in_progress|resolved|disposed (<disposition>)`; `FLAG`
is `new|changed|regressed` since the previous analysis; `RESOURCE` is the
first affected asset with `sec://<tenant>/` stripped and `+N` for more.
`--json` list output is the same `{findings, returned_count, total_count,
truncated}` envelope as code findings; rows are the raw backend objects.
`get` prints explanation, suggestion, remediation (markdown) and recheck
history; `--full` adds the attack-path and report JSON. Analysis internals
(rule id, last run id, verification plan, evidence refs, provenance) are
never shown in text mode — customers receive them redacted anyway, and
`--json` still returns whatever the backend sent.

Scope flags take **ids only** and are mutually exclusive: `--project` or
`--env`, never both (clap rejects the pair with exit 2). Omit both when the
tenant has a single cloud project; exit 2 with a hint means several match
and one must be named. Exit 3 with "browser sign-in" means this backend's
cloud-sec hop does not accept API keys (it predates the gate change, or
runs the legacy `idtoken` hop) — run `vega auth login`; setting another
key will not help.

## Patches and pull requests

Patch generation returns immediately by default. Add `--wait` only when the
complete unified diff is needed now:

```
vega findings patch generate <finding-id> --scan <scan-id>
vega findings patch generate <finding-id> --scan <scan-id> --wait
vega findings patch generate <finding-id> --scan <scan-id> --wait -o fix.patch
vega findings patch get <finding-id> --scan <scan-id> [--wait] [-o <file>]
vega findings patch status <finding-id> --scan <scan-id>
```

`generate` reuses an available patch or running task unless `--regenerate` is set, and reports the
reuse on stderr.
`get` never starts generation. `-o` on `generate` requires `--wait`; `-o -`
means stdout. `--json` and file output are mutually exclusive. Waits default to
60 minutes and accept explicit overrides such as `--timeout 30s` / `--timeout 10m`.
Before waiting, the CLI reminds the user that Ctrl+C stops only the local wait and prints the exact
scan-specific `patch get ... --wait` recovery command.

Create a backend GitHub PR (one finding uses the single endpoint; several use
one batch PR with one commit per finding):

```
vega findings pr create <finding-id>... --scan <scan-id> [--timeout 10m]
vega findings pr status [<finding-id>] --scan <scan-id> [--wait]
```

PR creation waits for the PR job by default, but it never generates patches. Every selected
finding must already have an available patch; otherwise the error prints the exact `patch generate`
or `patch get --wait` command needed for each blocked finding. A custom `--commit-message` is valid
only for one finding. The CLI does not touch local Git and does not mark findings fixed.

## Running a scan

```
vega scans run --path . --yes --max-cost 20 --cost-cap 30 --wait
```

Steps performed: index + zip the directory (respects `.vegaignore`) →
upload as a new repository (`--project <p>` attaches it; `--repo <r>`
reuses an existing repository instead of uploading) → wait for snapshot →
cost estimate → consent gate → create scan.

**Cost consent (scans cost real money):**
- The estimate always prints first: `estimated cost: $1.86 (p10 $0.70 – p90 $4.91), …`
- `--max-cost <usd>`: abort with **exit 6** if the estimate exceeds it;
  otherwise counts as consent. This is the safest flag for agents.
- `--yes`: unconditional consent. Without either, a non-TTY run exits 6.
- `--cost-cap <usd>`: independent server-side spend cap (also settable
  later via `vega scans cost-cap <scan_id> <usd>`).
- `--estimate-only` (or `vega scans estimate`): print the estimate and
  stop — free, no scan created.

**Watching progress:**
- default: prints `scan created: scan_…` and returns immediately; poll
  with `vega scans get <scan_id> -s`.
- `--wait`: poll until done; state changes on stderr, final scan detail
  on stdout.
- `--follow`: stream backend events; with `--json` each event is one
  NDJSON line on stdout and the final scan detail is the last line.
- `vega scans follow <scan_id>` attaches to an already-running scan.

## Scan control

```
vega scans pause|resume|cancel|retry <scan_id>    # prints "scan_… <new state>"
vega scans cost-cap <scan_id> <usd>
```

## Exit codes

| code | meaning | typical reaction |
|---|---|---|
| 0 | success | — |
| 1 | API/transport error (incl. 403 permission/billing denials — message says why) | read stderr |
| 2 | usage error / ambiguous name / ambiguous cloud scope | fix arguments, or use the id (`--project`/`--env`) |
| 3 | not authenticated (HTTP 401 / no credential) | `vega auth login` or set `VEGA_API_KEY` |
| 3 | cloud data: "this backend accepts only a browser sign-in" | `vega auth login` — a key will not help on this backend |
| 4 | not found (bad id or unknown name) | check the id |
| 5 | scan ended failed/cancelled under `--wait`/`--follow` | inspect `failure_reason` in the printed detail |
| 6 | cost consent refused or `--max-cost` exceeded | raise `--max-cost` or pass `--yes` |
| 7 | patch/PR wait timed out; backend work continues | run the recovery command printed on stderr |
| 130 | local wait interrupted with Ctrl+C; backend work continues | run the recovery command printed on stderr |

Errors print as `error[<code>]: <message> (request_id=…)` on stderr —
include the `request_id` when reporting backend issues.
