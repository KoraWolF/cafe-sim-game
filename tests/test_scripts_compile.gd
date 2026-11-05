extends TestCase
## Loads every game script, so one that doesn't compile fails the tests. The other
## tests never touch most of the UI, and a broken UI script stops the game starting.


func test_every_game_script_compiles() -> void:
	var scripts := _scripts("res://src")
	assert_true(scripts.size() > 50, "found the game's scripts")
	for path: String in scripts:
		var script: GDScript = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		assert_true(script != null and script.can_instantiate(), path + " compiles")


func _scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(child)))
	return found
