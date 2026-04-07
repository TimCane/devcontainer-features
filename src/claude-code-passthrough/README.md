<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Tim Cane -->

# Claude Code (with host credential passthrough) (`claude-code-passthrough`)

Installs [Anthropic Claude Code](https://docs.claude.com/claude-code) into your dev container and passes through your host's Claude Code authentication (`~/.claude/.credentials.json` + `~/.claude.json`) so you don't have to re-authenticate or re-onboard inside the container.

## Example Usage

```jsonc
"features": {
    "ghcr.io/timcane/devcontainer-features/claude-code-passthrough:0": {}
}
```

## Options

| Option                | Type    | Default  | Description |
|-----------------------|---------|----------|-------------|
| `version`             | string  | `latest` | Version of `@anthropic-ai/claude-code` to install from npm. |
| `nodeVersion`         | string  | `lts`    | Informational. The node dependency is pinned to `lts`; override by adding the node feature yourself. |
| `passthroughHostAuth` | boolean | `true`   | Whether to pass the host's Claude Code auth into the container on first start (symlink `~/.claude/.credentials.json`, copy `~/.claude.json`). Both halves are needed together — credentials alone re-runs onboarding, account state alone is unauthenticated — so this is one switch. |

## Prerequisite — the host files MUST exist before first build

This feature declares bind mounts from `${localEnv:HOME}/.claude/.credentials.json` and `${localEnv:HOME}/.claude.json` on the host. **Docker silently creates an empty directory at a mount source if the file does not exist**, which will then break the helper at container start with a clear error.

Before your first `devcontainer build`, run on the host:

```bash
mkdir -p ~/.claude && touch ~/.claude/.credentials.json ~/.claude.json
```

…or just run `claude` once on the host and authenticate normally (which creates both files for you).

## How it works

1. `dependsOn` pulls in `ghcr.io/devcontainers/features/node` so `npm` is available.
2. `install.sh` runs `npm i -g @anthropic-ai/claude-code@<version>` and stages the helper at `/usr/local/share/claude-code-passthrough/link-credentials.sh`.
3. The feature declares two bind mounts into `/usr/local/share/claude-code-passthrough/`: host `~/.claude/.credentials.json` and host `~/.claude.json`.
4. At container start, `postCreateCommand` runs the helper, which **symlinks** `$HOME/.claude/.credentials.json` → the bind-mounted credentials file (so token refreshes write back to the host) and **copies** the bind-mounted `~/.claude.json` to `$HOME/.claude.json` on first start (copied, not linked, because Claude Code rewrites it constantly and live-linking would pollute the host file with container-specific state).

The credentials mount is **read-write** so Claude Code can refresh OAuth tokens; refreshed tokens write straight back to the host file.

## Caveats

- **The bind mounts are always declared** by this feature. Setting `passthroughHostAuth=false` only skips the symlink/copy step — the mounts themselves still happen. To fully opt out, omit the feature.
- **`nodeVersion` is informational only.** Devcontainer features cannot template option values into `dependsOn`, so the node feature is pinned to `lts`. To use a different version, add `ghcr.io/devcontainers/features/node` yourself with the desired version *before* this feature in your `devcontainer.json`.
- **Read-write mount** means a compromised container could overwrite your host credentials. This is the trade-off for not breaking token refresh.
- **Host-only.** The mount source is a host path, so this feature is only useful for local dev containers — not for Codespaces or other remote builds where the host is ephemeral.
