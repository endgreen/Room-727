extends Node
## Devlog gameplay capture. Ziva's extension adds this autoload, in memory only, to every game the
## editor launches while STATE_PATH exists; it records the run (F5, run_scene, playtests) from
## inside the game, so no OS screen-recording permission is involved. Idle when the state says
## recording is off or paused.
##
## Frames are read back asynchronously where the renderer allows it (Forward+/Mobile) and piped
## to Ziva's bundled ffmpeg, which writes 10-second segments. The Compatibility renderer has no
## async readback, so it records at 15 fps to keep the per-frame stall small.

const STATE_PATH := "user://ziva/extensions/godot-gamedev/devlog/state.json"
const SEGMENT_SECONDS := 10

var _fps := 30
var _pid := -1
var _pipe: FileAccess
var _writer: Thread
var _queue: Array[PackedByteArray] = []
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _stopping := false
var _next_ms := 0.0
var _size := Vector2i.ZERO
var _async := false

func _ready() -> void:
	# Headless runs (Ziva's run_tests and execute_script tools, CI) draw no frames to record.
	if OS.has_feature("template") or DisplayServer.get_name() == "headless" or not FileAccess.file_exists(STATE_PATH):
		queue_free()
		return
	var state = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(state) != TYPE_DICTIONARY or not state.get("enabled", false) or state.get("paused", false):
		queue_free()
		return
	var dir: String = state.get("recordings", "")
	var ffmpeg: String = state.get("ffmpeg", "")
	if dir.is_empty() or ffmpeg.is_empty():
		push_error("Ziva Devlog: recording is on but %s names no folder or no encoder; this run is not recorded." % STATE_PATH)
		queue_free()
		return
	_async = RenderingServer.get_rendering_device() != null
	_fps = 30 if _async else 15
	var out := dir.path_join("game/%d" % int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(out)
	# Wait one frame so the window has its final size before the encoder is sized.
	await get_tree().process_frame
	_size = Vector2i(get_viewport().get_texture().get_size())
	if not _start_encoder(ffmpeg, out):
		queue_free()
		return
	_writer = Thread.new()
	_writer.start(_write_loop)
	RenderingServer.frame_post_draw.connect(_on_post_draw)

func _start_encoder(ffmpeg: String, out: String) -> bool:
	var args := PackedStringArray(["-hide_banner", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
		"-s", "%dx%d" % [_size.x, _size.y], "-framerate", str(_fps), "-i", "-", "-an",
		"-vf", "scale='min(1280,iw)':-2", "-c:v", "libopenh264", "-rc_mode", "bitrate", "-b:v", "4M",
		"-pix_fmt", "yuv420p", "-g", str(_fps * 2),
		"-f", "segment", "-segment_time", str(SEGMENT_SECONDS), "-reset_timestamps", "1", "-segment_format", "mp4",
		"-segment_format_options", "movflags=+frag_keyframe+empty_moov+default_base_moof", out.path_join("seg_%04d.mp4")])
	# ffmpeg writes its own diagnostics next to the segments so an encoder failure is never silent.
	# FFREPORT splits on ':' and treats a backslash as an escape, so a Windows path goes in with
	# forward slashes and its drive letter's colon escaped.
	OS.set_environment("FFREPORT", "file=%s:level=24" % out.path_join("ffmpeg.log").replace("\\", "/").replace(":", "\\:"))
	var p := OS.execute_with_pipe(ffmpeg, args)
	# Unset so the game's own child processes do not write reports here.
	OS.unset_environment("FFREPORT")
	if p.is_empty():
		push_error("Ziva Devlog: the video encoder at %s could not start, so this run is not recorded." % ffmpeg)
		return false
	_pipe = p["stdio"]
	_pid = p["pid"]
	var meta := FileAccess.open(out.path_join("meta.json"), FileAccess.WRITE)
	meta.store_string(JSON.stringify({"start_unix": Time.get_unix_time_from_system(), "fps": _fps,
		"size": [_size.x, _size.y], "segment_s": SEGMENT_SECONDS, "async_readback": _async}))
	meta.close()
	return true

func _write_loop() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _queue.is_empty():
			_mutex.unlock()
			if _stopping:
				return
			continue
		var buf: PackedByteArray = _queue.pop_front()
		_mutex.unlock()
		_pipe.store_buffer(buf)

func _enqueue(buf: PackedByteArray, copies: int) -> void:
	if _stopping:
		return
	if buf.size() != _size.x * _size.y * 4:
		# A resized window or an HDR 2D viewport no longer matches the encoder's RGBA8 input.
		push_error("Ziva Devlog: the game's frames changed size or format (%d bytes, expected %d); recording of this run stopped." % [buf.size(), _size.x * _size.y * 4])
		_finish.call_deferred()
		return
	_mutex.lock()
	for i in copies:
		if _queue.size() < 8:
			_queue.push_back(buf)
			_sem.post()
	_mutex.unlock()

func _on_post_draw() -> void:
	var now := Time.get_ticks_msec()
	if _next_ms == 0.0:
		_next_ms = now
	if now < _next_ms:
		return
	# One frame per elapsed tick keeps the recording in real time even if the game stalls.
	var ticks := int((now - _next_ms) / (1000.0 / _fps)) + 1
	_next_ms += ticks * (1000.0 / _fps)
	var tex := get_viewport().get_texture()
	if _async:
		RenderingServer.get_rendering_device().texture_get_data_async(RenderingServer.texture_get_rd_texture(tex.get_rid()), 0,
			_enqueue.bind(ticks))
	else:
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		_enqueue(img.get_data(), ticks)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_finish()

func _exit_tree() -> void:
	_finish()

func _finish() -> void:
	if _pipe == null or _stopping:
		return
	_stopping = true
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	_sem.post()
	_writer.wait_to_finish()
	_pipe.close()
	var deadline := Time.get_ticks_msec() + 3000
	while OS.is_process_running(_pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(20)
