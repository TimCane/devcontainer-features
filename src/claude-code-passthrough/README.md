
# Claude Code (with host credential passthrough) (claude-code-passthrough)

Installs Anthropic's Claude Code CLI and bind-mounts the host's ~/.claude/.credentials.json into the container so you don't have to re-authenticate.

## Example Usage

```json
"features": {
    "ghcr.io/TimCane/devcontainer-features/claude-code-passthrough:0": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| claudeVersion | Version of @anthropic-ai/claude-code to install from npm (e.g. 'latest', '1.2.3'). | string | latest |
| nodeVersion | Informational only. The node feature dependency is pinned to 'lts'; to override, add ghcr.io/devcontainers/features/node yourself with the desired version. | string | lts |
| passthroughHostAuth | If true, wire the host's Claude Code auth into the container at postCreate: symlink ~/.claude/.credentials.json (so token refreshes flow back to the host) and copy ~/.claude.json (account/onboarding state — copied, not linked, because Claude rewrites it constantly with container-local paths). Both halves are needed together; either alone leaves Claude broken. The bind mounts are always declared; this flag only controls whether link/copy runs. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/TimCane/devcontainer-features/blob/main/src/claude-code-passthrough/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
