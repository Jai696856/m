extends SceneTree
func _initialize() -> void:
	var P = load("res://scripts/chibi_parts.gd")
	var out := OS.get_cmdline_user_args()[0]
	var specs := [
		{"eye": Color("d81b60"), "hair": Color("22203a"), "eyes": "round", "mouth": "smile"},
		{"eye": Color("2f8cff"), "hair": Color("f2c14e"), "eyes": "sharp", "mouth": "grin", "brow": 12.0},
		{"eye": Color("8e4bdb"), "hair": Color("1d1830"), "eyes": "gentle", "mouth": "smile", "brow": -6.0},
		{"eye": Color("ff7043"), "hair": Color("6b3b1f"), "eyes": "round", "mouth": "open"},
		{"eye": Color("8b5a2b"), "hair": Color("15121c"), "eyes": "sharp", "mouth": "flat", "brow": 14.0, "male": true, "blush": false},
		{"eye": Color("ff3d8b"), "hair": Color("9b6bff"), "eyes": "wink", "mouth": "cat"},
		{"eye": Color("3a8a6b"), "hair": Color("3a8a6b"), "eyes": "closed", "mouth": "smile"},
		{"eye": Color("ffb02e"), "hair": Color("d9452b"), "eyes": "round", "mouth": "grin", "male": true, "brow": 8.0},
	]
	for i in range(specs.size()):
		var t: Texture2D = P.face_texture(specs[i])
		t.get_image().save_png("%s/face_%d.png" % [out, i])
	print("faces done")
	quit(0)
