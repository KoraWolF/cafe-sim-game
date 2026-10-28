extends Node
## Root of the game: shows the main menu or a running game, one at a time.

var _current: Node = null


func _ready() -> void:
	# A window as big as the screen would sit under the taskbar: maximize it instead
	# (a maximized window fills the screen's usable area).
	var usable := DisplayServer.screen_get_usable_rect()
	var size := DisplayServer.window_get_size()
	if usable.size.x > 0 and (size.x > usable.size.x or size.y > usable.size.y):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	show_menu()


func show_menu() -> void:
	var menu := MainMenu.new()
	menu.start_game.connect(show_game)
	_swap(menu)


func show_game() -> void:
	var game := GameScreen.new()
	game.quit_to_menu.connect(show_menu)
	_swap(game)


func _swap(next: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = next
	add_child(next)
