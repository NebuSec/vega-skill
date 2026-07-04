---
name: vega-cli
description: Query Vega security-scan results and run security scans from
  the command line. Use when asked to scan code with Vega, check scan
  progress or cost, or list/inspect security findings for a project,
  repository, or scan. Provides projects/repos/scans/findings subcommands
  with agent-friendly text output and raw-JSON mode.
---

# Vega CLI

`vega` audits code for security vulnerabilities on the Vega backend. Every
subcommand is non-interactive and designed for programmatic use:

- **stdout carries data only** — aligned columns for lists, markdown-style
  sections for details. Progress, warnings, and errors go to **stderr**.
- Add the global `--json` flag to any command to get the **raw backend
  JSON response** instead (compact, one object/array per line).
- IDs are self-describing: projects `pg_…`, repositories `proj_…`, scans
  `scan_…`, findings `finding_…`. Wherever a `<project>` or `<repo>`
  argument is accepted, a unique name works too.
- `vega <noun> --help` lists each subcommand; singular aliases work
  (`vega scan run` = `vega scans run`).

## Install

The `vega` binary must be on PATH. If `command -v vega` fails, install the
latest release (Linux/macOS, x64/arm64):

```
curl -fsSL https://raw.githubusercontent.com/NebuSec/vega-skill/main/install.sh | sh
```

Installs to `~/.local/bin` (override with `VEGA_INSTALL_DIR`; pin a version
with `VEGA_VERSION=vX.Y.Z`). With Node.js available,
`npm install -g @nebusec/vega-cli` works too. Binaries are also
downloadable directly from
<https://github.com/NebuSec/vega-skill/releases>.

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

vega scans list [--limit N]          # workspace-wide
vega scans get <scan_id> [--live]    # detail; --live adds live cost/progress
vega scans get <scan_id> -s          # ONE line — cheapest way to poll:
# scan_NtWy… running 49% "Auditing auth module" findings=8 cost=$260.73
```

## Findings

```
vega findings list --scan <scan_id>            # or --project <p> / --repo <r>
# FINDING_ID     SEV     CONF  STATUS     FILE                TITLE
# finding_d0c7…  medium  high  candidate  app/…/inline.py     Inline publish does…
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
vega findings get <finding_id>          # summary/root cause/evidence/fix
                                        # (finding ids are globally unique)
vega findings get <id1> <id2> <id3>     # several at once — text separates
                                        # with ---, --json emits NDJSON
vega findings get <finding_id> --full   # adds buggy code, attack path,
                                        # root-cause sections (long!)
vega findings export --scan <scan_id> [--finding <id>]   # markdown report
```

Fetch `get` only for findings you will act on; use `export` for a full
human-readable report.

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
| 2 | usage error / ambiguous name | fix arguments, or use the id |
| 3 | not authenticated (HTTP 401 / no credential) | `vega auth login` or set `VEGA_API_KEY` |
| 4 | not found (bad id or unknown name) | check the id |
| 5 | scan ended failed/cancelled under `--wait`/`--follow` | inspect `failure_reason` in the printed detail |
| 6 | cost consent refused or `--max-cost` exceeded | raise `--max-cost` or pass `--yes` |

Errors print as `error[<code>]: <message> (request_id=…)` on stderr —
include the `request_id` when reporting backend issues.
