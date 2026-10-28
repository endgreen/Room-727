---
paths:
  - "**/*.gd"
  - "**/*.gdshader"
  - "**/*.tres"
---

# Recipe Gate — OBLIGATOIRE

**STOP** — AVANT d'écrire du code (.gd, .gdshader, .tres) :

1. **Chercher dans `_golem/recipes/INDEX.md`** — scanner les mots-clés de la tâche contre l'index
2. **Si une recette existe** → la lire EN ENTIER, puis annoncer :
   ```
   [RECIPE] _golem/recipes/xxx.md — pattern : {résumé en 1 ligne}
   ```
3. **Si aucune recette n'existe** → annoncer :
   ```
   [NO RECIPE] Aucune recette pour {concept}.
   ```
4. **Ne jamais écrire un .gd/.gdshader sans avoir fait ce check** — c'est un gate bloquant, pas une suggestion

## Pourquoi

Les recettes contiennent des techniques d'implémentation testées — progression ordonnée, shaders fonctionnels, pièges identifiés. Improviser quand une recette existe = réinventer la roue en moins bien.

## Détection

Mots-clés qui doivent déclencher la consultation de l'index :
- **Lighting** : light, shadow, CanvasModulate, PointLight2D, normal map, posterization, dithering
- **Color/Mood** : palette, color grading, vignette, desaturation, mood, CanvasModulate tint, LUT, accent color
- **Shaders** : dissolve, hit flash, outline, shockwave, chromatic aberration, CRT, palette swap, water distortion
- **Particles** : GPUParticles2D, explosion, dust puff, trail, fire, rain, snow, sparkle, burst, color_ramp
- **Hit Feedback** : hitstop, freeze frame, screenshake, knockback, hit flash, damage number, impact
- **Movement** : coyote time, input buffer, variable jump, air control, corner correction, dash, wall slide
- **Tweens/Juice** : tween, easing, squash, stretch, overshoot, bounce, pop-in, BACK_OUT, ELASTIC
- **Transitions** : screen transition, fade, iris wipe, diamond wipe, scene change, crossfade
- **AI/Enemies** : telegraph, anticipation, wind-up, recovery, weight, momentum, boss design, attack pattern
- **Audio** : SFX, music ducking, pitch variation, spatial audio, bus layout, impact layer, AudioStreamRandomizer
- **Text/Dialogue** : typewriter, visible_characters, text speed, blip, RichTextEffect, dialogue box, portrait, expression
- **Cards** : card, hand, hover, tilt, foil, holographic, CCG, TCG, deckbuilder, fan layout
- **Collection** : pickup, fly-to-UI, counter, toast, rarity, inventory, loot, reward
- **Turn Combat** : turn-based, action beat, damage number, combat camera, status effect, Persona

## Annonce

Quand tu consultes une recette, annonce-le : `[RECIPE] _golem/recipes/xxx.md — pattern : {résumé en 1 ligne}`
