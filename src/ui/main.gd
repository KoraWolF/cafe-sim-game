extends Node
## Root of the game: shows the main menu or a running game, one at a time.

var _current: Node = null


func _ready() -> void:
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
