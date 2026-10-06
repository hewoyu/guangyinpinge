extends Node
func _ready() -> void:
	var now := Time.get_unix_time_from_system()
	print("system date: ", Time.get_date_string_from_system())
	print("unix date now: ", Time.get_date_string_from_unix_time(now))
	print("unix date -86400: ", Time.get_date_string_from_unix_time(now - 86400.0))
	print("tz offset: ", Time.get_time_zone_from_system())
	get_tree().quit()
