---
paths:
  - "**/*.gd"
  - "godot-plugin/**"
---

# GDScript — Timing, Types & Patterns

## Code Hygiene

### Formatting
- **Trailing comma obligatoire** — toujours laisser une virgule après le dernier élément d'un `Array`, `Dictionary`, `enum`, paramètre de fonction multi-ligne. Réduit les diffs Git (une seule ligne modifiée à l'ajout) et facilite le copier-coller
- **Listes/dicts multi-lignes** — casser sur plusieurs lignes dès 3+ éléments ou 80+ caractères
- **Espaces autour des opérateurs** — `1 + 1`, pas `1+1`. Ne JAMAIS aligner verticalement les `=` (coûteux à maintenir)

```gdscript
# BON
enum Tiles {
    TILE_BRICK,
    TILE_FLOOR,
    TILE_SPIKE,
}

var config: Dictionary = {
    "speed": 200.0,
    "damage": 10,
    "color": Color.RED,
}

# MAUVAIS
enum Tiles { TILE_BRICK, TILE_FLOOR, TILE_SPIKE }
```

### Comments & Documentation
- `# Comment` — note simple (espace après `#`)
- `#disabled_code` — code désactivé (PAS d'espace après `#`, différencie visuellement)
- `## Documentation` — double dièse, génère des **tooltips dans l'éditeur Godot** quand on survole la variable/fonction ailleurs dans le code. Utiliser sur les `@export`, les fonctions publiques, et les constantes

```gdscript
## Maximum speed of the player in pixels/sec
@export var max_speed: float = 300.0

## Spawn a projectile at the given position.
## Returns the projectile instance for chaining.
func spawn_projectile(pos: Vector2) -> Projectile:
    pass
```

### Naming
- **Fichiers & variables** : `snake_case` (`player_controller.gd`, `var health_points`)
- **Classes & Nodes** : `PascalCase` (`class_name LevelManager`)
- **Constantes** : `SCREAMING_SNAKE_CASE` (`const MAX_SPEED = 100.0`)
- **Signaux** : `snake_case` passé composé (`health_changed`, `enemy_died`)
- **Fonctions privées** : préfixe `_` (`func _update_ui()`)

### Logging
- **`push_error("msg")`** — rouge dans la console, **cliquable** (ouvre le script à la ligne). Utiliser pour les erreurs récupérables
- **`push_warning("msg")`** — jaune, cliquable. Utiliser pour les situations anormales non-bloquantes
- **`print_rich("[color=green]OK[/color]")`** — BBCode pour colorer les logs importants. Plus lisible que `print()` dans un flux dense
- **Éviter `print()` nu** — pollue la console, pas cliquable, pas filtrable. Réserver au prototypage rapide

## Timing & Signals

- **Signaux = synchrones** — `emit()` exécute tous les handlers IMMÉDIATEMENT avant la ligne suivante. L'ordre d'émission détermine le comportement si les handlers partagent un état. Pattern : suppress flag + `call_deferred("set", "_flag", false)` pour reset au frame suivant
- **`global_position` avant `add_child()` = ignoré** — stocker dans une var via `setup()`, appliquer dans `_ready()`. `position` (locale) OK si le parent est à (0,0)
- **`set_script()` avant `add_child()` = `@onready` OK** — le script est attaché avant l'entrée dans l'arbre
- **`queue_free()` n'est pas immédiat** — le node existe encore pendant le frame. Toujours `is_instance_valid(node)` et `node.is_queued_for_deletion()` avant usage
- **Guard après CHAQUE `await`** — n'importe quel node peut avoir été freed. `is_instance_valid()` sur self ET objets référencés
- **`is_instance_valid()` dans callbacks signal** — un signal peut arriver après `queue_free()` d'un node optionnel (overlay, FX, vignette). Toujours check avant manipulation
- **`add_child()` pendant `_ready()` parent = erreur** — le parent setup ses enfants .tscn. Fix : `call_deferred("add_child", child)`
- **`set_deferred("data", val)` → `_ready()` lit null** — assigner directement (`node.data = val`) AVANT `call_deferred("add_child", node)`. Seul le `add_child` a besoin du deferred
- **`add_child(Area2D)` pendant physics flush = CRASH** — signal handler pendant physics → `Can't change this state while flushing queries`. Fix : `container.call_deferred("add_child", node)`

## Type Inference `:=`

- **`:=` sur Array/Dictionary/ternaire/Node générique = crash parser** — source Variant, élément d'Array non-typé, propriété via `Node` générique → "Cannot infer the type". Toujours `: Type =`
- **`var speed := 200` = int, pas float** — `speed = 200.5` → erreur silencieuse. Toujours `200.0`
- **`Array[T]` vs `Array`** — `get_nodes_in_group()` retourne `Array` non-typé. Fix : `var x: Array = method()` ou `x.assign(method())`. Note : `get_children()` EST typé, mais `get_nodes_in_group/get_connections/get_groups` ne le sont PAS
- **Accès membre sur Variant = warning cascade** — Fix : cast `as Player` (si `class_name`), ou `has_method()`, ou accepter le Variant

## Tweens & Pause

- **Tween sur node freed = silent fail ou crash** — `create_tween()` lié au node. Fix : `get_tree().create_tween()` (survit au node) ou kill dans `_exit_tree()`
- **Tween pendant pause = 2 conditions** — `process_mode = PROCESS_MODE_ALWAYS` sur le node ET `tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` sur le tween. Un seul ne suffit pas
- **Time scale compensation player** — `var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta`. Ne PAS compenser ennemis/projectiles

## Native Member Shadowing

- **Redéfinition membre natif = Parser Error** — `@export var offset` dans `extends Camera2D` → bloquant. Préfixer (`follow_offset`, `shake_offset`, `camera_zoom`)
- Classes piégeuses : Camera2D (`offset`, `zoom`), Node2D (`position`, `rotation`, `scale`), Control (`size`, `position`), CharacterBody2D (`velocity`), Sprite2D (`texture`, `offset`)

## Resources & References

- **`ResourceLoader.exists()` avant `load()` dynamique** — `load("res://x/%s.tres" % type)` crashe si fichier absent. `preload()` vérifié au compile time, `load()` non
- **StyleBoxFlat = référence partagée** — `get_theme_stylebox("panel")` retourne une ref partagée. `.duplicate()` avant modification
- **`duplicate(true)` pour deep copy** — passer des données à l'UI → `weapons.duplicate(true)`, jamais la référence directe

## Architecture & UI

- **Composants custom = `@export` typé, pas `@onready $`** — `@export var health: HealthComponent` dans le script root. Drag & drop dans l'inspecteur. Résiste aux renames, validé par l'éditeur. `@onready $` uniquement pour les nodes natifs internes à la scène ($Label, $Sprite2D) ou le prototypage rapide via `%`
- **Données UI = copies** — l'UI est read-only, communique via signal
- **Action joueur échouée = signal, pas silence** — `return false` sans feedback = bug UX
- **Popup programmatique > .tscn** — CanvasLayer.new() + set_script() + `_build_ui()` pour UI temporaire
- **CanvasLayer ordering** — 0 (jeu), 1 (HUD), 5 (popup gameplay), 6 (popup secondaire), 10 (pause menu)
- **AudioServer effects = index en `_ready()`** — guard clause `bus_idx == -1`, ne jamais recalculer
- **Modulate = fake desaturation** — `Color(0.7, 0.7, 0.7)` sur parent entities = visuel grisé sans shader
- **Temporary nodes > repositioning** — N instances simultanées → nodes temporaires + tween + `queue_free`

## Performance

- **`queue_redraw()` chaque frame = HIGH** — throttle `Engine.get_process_frames() % 3 == 0` ou Sprite+tween
- **`create_timer()` par node = allocation** — utiliser compteur `_time` dans `_process`
- **`get_node()` dans hot paths** — cacher en var `_ready()`

## GPUParticles2D

- **`color_ramp`, `scale_min/max`** = sur `ParticleProcessMaterial`, PAS sur `GPUParticles2D`
- **Sans `draw_pass` = invisible** — toujours ajouter QuadMesh comme `draw_pass_1`
