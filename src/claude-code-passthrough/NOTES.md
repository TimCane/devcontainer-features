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
- This feature `dependsOn` the official `node` feature.

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

### Windows hosts

The bind-mount sources resolve `${localEnv:HOME}` with a fallback to
`${localEnv:USERPROFILE}` so they work on Windows hosts where `HOME`
isn't set. If you see mount errors on Windows, confirm that
`%USERPROFILE%\.claude\.credentials.json` exists.
