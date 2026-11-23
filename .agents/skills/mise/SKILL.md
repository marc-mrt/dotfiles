---
name: mise
description: How to prepare a dotfiles (chezmoi) worktree and what proves a change in it.
---

## Install
None — dependency installs are not detected in this repo. Fonts and tooling live on the machine; verify with `sh ~/.claude/skills/dev-worktree-toolkit/scripts/detect.sh <worktree>`.

## Services
None. The live Quickshell (`qs -c ~/.config/quickshell`, started by Hyprland autostart) is a verification target, not a service to start; `.agents/skills/verify/apply-check.sh <worktree>` applies a branch to it and checks the reload.

## Check
- Font/scale surface: `sh .agents/skills/verify/font-check.sh --source <worktree>` (read-only source mode; no arguments checks the live session).
- Quickshell surface: `sh .agents/skills/verify/apply-check.sh <worktree>` (mutates live Quickshell — run only when a live apply is intended).
- Single entry points: `node private_dot_config/quickshell/modules/pad/searchScore.test.mjs` and `bash dot_local/bin/capture.test.sh`.
- Other verify entry points and live-driving commands (IPC, layers, notifications): `.agents/skills/verify/SKILL.md`.

## Gate
`node private_dot_config/quickshell/modules/pad/searchScore.test.mjs` and `bash dot_local/bin/capture.test.sh`. No pre-commit hook is configured and no dependency install is needed.

## Standards
/home/marc/.agents/AGENTS.md — working persona: pragmatic, first-principles, smallest effective change.
/home/marc/.claude/CLAUDE.md — Marc's session rules (draft PRs, AGENTS.md import).
README.md — repo purpose and chezmoi bootstrap.
