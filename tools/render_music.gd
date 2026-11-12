# Saves a song from scripts/music.gd as a WAV:  godot --headless --path . -s tools/render_music.gd -- game /tmp/music.wav
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "game"
	var out: String = args[1] if args.size() > 1 else "user://music.wav"
	var wav: AudioStreamWAV = load("res://scripts/music.gd").render(id)
	wav.save_to_wav(out)
	print("saved ", out)
	quit(0)
