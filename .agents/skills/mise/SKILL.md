---
name: mise
description: How to prepare a chezmoi dotfiles worktree and what proves a change in it.
---

## Install
None — no dependency install; the chef detector found no recognized manifest. Fonts and tooling live on the machine; verify with `sh ~/.claude/skills/dev-worktree-toolkit/scripts/detect.sh <worktree>`.

## Services
None. The live Quickshell (`qs -c ~/.config/quickshell`, started by Hyprland autostart) is a verification target, not a service to start; `.agents/skills/verify/apply-check.sh <worktree>` applies a branch to it and checks the reload.

## Check
- Font/scale surface: `sh .agents/skills/verify/font-check.sh --source <worktree>` (read-only source mode; no arguments checks the live session).
- Quickshell surface: `sh .agents/skills/verify/apply-check.sh <worktree>` (mutates live Quickshell — run only when a live apply is intended).
- No CI workflow, Makefile or pre-commit hook; single entry points: `node private_dot_config/quickshell/modules/pad/searchScore.test.mjs` and `bash dot_local/bin/capture.test.sh`.
- GTK/CSS changes additionally use an isolated-HOME render plus a real GTK3/GTK4 `CssProvider` parse, and `chezmoi --source <worktree> apply --dry-run`.
- Other verify entry points and live-driving commands (IPC, layers, notifications): `.agents/skills/verify/SKILL.md`.

## Gate
```
bash -n private_dot_config/hypr/theme/executable_apply-theme.sh
chezmoi --source <worktree> apply --dry-run
node private_dot_config/quickshell/modules/pad/searchScore.test.mjs
bash dot_local/bin/capture.test.sh
```
No pre-commit hook is configured and no dependency install is needed.

## Standards
`dot_agents/AGENTS.md` — pragmatic first-principles, systems over symptoms, speed plus quality (imported by `/home/marc/.agents/AGENTS.md`).
`dot_claude/CLAUDE.md` — draft PRs; imports AGENTS.md.
`README.md` — repo purpose and chezmoi bootstrap.
