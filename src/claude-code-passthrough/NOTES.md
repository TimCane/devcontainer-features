## How it works

This feature does two things:

1. **Installs `@anthropic-ai/claude-code` from npm** at image build time.
2. **Wires the host's Claude Code auth into the container** at `postCreate`:
   - `~/.claude/.credentials.json` is **symlinked** so OAuth token refreshes
     flow back to the host.
   - `~/.claude.json` (account/onboarding state) is **copied** on first
     start only — Claude rewrites it constantly with container-local paths,
     so live-linking would pollute the host file.

Both halves are needed together: either alone leaves Claude broken. The
bind mounts are always declared; `passthroughHostAuth=false` only skips
the link/copy step at `postCreate`.

## Requirements

- The host must have authenticated Claude Code at least once before the
  dev container is **first built**, so that `~/.claude/.credentials.json`
  and `~/.claude.json` exist as files. If they don't exist, Docker will
  silently create empty directories at the bind-mount source and Claude
  will fail to start in the container.
- This feature `dependsOn` the official `node` feature (pinned to `lts`).

## Customizing the Node version

The `dependsOn` entry on `ghcr.io/devcontainers/features/node` is pinned
to `lts` and cannot be parameterized — the devcontainer spec evaluates
`dependsOn` statically, before feature options are bound, so this
feature has no way to forward an option value into it.

To use a different Node version, declare the node feature yourself in
your `devcontainer.json` alongside this one. Your declaration satisfies
the `dependsOn` and wins:

```json
"features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "20" },
    "ghcr.io/TimCane/devcontainer-features/claude-code-passthrough:0": {}
}
```

## Troubleshooting

### "ERROR: ... is a DIRECTORY, not a file"

The host file did not exist when the container was first built, so
Docker auto-created an empty directory at the bind-mount source.

**Fix:**
1. On the host, authenticate Claude Code once (`claude` then sign in).
   This creates `~/.claude/.credentials.json` and `~/.claude.json`.
2. **Dev Containers: Rebuild Container** (a plain restart is not enough —
   the bind-mount source has to be re-resolved).

### Claude prompts to log in inside the container even though I'm logged in on the host

Check that `passthroughHostAuth` is not set to `false` in your
`devcontainer.json`. If it isn't, verify on the host that
`~/.claude/.credentials.json` exists and is readable by your user.

### Warnings about the native installer

The npm build of Claude auto-migrates to a native launcher in the
background. This feature pre-creates a shim at `~/.local/bin/claude`
pointing at the npm binary so the self-check stays quiet until the
real native launcher arrives. No action needed.

## Uninstalling / cleanup

Dev container features bake into image layers, so there is no in-place
"uninstall" — removal happens at the `devcontainer.json` level and the
container is rebuilt clean.

1. **Remove the feature entry** from `devcontainer.json`:
   ```json
   "features": {
     "ghcr.io/TimCane/devcontainer-features/claude-code-passthrough:0": {}
   }
   ```
   Delete that line. If you also want to drop the Node feature this one
   pulled in via `dependsOn`, remove your own explicit `node` entry too.

2. **Rebuild the container** (Dev Containers: Rebuild Container). The new
   image will not contain `@anthropic-ai/claude-code`, the `/opt/claude-code-passthrough/`
   staging dir, the `~/.local/bin/claude` shim, or the bind mounts.

3. **Host side** is untouched — `~/.claude/.credentials.json` and
   `~/.claude.json` belong to the host's Claude Code install and remain
   exactly as they were. To remove host-side state, run `claude logout`
   on the host (or delete those two files manually).

4. **Container-local `~/.claude.json`** lived inside the container and
   goes away with the rebuild. It was a copy, never linked back, so
   nothing is left behind on the host.

If you only want to disable passthrough without uninstalling, set
`"passthroughHostAuth": false` instead — the bind mounts stay declared
(features can't opt out of their own mounts) but the helper skips the
symlink and seed.

### Windows hosts

The bind-mount sources resolve `${localEnv:HOME}` with a fallback to
`${localEnv:USERPROFILE}` so they work on Windows hosts where `HOME`
isn't set. If you see mount errors on Windows, confirm that
`%USERPROFILE%\.claude\.credentials.json` exists.
