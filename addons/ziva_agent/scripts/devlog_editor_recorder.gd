@tool
extends Node
## Devlog editor recorder. Ziva's editor plugin adds this node at startup; it stays idle until
## the sidecar turns recording on in STATE_PATH, which the game-dev extension's sidecar owns. While
## on, it keeps a still of the editor window whenever the editor redraws into something new (at
## most once a second).
## Game runs record themselves (devlog_capture.gd), reading the same file.

const STATE_PATH := "user://ziva/extensions/godot-gamedev/devlog/state.json"
const MAX_STILLS_PER_SECOND := 1.0
const MAX_STILL_WIDTH := 1920
# Luma levels on a 64x36 thumbnail. A caret blink moves it by 3 at most; real edits by 8 or more.
const STILL_MIN_CHANGE := 8
const STALL_FRAMES := 600

var _state_mtime := -1
var _recording := false
var _dir := ""
var _main_screen := ""
var _next_still_ms := 0
var _in_flight := 0
var _task_id := -1
var _pending_frames := 0
var _poll_accum := 0.0
var _last_thumb: Image

func attach(plugin: EditorPlugin) -> void:
	plugin.main_screen_changed.connect(func(screen: String) -> void: _main_screen = screen)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_poll_state()

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	_recording = false

func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum >= 1.0:
		_poll_accum = 0.0
		_poll_state()

func _poll_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		_recording = false
		return
	var mtime := FileAccess.get_modified_time(STATE_PATH)
	if mtime == _state_mtime:
		return
	_state_mtime = mtime
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ziva Devlog: %s is not valid JSON; recording stays off." % STATE_PATH)
		_recording = false
		return
	var want: bool = parsed.get("enabled", false) and not parsed.get("paused", false)
	var dir: String = parsed.get("recordings", "")
	if want and dir.is_empty():
		push_error("Ziva Devlog: recording is on but %s names no folder; recording stays off." % STATE_PATH)
		want = false
	if want and (not _recording or dir != _dir):
		_start(dir)
	elif not want:
		_recording = false

func _start(dir: String) -> void:
	_recording = false
	var err := DirAccess.make_dir_recursive_absolute(dir.path_join("editor"))
	if err != OK:
		push_error("Ziva Devlog: cannot create %s (error %d); recording stays off." % [dir, err])
		return
	_dir = dir
	_last_thumb = null
	_recording = true

func _on_post_draw() -> void:
	# The Game tab shows the running game from another process as a grey box in these stills.
	if not _recording or _main_screen == "Game":
		return
	if _in_flight > 0:
		# A still that never comes back would stop editor stills with no sign, so it is reported.
		_pending_frames += 1
		if _pending_frames == STALL_FRAMES:
			push_error("Ziva Devlog: an editor still has not come back after %d drawn frames; no new editor stills until it does." % STALL_FRAMES)
		return
	var now := Time.get_ticks_msec()
	if now < _next_still_ms:
		return
	_pending_frames = 0
	_next_still_ms = now + int(1000.0 / MAX_STILLS_PER_SECOND)
	var tex := EditorInterface.get_base_control().get_viewport().get_texture()
	var size := Vector2i(tex.get_width(), tex.get_height())
	var stamp := Time.get_unix_time_from_system()
	var dir := _dir
	var rd := RenderingServer.get_rendering_device()
	_in_flight += 1
	if rd:
		rd.texture_get_data_async(RenderingServer.texture_get_rd_texture(tex.get_rid()), 0,
			_on_still_read.bind(size, stamp, dir))
	else:
		# The Compatibility renderer has no async readback; one still a second keeps the stall rare.
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		_task_id = WorkerThreadPool.add_task(_encode.bind(img.get_data(), size, stamp, dir))

func _on_still_read(data: PackedByteArray, size: Vector2i, stamp: float, dir: String) -> void:
	_task_id = WorkerThreadPool.add_task(_encode.bind(data, size, stamp, dir))

func _encode(data: PackedByteArray, size: Vector2i, stamp: float, dir: String) -> void:
	# A runtime error ends only _save_still, so the capture slot is always freed.
	_save_still(data, size, stamp, dir)
	_done_encoding.call_deferred()

func _save_still(data: PackedByteArray, size: Vector2i, stamp: float, dir: String) -> void:
	if data.size() != size.x * size.y * 4:
		push_error("Ziva Devlog: an editor still came back as %d bytes, not the %d of a %dx%d RGBA8 frame; it was skipped." % [data.size(), size.x * size.y * 4, size.x, size.y])
		return
	var img := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
	img.convert(Image.FORMAT_RGB8)
	# An idle editor keeps redrawing (caret blink, dock repaints); stills that show nothing new
	# would fill the disk at about 600 MB an hour, so they are dropped.
	var thumb := img.duplicate() as Image
	thumb.resize(64, 36, Image.INTERPOLATE_LANCZOS)
	if _last_thumb and thumb.compute_image_metrics(_last_thumb, true)["max"] < STILL_MIN_CHANGE:
		return
	_last_thumb = thumb
	if img.get_width() > MAX_STILL_WIDTH:
		img.resize(MAX_STILL_WIDTH, int(float(MAX_STILL_WIDTH) * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var err := img.save_jpg(dir.path_join("editor/%.3f.jpg" % stamp), 0.8)
	if err != OK:
		push_error("Ziva Devlog: could not save an editor still (error %d)." % err)

func _done_encoding() -> void:
	# The pool keeps a task's callable, and with it the whole frame, until the task is waited on.
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_in_flight -= 1
