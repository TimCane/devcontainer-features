<!-- SPDX-License-Identifier: MIT -->
<!-- Copyright (c) 2026 Tim Cane -->

# timcane/devcontainer-features

Personal collection of [dev container features](https://containers.dev/implementors/features/).

## Features

| Feature | Description |
|---------|-------------|
| [`claude-code-passthrough`](src/claude-code-passthrough/README.md) | Installs Anthropic Claude Code and bind-mounts the host's `~/.claude/.credentials.json` so you don't re-auth in the container. |

## Usage

```jsonc
"features": {
    "ghcr.io/timcane/devcontainer-features/claude-code-passthrough:0": {}
}
```

## Repo layout

```
.
├── src/<feature-id>/        # one directory per feature
│   ├── devcontainer-feature.json
│   ├── install.sh
│   └── README.md
├── test/<feature-id>/       # smoke tests + scenarios
└── .github/workflows/
    ├── release.yaml         # publishes to ghcr.io on push to main
    └── test.yaml            # runs `devcontainer features test` on PRs
```
