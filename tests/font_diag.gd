extends Node
func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var l := Label.new()
	add_child(l)
	l.text = "测"
	await get_tree().process_frame
	print("LABEL_FONT=", l.get_theme_font("font").resource_name if l.get_theme_font("font") != null else "null")
	print("LABEL_FONT_PATH=", l.get_theme_font("font").resource_path if l.get_theme_font("font") != null else "")
	var t := get_tree().root.theme
	print("ROOT_THEME=", t.resource_path if t != null else "null")
	print("FALLBACK=", ThemeDB.fallback_font.resource_name if ThemeDB.fallback_font != null else "null")
	get_tree().quit()
