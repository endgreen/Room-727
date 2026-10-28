---
paths: []
---
# Multi-agent — Orchestration game dev

- **Fichiers goulots** — avant de paralléliser des livrables, mapper quels fichiers sont modifiés par chaque agent. Même fichier modifié par 2+ agents = interdit en parallèle (sauf `event_bus.gd` par section et `project.godot` par ligne distincte)
- **Instructions agents** — chaque agent reçoit `FILES YOU OWN` (créer/modifier) et `DO NOT MODIFY` (touché par un autre agent)
- **Vérification post-merge** — toujours vérifier `event_bus.gd` (signaux dupliqués), `project.godot` (autoloads), `.tscn` partagés (conflits nodes/ext_resources)
- **Patterns détaillés** — voir `references/workflow_patterns.md`
