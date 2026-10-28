---
paths:
  - "**/*.gd"
  - "godot-plugin/**"
---

# MCP Tools & TCP — Pitfalls

## Plugin / TCP

- **Godot cache les scripts @tool** — apres modification d'un .gd, il faut recharger le projet (Project > Reload) pas juste desactiver/reactiver le plugin
- **`class_name` en double** — ne jamais copier le dossier `godot-plugin/` entier dans addons, sinon Godot voit le meme class_name deux fois
- **`put_data` TCP sur gros payloads** — les screenshots base64 font ~100KB+, envoi chunke en 64KB
- **`await` dans `_process`** — interdit en GDScript @tool, tout doit etre sync ou deferred
- **`user://` partage** — le file-based protocol marche parce que editeur et jeu partagent le meme `user://` en local. Ne marchera pas en remote debug
- **Multi-client TCP** — chaque session Claude Code = un process golem-mcp = un client TCP. MAX_CLIENTS=5, au-dela rejete. Graceful disconnect (`{"tool": "disconnect"}`) libere le slot. Symptome si trop de sessions : console Godot spammee "Client connected/disconnected" en boucle
- **Hook PreToolUse probe TCP = connection storm** — `check_connection.py` fait un `socket.connect_ex()` a chaque appel MCP tool. GolemServer voit chaque probe comme un client connect/disconnect. En rafale (10+ appels rapides), declenche la storm detection. Fix cote hook : cache TTL 10s (ne re-probe que si cache expire). Fix cote serveur : `RECONNECT_COOLDOWN` 500ms rejette les nouvelles connexions si le peer actuel est vivant et recent. **Regle : tout hook PreToolUse qui fait du reseau doit avoir un cache TTL**

## Godot via MCP

- **GPUParticles2D sans `draw_pass` = invisible** — les particules sont calculees mais jamais rendues. Toujours ajouter un QuadMesh comme `draw_pass_1`
- **Scripts inline dans .tscn = indentation cassee** — GDScript.new() via execute_script serialise avec des tabs foires. Toujours utiliser des fichiers .gd externes
- **Engine.time_scale trop bas bloque GolemCapture** — time_scale < 0.1 empeche les screenshots (timeout). Minimum safe : 0.15
- **project_settings set ne persiste pas toujours** — verifier avec `project_settings action=get` apres. NE PAS editer `project.godot` manuellement
- **PRESET_CENTER ne marche pas pour VBoxContainer** — utiliser PRESET_FULL_RECT + alignment = ALIGNMENT_CENTER
- **execute_script + save_scene ne serialise pas les sub_resources runtime** — ecrire le .tscn manuellement ou utiliser godot_add_node + godot_update_property
- **Shader params dans .tscn overrident les defaults du .gdshader** — modifier le .gdshader ne suffit pas si la scene a un shader_parameter explicite. Verifier les deux
- **UIDs inventes dans les .tscn = fragile** — Godot les accepte mais les regenere. Laisser Godot gerer les UIDs ou copier les existants

## Tools MCP — Usage

- **`add_nodes` ne load() pas les Resources** — passer `"texture": "res://img.png"` dans les properties resulte en null. Toujours assigner les Resources (Texture, SpriteFrames, Material, Theme) via `execute_script` + `load()` apres la creation du node
- **~~`add_nodes` casse les Vector2/Color~~** — **FIXE v0.9.1** : `_create_node_recursive` utilise maintenant `_convert_value()` (via inspect_handler) pour convertir les types complexes (Vector2, Color, Rect2, etc.)
- **Root node = `"."`, pas son nom** — `update_property(path="Main", ...)` -> Node not found. Le root de la scene editee est toujours `"."`, les enfants directs sont `"Player"`, les petits-enfants `"Player/Sprite"`
- **`anchors_preset` ne reset pas les offsets** — `set_anchors_preset(PRESET_FULL_RECT)` change les anchors mais pas les offsets. Toujours ajouter `offset_left/top/right/bottom = 0` apres, ou utiliser `set_anchors_and_offsets_preset()`
- **Autoloads inaccessibles dans `execute_script`** — le contexte est l'editeur, pas le jeu. `GameState.current_state` -> erreur. Tester les autoloads au runtime via `play_scene` + `get_logs`
- **`execute_script` — erreur code 36 sur scripts complexes** — arrays + boucles + concatenation = echec silencieux. Garder les scripts simples (une operation). Logique complexe -> `.gd` externe
- **`execute_script` message d'erreur enrichi** — compilation error affiche maintenant les causes probables (syntax error, Node-only APIs, expressions complexes) au lieu du code brut
- **~~`execute_script` ne detecte pas `await`~~** — **FIXE v0.9.1** : le code est scanne pour `await` avant compilation, avec message d'erreur explicite recommandant `godot_write_script`
- **~~`get_input_map` ne retourne que les actions editeur~~** — **FIXE** : `_parse_project_input_actions()` parse `project.godot [input]` pour ne retourner que les actions projet. Fallback sur filtre `!ui_*` si parse echoue. **Attention** : peut encore retourner "No custom input actions" meme quand des actions existent dans project.godot — verifier manuellement avec `Read project.godot` section `[input]`, ou utiliser `godot_execute_script` avec `InputMap.get_actions()` comme fallback
- **Disconnected =/= echec** — certains appels retournent Disconnected alors que l'operation a reussi. Toujours verifier avec `get_scene_tree()` avant de retry
- **~~SpriteFrames = execute_script obligatoire~~** — **FIXE** : utiliser `godot_create_sprite_frames(animations=[...], node_path="...")` directement
- **~~`unique_name_in_owner` non supporte par add_node~~** — **FIXE** : param `unique_name=true` dans `godot_add_node` et dans les node specs de `godot_add_nodes`
- **Background scaling = calcul manuel** — toujours verifier les dimensions (`Image.load_from_file().get_size()`) puis calculer scale et offset
- **Viewport origin = top-left, pas le centre** — un Node2D a (0,0) dans un Viewport/SubViewport est au coin haut-gauche. Camera2D a (0,0) montre le coin, pas le milieu -> screenshot = vide, boucle de debug inutile. Fix : positionner la camera a `Vector2(viewport.size) / 2.0`. **Regle generale** : ne jamais positionner manuellement des nodes sur le canvas — utiliser des containers (Control) ou calculer relativement a la taille du viewport (Node2D). Apres ajout de nodes, TOUJOURS verifier avec `godot_get_editor_screenshot`
- **GDScript `:=` type inference** — `var speed := 200` infere int, pas float. `speed = 200.5` -> erreur de type silencieuse. Toujours utiliser `200.0` pour les floats. Autre piege : si la variable est typee comme un parent class (`var grid: Node2D`), GDScript ne voit pas les methodes custom du script -> `:=` echoue avec "Cannot infer type". Fix : typer explicitement le retour (`var col: int = grid.get_column()`) ou utiliser `class_name` sur le script
- **GolemCapture.game_log() avant verification autoload** — si le script appelle un autoload non encore charge, crash silencieux. Verifier `Engine.has_singleton()` ou `get_node_or_null("/root/AutoloadName")`
- **Editor screenshot apres disconnect TCP** — le handler peut etre appele alors que le peer est null. Erreur silencieuse, pas de screenshot retourne. Verifier la connexion avant
- **`get_logs` est incremental** — chaque appel retourne seulement les NOUVELLES lignes depuis le dernier appel (seek-based). `clear_logs` et `play_scene` remettent les curseurs a zero. Ne pas s'attendre a relire les anciens logs apres un premier `get_logs`
- **`add_child(Area2D)` pendant physics flush = CRASH** — signal handler declenche pendant physics (ex: `enemy_died` -> spawn loot Area2D) -> `Can't change this state while flushing queries`. Fix : `container.call_deferred("add_child", node)`. Le `setup()` peut etre appele AVANT le deferred tant qu'il ne touche que des variables internes
- **Input simulation via `godot_simulate_input`** — envoie des sequences d'actions Input Map au jeu (file-based, meme pattern que screenshots). Supporte `duration` (hold), `wait`, `pressed` toggle, et `loop`. Actions doivent exister dans l'Input Map du projet. Ne simule PAS les evenements souris/clavier bruts — uniquement les actions nommees
- **`godot_edit_script` et CRLF (Windows)** — sur Windows, Godot cree les .gd avec CRLF (`\r\n`). `godot_edit_script` ne matche pas les blocs multi-lignes contenant `\r\n`. **Regle** : toujours matcher sur **une seule ligne unique** ou utiliser `godot_write_script` pour les gros changements. Si un match multi-ligne echoue, reduire au match de la derniere ligne du bloc
- **`godot_edit_script` et indentation tabs** — GDScript utilise des tabs. Le match doit inclure les tabs exactement. Apres editions successives, des mix tabs/espaces peuvent apparaitre. **Regle** : preferer des lignes courtes et uniques comme ancre de match

## Runtime & Play

- **MCP deconnecte souvent pendant play** — les screenshots et get_scene_tree echouent frequemment juste apres `play_scene`. Pattern : appeler `get_errors` d'abord (fiable), puis retry screenshot 1-2 fois max. Ne pas boucler — apres 3 echecs, demander a l'utilisateur
- **Race condition stop -> play** — appeler `play_scene` immediatement apres `stop_scene` retourne "A scene is already running". Faire une operation intermediaire (get_errors, Read, etc.) entre les deux pour laisser Godot tear down
- **Game screenshot = best-effort, jamais retry** — le JPEG encode + base64 fait plusieurs MB, l'envoi TCP peut timeout et declencher un cycle connect/disconnect. Un seul appel. Si fail -> `godot_get_logs` ou validation manuelle. Retry aggrave le storm
- **`get_game_screenshot` requiert GolemCapture** — si l'autoload n'est pas actif dans le projet, le screenshot ne reviendra jamais. Verifier dans Project Settings > Autoload

## Scene Editing via MCP

- **JAMAIS editer .tscn / project.godot sur disque** — Godot ecrase au prochain save. Scripts .gd = OK (auto-reload)
- **Sequence** : stop_scene -> API calls -> save_scene -> get_scene_tree (verif) -> play_scene
- **project_settings key format** — chemin complet `display/window/size/viewport_width` (pas le format fichier)
- **ext_resource orphelins** — quand un node est supprime manuellement du fichier, sa ligne `[ext_resource]` reste. Raison de plus de ne pas editer les .tscn manuellement — `godot_delete_node` + `save_scene` nettoie automatiquement
- **Instanciation scene editeur = aplatie sans `scene_file_path`** — `instantiate()` seul cree des nodes inline dans le .tscn parent. Pour garder la reference vers la PackedScene : `instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)` + `add_child()` + `.owner = scene_root` + `.scene_file_path = "res://path.tscn"`. Sans le step 4, la scene est serialisee a plat
- **Instance overrides dans parent = ignorees** — changer une propriete (texture, color) sur un node instancie dans arena.tscn ne prend pas : le source scene (player.tscn) prend priorite, surtout si un script set la propriete dans `_ready()`. Fix : toujours modifier la **source scene**, pas l'instance. Via MCP : `godot_open_scene("res://source.tscn")` -> `godot_update_property` -> `godot_save_scene`, puis revenir a la scene parente
- **FBX/GLB imported scene : overrides ne persistent PAS via save_scene** — `godot_update_property` sur un node herite d'un FBX/GLB importe retourne OK, `godot_save_scene` retourne OK, `godot_inspect_node` confirme la nouvelle valeur — mais au runtime c'est l'ancienne valeur. Godot refuse d'ecrire les overrides de proprietes sur des nodes provenant d'une scene importee dans le .tscn. `inspect_node` donne un **faux positif** (il lit la memoire editeur, pas le disque). **Diagnostic** : `grep property_name file.tscn` — si l'override n'apparait pas dans le fichier, il ne sera pas au runtime. **Fix** : setter la propriete dans `_ready()` du script GDScript attache au node. Ex: `skeleton = NodePath("..")`, `root_node = NodePath("..")`. Ce piege est distinct des "instance overrides parent" (scenes Godot) — ici c'est specifique aux scenes importees (FBX/GLB)
- **Autoload name = classe native Godot = masque** — `Logger`, `Input`, `Engine`, `Time`, `OS`, `IP`, `JSON`, `Crypto`, `ClassDB`, `EditorInterface` etc. existent comme classes internes. Un autoload du meme nom est masque par la classe native (parser priorite). Fix : prefixer (`GameLogger`, `AppState`) ou nom court unique (`Log`, `Bus`)

## Server Modification

- **Ecrire `golem_server.gd` = kill la connexion MCP** — Godot auto-reload les scripts @tool. Ecrire sur le serveur TCP reconstruit l'objet, le bridge ne se reconnecte pas proprement. Fix : le user doit recharger le plugin (Project > Plugins > toggle off/on). Prevenir avant d'ecrire
