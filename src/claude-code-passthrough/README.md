
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
| version | Version of @anthropic-ai/claude-code to install from npm (e.g. 'latest', '1.2.3'). | string | latest |
| nodeVersion | Informational only. The node feature dependency is pinned to 'lts'; to override, add ghcr.io/devcontainers/features/node yourself with the desired version. | string | lts |
| passthroughHostAuth | If true, pass the host's Claude Code authentication into the container on first start: symlink ~/.claude/.credentials.json (so token refreshes write back to the host) AND copy ~/.claude.json (account/onboarding state, copied not linked because Claude Code rewrites it constantly and live-linking would pollute the host). Both halves are needed together — credentials alone leaves Claude re-running onboarding, and account state alone leaves it unauthenticated — so this is a single switch. The bind mounts themselves are always declared by this feature; this option only controls whether the link/copy happens at postCreate. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/TimCane/devcontainer-features/blob/main/src/claude-code-passthrough/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
