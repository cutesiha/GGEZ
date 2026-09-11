extends Node

const SETTINGS_PATH := "user://bar_brawl_settings.cfg"

var audio_offset_seconds := 0.0

# Run-only selection, set by the battle's pre-game chooser.  It deliberately is
# not persisted: every new run starts by asking for the play style again.
var coop_enabled := false
var human_side := 0 # 0 = P1, 1 = P2; only used in single-player.

const LANE_ACTIONS := [
	"p1_left", "p1_down", "p1_up", "p1_right",
	"p2_left", "p2_down", "p2_up", "p2_right",
]
const DEFAULT_LANE_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		audio_offset_seconds = float(config.get_value("sync", "audio_offset_seconds", 0.0))
	_apply_saved_lane_keys(config)


func save_audio_offset(value: float) -> void:
	audio_offset_seconds = clamp(value, -0.25, 0.25)
	var config := ConfigFile.new()
	config.set_value("sync", "audio_offset_seconds", audio_offset_seconds)
	config.save(SETTINGS_PATH)


func set_play_mode(use_multiplayer: bool, selected_human_side: int = 0) -> void:
	coop_enabled = use_multiplayer
	human_side = clampi(selected_human_side, 0, 1)


func ensure_lane_actions() -> void:
	for index in range(LANE_ACTIONS.size()):
		var action: String = LANE_ACTIONS[index]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			_set_lane_key(index, DEFAULT_LANE_KEYS[index])


func get_lane_key(index: int) -> int:
	ensure_lane_actions()
	var events := InputMap.action_get_events(LANE_ACTIONS[index])
	if events.is_empty() or not events[0] is InputEventKey:
		return DEFAULT_LANE_KEYS[index]
	return (events[0] as InputEventKey).physical_keycode


func set_lane_key(index: int, keycode: int) -> void:
	if index < 0 or index >= LANE_ACTIONS.size() or keycode == KEY_NONE:
		return
	ensure_lane_actions()
	_set_lane_key(index, keycode)
	_save_lane_keys()


func lane_key_text(index: int) -> String:
	return OS.get_keycode_string(get_lane_key(index))


func _set_lane_key(index: int, keycode: int) -> void:
	var action: String = LANE_ACTIONS[index]
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _apply_saved_lane_keys(config: ConfigFile) -> void:
	for index in range(LANE_ACTIONS.size()):
		var saved_key: int = int(config.get_value("keys", LANE_ACTIONS[index], DEFAULT_LANE_KEYS[index]))
		_set_lane_key(index, saved_key)


func _save_lane_keys() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for index in range(LANE_ACTIONS.size()):
		config.set_value("keys", LANE_ACTIONS[index], int(get_lane_key(index)))
	config.save(SETTINGS_PATH)
