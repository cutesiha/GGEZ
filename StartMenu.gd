extends Control

const NORMAL_BLINK_INTERVAL := 0.42
const CONFIRM_BLINK_INTERVAL := 0.045
const CONFIRM_BLINK_COUNT := 10
const START_MUSIC_PATH := "res://audio/start_[cut_35sec].wav"
const SFX_PREVIEW_PATH := "res://audio/perfect_p1.wav"
const SETTINGS_MASTER := 0
const SETTINGS_MUSIC := 1
const SETTINGS_SFX := 2
const SETTINGS_FULLSCREEN := 3
const SETTINGS_COUNT := 4
const VOLUME_STEP := 5
const DEFAULT_VOLUME := 70
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

@onready var arrow_labels: Array[Label] = [
	$Menu/StartRow/Arrow,
	$Menu/TutorialRow/Arrow,
	$Menu/SettingRow/Arrow,
	$Menu/ExitRow/Arrow,
]
@onready var text_labels: Array[Label] = [
	$Menu/StartRow/Text,
	$Menu/TutorialRow/Text,
	$Menu/SettingRow/Text,
	$Menu/ExitRow/Text,
]
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var settings_panel: Panel = $SettingsPanel
@onready var settings_cursor: Label = $SettingsPanel/Cursor
@onready var master_value_text: Label = $SettingsPanel/MasterValue
@onready var music_value_text: Label = $SettingsPanel/MusicValue
@onready var sfx_value_text: Label = $SettingsPanel/SfxValue
@onready var fullscreen_o_box: Panel = $SettingsPanel/FullscreenO
@onready var fullscreen_x_box: Panel = $SettingsPanel/FullscreenX
@onready var fullscreen_o_text: Label = $SettingsPanel/FullscreenO/Text
@onready var fullscreen_x_text: Label = $SettingsPanel/FullscreenX/Text

var selected_index := 0
var blink_timer := 0.0
var blink_white := true
var confirming := false
var settings_open := false
var settings_index := SETTINGS_MASTER
var master_volume := DEFAULT_VOLUME
var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
var fullscreen_enabled := false
var arrow_text := ""
var menu_items: Array = []
var start_music_player: AudioStreamPlayer
var settings_preview_player: AudioStreamPlayer
var fullscreen_normal_style: StyleBoxFlat
var fullscreen_selected_style: StyleBoxFlat


func _ready() -> void:
	arrow_text = PackedByteArray([0xe2, 0x96, 0xb6]).get_string_from_utf8()
	menu_items = [
		{"label": "start", "scene": "res://mainmenu.tscn"},
		{"label": "tutorial", "scene": "res://Tutorial.tscn"},
		{"label": "setting", "action": "settings"},
		{"label": "exit..." + PackedByteArray([0xe2, 0x98, 0xb9]).get_string_from_utf8(), "action": "exit"},
	]
	_build_setting_styles()
	_load_current_settings()
	_setup_settings_preview_player()
	_apply_menu_text()
	_play_start_music()
	_update_settings_ui()
	_update_selection()


func _process(delta: float) -> void:
	if confirming or settings_open:
		return

	blink_timer += delta
	if blink_timer >= NORMAL_BLINK_INTERVAL:
		blink_timer = 0.0
		blink_white = not blink_white
		_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	if confirming or not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if settings_open:
		_handle_settings_input(key_event)
		get_viewport().set_input_as_handled()
		return

	match key_event.keycode:
		KEY_DOWN:
			_select_index(selected_index + 1)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_select_index(selected_index - 1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			confirm_selected()


func _exit_tree() -> void:
	if start_music_player:
		start_music_player.stop()


func _apply_menu_text() -> void:
	for i in range(text_labels.size()):
		text_labels[i].text = menu_items[i]["label"]


func _play_start_music() -> void:
	start_music_player = AudioStreamPlayer.new()
	start_music_player.name = "StartMusic"
	add_child(start_music_player)

	var stream := load(START_MUSIC_PATH)
	if stream is AudioStream:
		start_music_player.stream = stream
	if start_music_player.stream is AudioStreamWAV:
		var wav_stream := start_music_player.stream as AudioStreamWAV
		wav_stream.loop_begin = 0
		wav_stream.loop_end = int(wav_stream.get_length() * wav_stream.mix_rate)
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	start_music_player.bus = &"Music"
	start_music_player.volume_db = 0.0
	start_music_player.stream_paused = false
	await get_tree().process_frame
	start_music_player.play()


func _select_index(next_index: int) -> void:
	selected_index = posmod(next_index, menu_items.size())
	blink_timer = 0.0
	blink_white = true
	_update_selection()


func _update_selection() -> void:
	for i in range(arrow_labels.size()):
		if i == selected_index:
			arrow_labels[i].text = arrow_text
			if blink_white:
				arrow_labels[i].add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			else:
				arrow_labels[i].add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		else:
			arrow_labels[i].text = ""


func _build_setting_styles() -> void:
	fullscreen_normal_style = _make_box_style(Color.BLACK, Color.WHITE, 3)
	fullscreen_selected_style = _make_box_style(Color.WHITE, Color.WHITE, 5)


func _make_box_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style


func _load_current_settings() -> void:
	master_volume = _read_bus_volume(BUS_MASTER)
	music_volume = _read_bus_volume(BUS_MUSIC)
	sfx_volume = _read_bus_volume(BUS_SFX)
	var window_mode := DisplayServer.window_get_mode()
	fullscreen_enabled = window_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _read_bus_volume(bus_name: StringName) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return DEFAULT_VOLUME
	return clampi(roundi(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0), 0, 100)


func _set_bus_volume(bus_name: StringName, value: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var linear_value := float(value) / 100.0
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value) if linear_value > 0.0 else -80.0)


func _setup_settings_preview_player() -> void:
	settings_preview_player = AudioStreamPlayer.new()
	settings_preview_player.name = "SettingsSfxPreview"
	settings_preview_player.bus = BUS_SFX
	var preview_stream := load(SFX_PREVIEW_PATH)
	if preview_stream is AudioStream:
		settings_preview_player.stream = preview_stream
	add_child(settings_preview_player)


func _open_settings() -> void:
	settings_open = true
	settings_index = SETTINGS_MASTER
	dim_overlay.visible = true
	settings_panel.visible = true
	_update_settings_ui()


func _close_settings() -> void:
	settings_open = false
	dim_overlay.visible = false
	settings_panel.visible = false
	confirming = false
	blink_timer = 0.0
	blink_white = true
	_update_selection()


func _handle_settings_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			_close_settings()
		KEY_UP:
			settings_index = posmod(settings_index - 1, SETTINGS_COUNT)
			_update_settings_ui()
		KEY_DOWN:
			settings_index = posmod(settings_index + 1, SETTINGS_COUNT)
			_update_settings_ui()
		KEY_LEFT:
			_change_current_setting(-1)
		KEY_RIGHT:
			_change_current_setting(1)
		KEY_O:
			if settings_index == SETTINGS_FULLSCREEN:
				_set_fullscreen(true)
		KEY_X:
			if settings_index == SETTINGS_FULLSCREEN:
				_set_fullscreen(false)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if settings_index == SETTINGS_FULLSCREEN:
				_set_fullscreen(not fullscreen_enabled)


func _change_current_setting(direction: int) -> void:
	match settings_index:
		SETTINGS_MASTER:
			master_volume = clampi(master_volume + direction * VOLUME_STEP, 0, 100)
			_set_bus_volume(BUS_MASTER, master_volume)
		SETTINGS_MUSIC:
			music_volume = clampi(music_volume + direction * VOLUME_STEP, 0, 100)
			_set_bus_volume(BUS_MUSIC, music_volume)
		SETTINGS_SFX:
			sfx_volume = clampi(sfx_volume + direction * VOLUME_STEP, 0, 100)
			_set_bus_volume(BUS_SFX, sfx_volume)
			if settings_preview_player.stream:
				settings_preview_player.stop()
				settings_preview_player.play()
		SETTINGS_FULLSCREEN:
			_set_fullscreen(direction < 0)
	_update_settings_ui()


func _set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_update_settings_ui()


func _update_settings_ui() -> void:
	master_value_text.text = _volume_bar_text(master_volume)
	music_value_text.text = _volume_bar_text(music_volume)
	sfx_value_text.text = _volume_bar_text(sfx_volume)
	settings_cursor.position.y = [105.0, 171.0, 237.0, 303.0][settings_index]
	fullscreen_o_box.add_theme_stylebox_override("panel", fullscreen_selected_style if fullscreen_enabled else fullscreen_normal_style)
	fullscreen_x_box.add_theme_stylebox_override("panel", fullscreen_selected_style if not fullscreen_enabled else fullscreen_normal_style)
	fullscreen_o_text.add_theme_color_override("font_color", Color.BLACK if fullscreen_enabled else Color.WHITE)
	fullscreen_x_text.add_theme_color_override("font_color", Color.BLACK if not fullscreen_enabled else Color.WHITE)


func _volume_bar_text(value: int) -> String:
	const SEGMENTS := 28
	var marker_position := clampi(roundi(float(value) / 100.0 * SEGMENTS), 0, SEGMENTS)
	return "%s|%s  %d/100" % ["-".repeat(marker_position), "-".repeat(SEGMENTS - marker_position), value]


func confirm_selected() -> void:
	confirming = true
	for i in range(CONFIRM_BLINK_COUNT):
		var white := i % 2 == 0
		arrow_labels[selected_index].add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0, 1.0) if white else Color(0.0, 0.0, 0.0, 1.0)
		)
		await get_tree().create_timer(CONFIRM_BLINK_INTERVAL).timeout

	await _activate_selected()


func _activate_selected() -> void:
	var selected_item: Dictionary = menu_items[selected_index]
	var action := String(selected_item.get("action", ""))
	if action == "settings":
		_open_settings()
		confirming = false
		return
	if action == "exit":
		get_tree().quit()
		return
	var target_scene: String = selected_item["scene"]
	var error := get_tree().change_scene_to_file(target_scene)
	if error != OK:
		push_error("Could not change scene to %s. Error: %s" % [target_scene, error])
		confirming = false
		blink_timer = 0.0
		blink_white = true
		_update_selection()
