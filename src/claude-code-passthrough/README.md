<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Tim Cane -->

# Claude Code (with host credential passthrough) (`claude-code-passthrough`)

Installs [Anthropic Claude Code](https://docs.claude.com/claude-code) into your dev container and bind-mounts your host's `~/.claude/.credentials.json` so you don't have to re-authenticate inside the container.

## Example Usage

```jsonc
"features": {
    "ghcr.io/timcane/devcontainer-features/claude-code-passthrough:0": {}
}
```

## Options

| Option             | Type    | Default  | Description |
|--------------------|---------|----------|-------------|
| `version`          | string  | `latest` | Version of `@anthropic-ai/claude-code` to install from npm. |
| `nodeVersion`      | string  | `lts`    | Informational. The node dependency is pinned to `lts`; override by adding the node feature yourself. |
| `mountCredentials` | boolean | `true`   | Whether to symlink the bind-mounted host credentials into `$HOME/.claude/.credentials.json` at container start. |

## Prerequisite — the host credentials file MUST exist before first build

This feature declares a bind mount from `${localEnv:HOME}/.claude/.credentials.json` on the host. **Docker silently creates an empty directory at the mount source if the file does not exist**, which will then break the symlink step at container start with a clear error.

Before your first `devcontainer build`, run on the host:

```bash
mkdir -p ~/.claude && touch ~/.claude/.credentials.json
```

…or just run `claude` once on the host and authenticate normally (which creates the file for you).

## How it works

1. `dependsOn` pulls in `ghcr.io/devcontainers/features/node` so `npm` is available.
2. `install.sh` runs `npm i -g @anthropic-ai/claude-code@<version>` and stages a helper script at `/usr/local/share/claude-code/link-credentials.sh`.
3. The feature declares a bind mount: host `~/.claude/.credentials.json` → container `/usr/local/share/claude-code/.credentials.json`.
4. At container start, the `postCreateCommand` runs the helper, which symlinks `$HOME/.claude/.credentials.json` → the bind-mounted file.

The mount is **read-write** so Claude Code can refresh OAuth tokens; refreshed tokens write straight back to the host file.

## Caveats

- **The bind mount is always declared** by this feature. Setting `mountCredentials=false` only skips the symlink step — the mount itself still happens. To fully opt out, omit the feature.
- **`nodeVersion` is informational only.** Devcontainer features cannot template option values into `dependsOn`, so the node feature is pinned to `lts`. To use a different version, add `ghcr.io/devcontainers/features/node` yourself with the desired version *before* this feature in your `devcontainer.json`.
- **Read-write mount** means a compromised container could overwrite your host credentials. This is the trade-off for not breaking token refresh.
- **Host-only.** The mount source is a host path, so this feature is only useful for local dev containers — not for Codespaces or other remote builds where the host is ephemeral.
