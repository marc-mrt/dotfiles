---
description: "chef's {{ .tier }} cook: {{ .job }} Implements one unit spec in the named worktree, commits, and reports. Spawned only by the chef."
mode: subagent
model: {{ .model }}
{{- if .effort }}
reasoningEffort: {{ .effort }}
{{- end }}
permission:
  question: deny
  bash:
    "*": allow
    "gh pr merge*": deny
    "gh pr ready*": deny
    "gh pr comment*": deny
    "gh pr review*": deny
    "gh issue comment*": deny
    "git push --force*": deny
    "git push -f*": deny
---

Read `~/.agents/skills/chef/cook.md` and follow it. It is your whole brief.
