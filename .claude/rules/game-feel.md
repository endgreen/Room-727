---
paths:
  - "**/juice/**"
  - "**/shake/**"
  - "**/screenshake/**"
  - "**/camera_shake*"
  - "**/hit_*"
  - "**/damage_*"
  - "**/freeze_*"
  - "**/trail*"
  - "**/squash*"
---

# Game Feel — Guardrails

AVANT d'écrire du code game feel (screenshake, freeze frame, squash & stretch, hit effects, trails, damage numbers) : **INVOQUER `/godot-juice`**.

## Pièges critiques

- **Camera2D : JAMAIS modifier `position` directement pour le shake** — utiliser `offset`. `position` déplace la caméra, `offset` la secoue sans perdre le cadrage
- **`@export var offset` dans extends Camera2D = Parser Error** — `offset` est un membre natif. Préfixer : `shake_offset`, `follow_offset`
- **Screenshake = gradient noise + quintic**, pas value noise (trop pixelisé) ni `randf()` (trop aléatoire)
- **Freeze frame = `Engine.time_scale`** — minimum safe 0.15 (sinon GolemCapture bloque). Compenser le player avec `delta / Engine.time_scale`
- **Fréquent (hit, collecte) → subtil. Rare (level up, game over) → dramatique** — l'intensité du juice correspond à la rareté de l'événement
- **Tween sur node qui va mourir → `get_tree().create_tween()`** — lié à l'arbre, survit au node
- **`add_child(Area2D)` dans callback physique → `call_deferred`** — sinon crash physics flush
