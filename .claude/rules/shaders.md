---
paths:
  - "**/*.gdshader"
  - "**/vfx/**"
  - "**/particles/**"
  - "**/lighting/**"
  - "**/effects/**"
  - "**/juice/**"
  - "**/shake/**"
  - "**/screenshake/**"
  - "**/camera_shake*"
  - "**/hit_*"
  - "**/damage_*"
  - "**/freeze_*"
  - "**/trail*"
  - "**/squash*"
  - "**/audio/**"
  - "**/sfx/**"
  - "**/music/**"
  - "**/sound/**"
  - "**/*_audio*"
  - "**/*_sfx*"
  - "**/*_music*"
---

# VFX, Game Feel & Audio — Guardrails

Avant d'implémenter du VFX, game feel, ou audio : lire le skill correspondant (`.claude/skills/godot-vfx.md`, `.claude/skills/godot-juice.md`, `.claude/skills/godot-audio.md`).

## Shaders & Lighting

- **Shader = surface, JAMAIS lumiere** — canvas_item = surface. PointLight2D = lumiere. Mixer = double-bubble artifacts
- **Gradient PointLight2D = RGB opaque** (blanc→noir), pas alpha (ring artifacts). Interpolation CUBIC, max 3 stops, texture 512x512 min
- **`floor(TIME * speed)` = pixels carres qui flickent** — toujours `sin(TIME)` / `cos(TIME)` pour animations shader
- **CanvasModulate max (0.02, 0.02, 0.02)** — au-dela, bord du halo visible
- **Mobile renderer = banding sur gradients subtils** — Forward+ ou PNG avec dithering
- **GPUParticles2D sans `draw_pass` = invisible** — toujours ajouter un QuadMesh comme `draw_pass_1`
- **`color_ramp`, `scale_min/max` = sur `ParticleProcessMaterial`** — PAS sur `GPUParticles2D`
- **Flipbook sans `BLEND_MODE_ADD`** = carres noirs autour des particules
- **ColorRect fullscreen shader = base color transparent** — default `Color.WHITE` + GPU hiccup = flash blanc. Fix : `color = Color(0, 0, 0, 0)` dans `_ready()`
- **VFX : demarrer a 20% d'intensite** — augmenter ensuite. Plus facile que diagnostiquer un ecran noir

### Naming conventions
- `shd_` pour les shaders : `shd_water_stylized.gdshader`
- `mat_` pour les materials : `mat_water_stylized.tres`
- `tex_` pour les textures VFX : `tex_noise_01.png`

### Shader params obligatoires (prod)
Tout shader prod doit exposer au minimum :
```gdshader
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform float scale : hint_range(0.1, 5.0) = 1.0;
uniform int debug_view : hint_range(0, 3) = 0;
```
Sans ces params, le shader est un prototype — pas shippable.

### Debug view pattern
Visualiser chaque etape du shader pour diagnostiquer sans deviner :
```gdshader
uniform int debug_view : hint_range(0, 3) = 0;
// 0 = off, 1 = UV, 2 = mask, 3 = noise

void fragment() {
    // ... calculs normaux ...
    if (debug_view == 1) { COLOR = vec4(UV, 0.0, 1.0); return; }
    if (debug_view == 2) { COLOR = vec4(vec3(mask), 1.0); return; }
    if (debug_view == 3) { COLOR = vec4(vec3(noise), 1.0); return; }
}
```
**Tester sur fond clair ET fond sombre** — certains bugs ne sont visibles que sur l'un des deux.

### Visual Shader → Code workflow
- **Visual Shader** = prototypage rapide, iteration, transmission a d'autres (artistes)
- **Shader code** = complexite, perf fine, patterns reutilisables, version control propre
- **Regle** : prototype en Visual Shader → si critique/perf ou reutilise, porter en code. Ne pas commencer en code sauf si le pattern est deja connu

## Game Feel

- **Camera2D : JAMAIS `position` pour le shake** — utiliser `offset`. `position` deplace, `offset` secoue sans perdre le cadrage
- **`@export var offset` dans extends Camera2D = Parser Error** — membre natif. Prefixer : `shake_offset`, `follow_offset`
- **Screenshake = gradient noise + quintic** — pas value noise (pixelise) ni `randf()` (trop aleatoire)
- **Freeze frame = `Engine.time_scale`** — minimum safe 0.15 (GolemCapture bloque en-dessous). Compenser player avec `delta / Engine.time_scale`
- **Frequent = subtil, rare = dramatique** — l'intensite du juice correspond a la rarete de l'evenement
- **Tween sur node mourant → `get_tree().create_tween()`** — lie a l'arbre, survit au node
- **`add_child(Area2D)` dans callback physique → `call_deferred`** — sinon crash physics flush

## Audio

- **Bus layout = Master/Music/SFX minimum** — ne pas tout mettre sur Master
- **`AudioServer.get_bus_index()` peut retourner -1** — guard clause avant `get_bus_effect()`
- **SFX throttle obligatoire** — meme son 10x dans le meme frame = distorsion. Pool + cooldown
- **Crossfade musique = 2 AudioStreamPlayer** — fade out l'un, fade in l'autre. Pas d'arret brutal
- **Volume UI = `linear_to_db()` / `db_to_linear()`** — slider lineaire, AudioServer attend des dB
- **Spatial audio 2D = `max_distance`** — defaut 2000px, souvent trop
