# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClodPod is a macOS VM sandbox for running AI agents (Claude Code, Codex, Gemini, Cursor) in isolation. It uses [Tart](https://tart.run/) for Apple Silicon VM management, maps host project directories into VMs via volume mounts, and connects via SSH.

## Commands

```bash
# Run all tests
./scripts/tests

# Run tests silently
VERBOSE=0 ./scripts/tests

# Lint the main script (run from repo root so .shellcheckrc is picked up)
shellcheck clod

# Run clod locally (from repo root)
./clod <command>
```

There is no build step. The project is a Bash script (`clod`) with supporting shell scripts.

## Architecture

**`clod`** — Single monolithic Bash script (~1200 lines) containing all logic: CLI parsing, SQLite project database, VM lifecycle (clone/run/stop/delete), SSH key management, and guest configuration. Must maintain Bash 3.2 compatibility (macOS system bash).

**Two-layer VM caching:**
1. **Base image** — OS + packages (shared across projects, slow to build, cached as `clodpod-xcode-base`)
2. **Destination image** — Base + user config (cloned from base, cached as `clodpod-xcode`)

**Named VMs** (`--vm-name`) skip the rebuild pipeline entirely — they clone from the destination image. Used for orchestrator dispatch (e.g. `clodpod-issue-123`). Named VMs also skip directory mappings and project checks.

**Directory mapping** — Host project directories are mounted into the guest at `/Users/clodpod/projects/<name>` via Tart `--dir` flags. Multiple projects can be mapped simultaneously.

**Environment forwarding** — `GITHUB_TOKEN`, `GITHUB_REPO`, `GITHUB_BRANCH`, and `GITHUB_ISSUE` are forwarded from host to guest SSH session when set.

**`guest/`** — Files copied into VMs:
- `install.sh` — Runs on base image: installs brew packages, dev tools
- `configure.sh` — Runs on destination image: creates clodpod user, copies config
- `home/` — Dotfiles, SSH keys, and wrapper scripts deployed to guest `~clodpod/`

**`scripts/`** — Developer tooling: `tests` (custom Bash test framework with mocked externals), `setup` (install dev dependencies), `bump-version` (semver + git tag)

## Key Conventions

- **Bash 3.2 compatibility** — No associative arrays, no `${var,,}`, use `${array[@]+"${array[@]}"}` for safe empty array expansion
- **ShellCheck is mandatory** — Config in `.shellcheckrc` enables extra checks (require-double-brackets, avoid-nullary-conditions, etc.)
- **Error handling** — Scripts use `set -Eeuo pipefail` with ERR trap
- **Logging** — Use existing `debug`, `info`, `warn`, `error` functions (color-coded, respect VERBOSE level)
- **Tests mock external commands** — Tests create stubs in a temp `$MOCK_BIN` directory for `brew`, `tart`, `jq`, `netcat`, `rush` to avoid real VM operations
- **SQLite for state** — Project list and settings stored in `.clodpod.sqlite` via `sqlite3` CLI

## Host Dependencies

tart, brew, jq, netcat, rush (GNU Restricted User Shell), sqlite3
