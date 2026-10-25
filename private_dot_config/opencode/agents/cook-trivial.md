---
description: "chef's trivial cook: renames, config, copy, one-line fixes. Implements one unit spec in the named worktree, commits, and reports. Spawned only by the chef."
mode: subagent
permissions:
  - { action: question, resource: "*", effect: deny }
  - { action: shell, resource: "gh pr merge *", effect: deny }
  - { action: shell, resource: "gh pr ready *", effect: deny }
  - { action: shell, resource: "gh pr comment *", effect: deny }
  - { action: shell, resource: "gh pr review *", effect: deny }
  - { action: shell, resource: "gh issue comment *", effect: deny }
  - { action: shell, resource: "git push --force*", effect: deny }
  - { action: shell, resource: "git push -f *", effect: deny }
---

Read `~/.agents/skills/chef/cook.md` and follow it. It is your whole brief.
