---
paths:
  - "**/audio/**"
  - "**/sfx/**"
  - "**/music/**"
  - "**/sound/**"
  - "**/*_audio*"
  - "**/*_sfx*"
  - "**/*_music*"
---

# Audio — Guardrails

AVANT d'écrire du code audio (bus, musique, SFX, spatial, volume) : **INVOQUER `/godot-audio`**.

## Pièges critiques

- **Bus layout = Master/Music/SFX minimum** — ne pas tout mettre sur Master
- **`AudioServer.get_bus_index()` peut retourner -1** — toujours guard clause avant `get_bus_effect()`
- **SFX throttle obligatoire** — même son joué 10x dans le même frame = distorsion. Pool + cooldown
- **Crossfade musique = 2 AudioStreamPlayer** — fade out l'un, fade in l'autre. Pas d'arrêt brutal
- **Volume UI = `linear_to_db()` / `db_to_linear()`** — le slider est linéaire, AudioServer attend des dB
- **Spatial audio 2D = `max_distance` sur AudioStreamPlayer2D** — par défaut c'est 2000px, souvent trop
