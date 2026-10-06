extends Node
func _ready() -> void:
	GameState.collected.clear()
	GameState.placed.clear()
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().create_timer(1.0).timeout
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	for i in 5:
		GameState.collect_piece(i)
	board.refresh_from_game_state()
	page._enter_puzzle_mode()
	await get_tree().create_timer(0.2).timeout
	print("T1 visible=", board.auto_button.visible, " text=", board.auto_button.text)
	SettingsData.set_value("启用拼图排序按钮", false)
	print("T1.5 stored=", SettingsData.get_value("启用拼图排序按钮", "MISS"))
	page._exit_puzzle_mode()
	await get_tree().create_timer(0.2).timeout
	page._enter_puzzle_mode()
	await get_tree().create_timer(0.2).timeout
	print("T2 visible=", board.auto_button.visible, " stored=", SettingsData.get_value("启用拼图排序按钮", "MISS"))
	get_tree().quit()
