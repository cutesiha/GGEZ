extends Node

const SETTINGS_PATH := "user://bar_brawl_settings.cfg"

var audio_offset_seconds := 0.0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		audio_offset_seconds = float(config.get_value("sync", "audio_offset_seconds", 0.0))


func save_audio_offset(value: float) -> void:
	audio_offset_seconds = clamp(value, -0.25, 0.25)
	var config := ConfigFile.new()
	config.set_value("sync", "audio_offset_seconds", audio_offset_seconds)
	config.save(SETTINGS_PATH)
