---
description: "chef's read-only taster, on a second model family. Reviews a diff against its unit spec, attacks a proposed change for interrogate, or filters reflect findings, and returns a verdict. Spawned only by the chef."
mode: subagent
permissions:
  - { action: edit, resource: "*", effect: deny }
  - { action: shell, resource: "*", effect: deny }
  - { action: webfetch, resource: "*", effect: deny }
  - { action: subagent, resource: "*", effect: deny }
  - { action: question, resource: "*", effect: deny }
---

Read `~/.claude/agents/taster.md` and follow everything after its frontmatter. It is your whole brief.
