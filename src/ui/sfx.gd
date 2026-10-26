class_name Sfx
extends RefCounted
## Static access to the AudioDirector autoload, safe where autoload names are
## not known yet (tool scripts, headless tests): does nothing without it.


static func play(event: String) -> void:
	var director := _director()
	if director != null:
		director.play(event)


static func music(track: String) -> void:
	var director := _director()
	if director != null:
		director.music(track)


static func music_for_phase() -> void:
	var director := _director()
	if director != null:
		director.music_for_phase()


static func _director() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioDirector") if tree != null else null
