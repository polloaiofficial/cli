# Pollo CLI installer

This repo hosts **only the install script** for the [Pollo AI](https://pollo.ai)
CLI, so that `curl | sh` has a stable, readable URL you can read before running.

The binary itself comes from the **npm registry** — the very same per-platform
packages that `npm i -g @pollo-ai/cli` installs. The registry is the single
source of truth for releases, so this script has no version pointer of its own
to drift out of sync, and it verifies the download against the registry's
`dist.integrity` (sha512) exactly as npm would.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/polloaiofficial/cli/main/install.sh | sh
```

macOS and Linux, on x86-64 and arm64. **On Windows, install from npm** (below).

If your organisation installs through a private or proxying registry rather than
npmjs.org, point the script at it with `POLLO_REGISTRY` (see
[Overrides](#overrides)).

## Install from npm

Covers Windows as well, and needs no shell script:

```bash
npm i -g @pollo-ai/cli
```

The npm package is a thin Node shim; the binary ships in per-platform packages
declared as `optionalDependencies`, so npm installs only the one matching your
machine. Nothing is fetched in a `postinstall` hook.

## Then

```bash
pollo auth login
pollo --help
```

## Overrides

| Variable | Effect |
| --- | --- |
| `POLLO_CLI_VERSION` | Pin a version instead of npm's `latest` |
| `POLLO_INSTALL_DIR` | Install directory (default `/usr/local/bin` if writable, else `~/.local/bin`) |
| `POLLO_REGISTRY` | Registry base URL, for private or proxying registries. Public mirrors often lag a fresh release, so a new version may 404 there for a while |

`install.sh` detects your OS/arch, resolves the version from npm's `latest`
dist-tag, downloads that platform's package and verifies it against the
registry's sha512 before installing. It carries no version of its own, so
cutting a release never means touching this file.

## Agent skills

To teach an AI coding agent to drive this CLI:

```bash
npx skills add polloaiofficial/skills
```
