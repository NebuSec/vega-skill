# Vega CLI — agent skill & binary distribution

Vega CLI is a developer- and automation-friendly command-line tool for running Vega security scans, tracking scan progress and cost, and inspecting projects, repositories, scans, and findings from the terminal.

This repository distributes the **agent skill** and the **prebuilt binaries**.

## Install the skill

**Claude Code** (plugin):

```
/plugin marketplace add NebuSec/vega-skill
/plugin install vega-cli@nebusec
```

**Codex** (skill-installer):

```
$skill-installer install https://github.com/NebuSec/vega-skill/tree/main/skills/vega-cli
```

**Any agent** ([`npx skills`](https://github.com/vercel-labs/skills)):

```
npx skills add NebuSec/vega-skill
```

## Install the binary

The skill instructs agents to bootstrap the binary automatically. To install it yourself:

```
curl -fsSL https://raw.githubusercontent.com/NebuSec/vega-skill/main/install.sh | sh
```

Installs the latest release to `~/.local/bin`. Options via environment:`VEGA_VERSION=vX.Y.Z` pins a release, `VEGA_INSTALL_DIR` changes the target directory.

Or via npm (requires Node.js ≥ 18):

```
npm install -g @nebusec/vega
```

Release assets, if you prefer manual download:

| asset | platform |
|---|---|
| `vega-linux-x64.tar.gz` | Linux x86_64 (static musl build) |
| `vega-linux-arm64.tar.gz` | Linux aarch64 (static musl build) |
| `vega-darwin-x64.tar.gz` | macOS Intel |
| `vega-darwin-arm64.tar.gz` | macOS Apple Silicon |

## Getting started

```
vega auth login          # or export VEGA_API_KEY=vega_…
vega scans run --path . --max-cost 20
```

See [`skills/vega-cli/SKILL.md`](skills/vega-cli/SKILL.md) for the full command reference.
