# Dotfiles

My dotfiles, managed by [chezmoi](https://www.chezmoi.io/).

## Bootstrap

`~/Code/chef` comes in as a private git-repo external, so give git GitHub credentials before the first apply:

```sh
gh auth login && gh auth setup-git
chezmoi init --apply marc-mrt/dotfiles
```

## Machine layer

This repo holds only what every machine shares. Anything that differs per machine stays on the machine:

- opencode's providers, default model, MCP servers and per-agent models go in the system config, which opencode merges over `~/.config/opencode/opencode.jsonc`: `/etc/opencode/opencode.json` on Linux, `/Library/Application Support/opencode/opencode.json` on macOS. Set an agent's model with `"agents": { "cook-hard": { "model": "provider/model" } }`.
- regarde's `~/.config/regarde/config.toml` is ignored here.
