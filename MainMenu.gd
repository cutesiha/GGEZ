extends Node2D

const BLINK_INTERVAL := 0.42
const CONFIRM_BLINK_INTERVAL := 0.045
const CONFIRM_BLINK_COUNT := 10
const MENU_MUSIC_PATH := "res://audio/menu.wav"
const SFX_PREVIEW_PATH := "res://audio/perfect_p1.wav"
const SELECT_HOME := 0
const SELECT_SETTINGS := 1
const SELECT_ACHIEVEMENTS := 2
const SELECT_SYNC := 3
const SELECT_RETURN := 4
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
const ACHIEVEMENT_VISIBLE_COUNT := 5
const ACHIEVEMENTS := [
	"첫 싸움에 입장하기",
	"PERFECT 판정 10회 달성",
	"콤보 25회 이어가기",
	"Stage 1 클리어",
	"하이라이트 공격 성공",
	"체력 50% 이상으로 승리",
	"싱크 설정 저장하기",
	"두 플레이어 모두 생존",
	"보스 스테이지 발견",
	"BAR BRAWL 마스터",
]
const SYNC_STATE_IDLE := 0
const SYNC_STATE_COUNTDOWN := 1
const SYNC_STATE_RUNNING := 2
const SYNC_NOTE_COUNT := 12
const SYNC_HIT_WINDOW := 0.25
const SYNC_TARGET_Y := 105.0
const SYNC_START_Y := -80.0
const SYNC_END_Y := 210.0
const SYNC_NOTE_SPEED := 440.0
const SYNC_NOTE_OUTLINE_RADIUS := 12
const SYNC_CHART_PATH := "res://charts/chapter1_stage1.json"
const SYNC_MUSIC_PATH := "res://audio/stage1.wav"
const SYNC_NOTE_TEXTURE := preload("res://images/up.png")
const SYNC_NOTE_COLOR := Color("c65b86")
const STAGE_HOME := 0
const STAGE_1 := 1
const STAGE_2 := 2
const STAGE_BOSS := 3
const STAGE_SCROLL_DURATION := 0.38
const STAGE_MAP_X := [-231.0, -731.5, -1224.5, -1705.0]
const PLAYER_MAP_X := [10.0, 510.5, 1003.5, 1484.0]
const STAGE_ARROW_REST_X := 612.0
const STAGE_ARROW_NUDGE := 28.0
const PLAYER_MOVE_DURATION := 0.30


class StageFlashOverlay:
	extends Node2D

	var flash_on := false
	var center := Vector2(627.5, 355.0)

	func set_flash(enabled: bool) -> void:
		flash_on = enabled
		queue_redraw()

	func _draw() -> void:
		if not flash_on:
			return
		draw_circle(center, 82.0, Color(1.0, 1.0, 1.0, 0.12))
		draw_arc(center, 83.0, 0.0, TAU, 64, Color.WHITE, 5.0, true)
		draw_arc(center, 92.0, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.55), 3.0, true)

@onready var selection_arrow: Label = $CanvasGroup/SelectionArrow
@onready var stage_map: Node2D = $CanvasGroup/StageMap
@onready var stage_strip: TextureRect = $CanvasGroup/StageMap/Stages
@onready var players_layer: TextureRect = $CanvasGroup/StageMap/Players
@onready var settings_box: Control = $CanvasGroup/SettingsBox
@onready var achievements_box: Control = $CanvasGroup/AchievementsBox
@onready var sync_box: Control = $CanvasGroup/SyncBox
@onready var return_box: Control = $CanvasGroup/ReturnBox
@onready var settings_text: Label = $CanvasGroup/SettingsBox/Text
@onready var achievements_text: Label = $CanvasGroup/AchievementsBox/Text
@onready var sync_text: Label = $CanvasGroup/SyncBox/Text
@onready var return_text: Label = $CanvasGroup/ReturnBox/Text
@onready var settings_backdrop: ColorRect = $CanvasGroup/SettingsBackdrop
@onready var settings_panel: Panel = $CanvasGroup/SettingsPanel
@onready var settings_cursor: Label = $CanvasGroup/SettingsPanel/Cursor
@onready var master_value_text: Label = $CanvasGroup/SettingsPanel/MasterValue
@onready var music_value_text: Label = $CanvasGroup/SettingsPanel/MusicValue
@onready var sfx_value_text: Label = $CanvasGroup/SettingsPanel/SfxValue
@onready var fullscreen_o_box: Panel = $CanvasGroup/SettingsPanel/FullscreenO
@onready var fullscreen_x_box: Panel = $CanvasGroup/SettingsPanel/FullscreenX
@onready var fullscreen_o_text: Label = $CanvasGroup/SettingsPanel/FullscreenO/Text
@onready var fullscreen_x_text: Label = $CanvasGroup/SettingsPanel/FullscreenX/Text
@onready var achievements_panel: Panel = $CanvasGroup/AchievementsPanel
@onready var sync_panel: Panel = $CanvasGroup/SyncPanel
@onready var sync_note_field: Control = $CanvasGroup/SyncPanel/NoteField
@onready var sync_target_outline: TextureRect = $CanvasGroup/SyncPanel/NoteField/TargetOutline
@onready var sync_target_note: TextureRect = $CanvasGroup/SyncPanel/NoteField/TargetNote
@onready var sync_countdown_text: Label = $CanvasGroup/SyncPanel/Countdown
@onready var sync_button: Panel = $CanvasGroup/SyncPanel/SyncButton
@onready var sync_button_text: Label = $CanvasGroup/SyncPanel/SyncButton/Text
@onready var sync_current_text: Label = $CanvasGroup/SyncPanel/CurrentSync

var selected_index := SELECT_HOME
var selected_stage := STAGE_HOME
var current_stage := STAGE_HOME
var settings_open := false
var achievements_open := false
var sync_open := false
var settings_index := SETTINGS_MASTER
var master_volume := DEFAULT_VOLUME
var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
var fullscreen_enabled := false
var achievement_selected := 0
var achievement_scroll_start := 0
var achievement_completed := [false, false, false, false, false, false, false, false, false, false]
var achievement_slots: Array[Panel] = []
var achievement_inners: Array[Panel] = []
var achievement_labels: Array[Label] = []
var sync_state := SYNC_STATE_IDLE
var sync_countdown_elapsed := 0.0
var sync_elapsed := 0.0
var sync_preview_ms := 0
var sync_measurements: Array[float] = []
var sync_notes := []
var sync_chart_note_texture: Texture2D
var sync_note_outline_texture: Texture2D
var sync_audio_start_time := 0.0
var sync_menu_music_was_playing := false
var blink_timer := 0.0
var blink_white := true
var confirming := false
var arrow_text := ""
var normal_box_style: StyleBoxFlat
var selected_box_style: StyleBoxFlat
var fullscreen_normal_style: StyleBoxFlat
var fullscreen_selected_style: StyleBoxFlat
var achievement_focus_style: StyleBoxFlat
var achievement_no_focus_style: StyleBoxFlat
var achievement_incomplete_style: StyleBoxFlat
var achievement_complete_style: StyleBoxFlat
var menu_music_player: AudioStreamPlayer
var settings_preview_player: AudioStreamPlayer
var sync_music_player: AudioStreamPlayer
var stage_scroll_tween: Tween
var stage_arrow_tween: Tween
var player_move_tween: Tween
var stage_flash_overlay: StageFlashOverlay
var settings_overlay: Node2D


func _ready() -> void:
	arrow_text = PackedByteArray([0xe2, 0x96, 0xbc]).get_string_from_utf8()
	_set_button_texts()
	_build_box_styles()
	_load_current_settings()
	_setup_settings_preview_player()
	_setup_sync_music_player()
	_build_sync_note_textures()
	_collect_achievement_nodes()
	_play_menu_music()
	stage_map.position.x = float(STAGE_MAP_X[selected_stage])
	players_layer.position.x = float(PLAYER_MAP_X[current_stage])
	stage_flash_overlay = StageFlashOverlay.new()
	stage_flash_overlay.z_index = 20
	add_child(stage_flash_overlay)
	settings_overlay = preload("res://SettingsOverlay.gd").new()
	add_child(settings_overlay)
	_update_settings_ui()
	_refresh_achievement_list()
	_update_sync_ui()
	_update_arrow()
	_update_button_styles()


func _process(delta: float) -> void:
	if confirming:
		return
	if sync_open:
		_update_sync_calibration(delta)
		return
	if settings_open or achievements_open:
		return

	blink_timer += delta
	if blink_timer >= BLINK_INTERVAL:
		blink_timer = 0.0
		blink_white = not blink_white
		_update_arrow_color()


func _unhandled_input(event: InputEvent) -> void:
	if confirming:
		return

	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if settings_open:
		settings_overlay.handle_input(key_event)
		if not settings_overlay.visible:
			_close_settings()
		get_viewport().set_input_as_handled()
		return
	if achievements_open:
		_handle_achievements_input(key_event)
		get_viewport().set_input_as_handled()
		return
	if sync_open:
		_handle_sync_input(key_event)
		get_viewport().set_input_as_handled()
		return

	match key_event.keycode:
		KEY_DOWN:
			if selected_index == SELECT_HOME:
				_select(SELECT_SETTINGS)
			get_viewport().set_input_as_handled()
		KEY_UP:
			if selected_index != SELECT_HOME:
				_select(SELECT_HOME)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			if selected_index == SELECT_HOME:
				_select_stage(selected_stage + 1)
			else:
				_select(_next_bottom_selection(1))
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			if selected_index == SELECT_HOME:
				_select_stage(selected_stage - 1)
			else:
				_select(_next_bottom_selection(-1))
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			confirm_selected()


func _select(next_index: int) -> void:
	selected_index = next_index
	blink_timer = 0.0
	blink_white = true
	_update_arrow()
	_update_button_styles()


func _select_stage(next_stage: int) -> void:
	var clamped_stage: int = clampi(next_stage, STAGE_HOME, STAGE_BOSS)
	if clamped_stage == selected_stage:
		return
	var direction: int = signi(clamped_stage - selected_stage)
	selected_stage = clamped_stage
	blink_timer = 0.0
	blink_white = true
	_update_arrow_color()
	_animate_stage_strip()
	_animate_stage_arrow(direction)


func _animate_stage_strip() -> void:
	if stage_scroll_tween and stage_scroll_tween.is_valid():
		stage_scroll_tween.kill()
	stage_scroll_tween = create_tween()
	stage_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	stage_scroll_tween.set_ease(Tween.EASE_IN_OUT)
	stage_scroll_tween.tween_property(
		stage_map,
		"position:x",
		float(STAGE_MAP_X[selected_stage]),
		STAGE_SCROLL_DURATION
	)


func _animate_stage_arrow(direction: int) -> void:
	if stage_arrow_tween and stage_arrow_tween.is_valid():
		stage_arrow_tween.kill()
	stage_arrow_tween = create_tween()
	stage_arrow_tween.set_trans(Tween.TRANS_QUAD)
	stage_arrow_tween.set_ease(Tween.EASE_OUT)
	stage_arrow_tween.tween_property(
		selection_arrow,
		"position:x",
		STAGE_ARROW_REST_X + float(direction) * STAGE_ARROW_NUDGE,
		STAGE_SCROLL_DURATION * 0.35
	)
	stage_arrow_tween.set_trans(Tween.TRANS_BACK)
	stage_arrow_tween.set_ease(Tween.EASE_OUT)
	stage_arrow_tween.tween_property(
		selection_arrow,
		"position:x",
		STAGE_ARROW_REST_X,
		STAGE_SCROLL_DURATION * 0.65
	)


func _next_bottom_selection(direction: int) -> int:
	var bottom_index := selected_index - SELECT_SETTINGS
	bottom_index = posmod(bottom_index + direction, 4)
	return SELECT_SETTINGS + bottom_index


func _update_arrow() -> void:
	selection_arrow.text = arrow_text
	selection_arrow.position = _arrow_position_for_selection(selected_index)
	_update_arrow_color()


func _update_arrow_color() -> void:
	selection_arrow.add_theme_color_override(
		"font_color",
		Color(1.0, 1.0, 1.0, 1.0) if blink_white else Color(0.0, 0.0, 0.0, 1.0)
	)


func _arrow_position_for_selection(index: int) -> Vector2:
	match index:
		SELECT_SETTINGS:
			return _arrow_position_above(settings_box)
		SELECT_ACHIEVEMENTS:
			return _arrow_position_above(achievements_box)
		SELECT_SYNC:
			return _arrow_position_above(sync_box)
		SELECT_RETURN:
			return _arrow_position_above(return_box)
		_:
			return Vector2(612.0, 156.0)


func _arrow_position_above(box: Control) -> Vector2:
	var box_center_x := box.position.x + box.size.x * 0.5
	return Vector2(box_center_x - selection_arrow.size.x * 0.5, box.position.y - 46.0)


func _set_button_texts() -> void:
	settings_text.text = "설정"
	achievements_text.text = "도전과제"
	sync_text.text = "싱크"
	return_text.text = "시작화면"


func _build_box_styles() -> void:
	normal_box_style = _make_box_style(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 1.0))
	selected_box_style = _make_box_style(Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 1.0))
	fullscreen_normal_style = _make_box_style(Color.BLACK, Color.WHITE)
	fullscreen_selected_style = _make_box_style(Color.WHITE, Color.WHITE)
	fullscreen_selected_style.border_width_left = 5
	fullscreen_selected_style.border_width_top = 5
	fullscreen_selected_style.border_width_right = 5
	fullscreen_selected_style.border_width_bottom = 5
	achievement_focus_style = _make_box_style(Color.TRANSPARENT, Color.WHITE)
	achievement_focus_style.border_width_left = 1
	achievement_focus_style.border_width_top = 1
	achievement_focus_style.border_width_right = 1
	achievement_focus_style.border_width_bottom = 1
	achievement_no_focus_style = _make_box_style(Color.TRANSPARENT, Color.TRANSPARENT)
	achievement_no_focus_style.border_width_left = 1
	achievement_no_focus_style.border_width_top = 1
	achievement_no_focus_style.border_width_right = 1
	achievement_no_focus_style.border_width_bottom = 1
	achievement_incomplete_style = _make_box_style(Color.BLACK, Color.WHITE)
	achievement_incomplete_style.border_width_left = 2
	achievement_incomplete_style.border_width_top = 2
	achievement_incomplete_style.border_width_right = 2
	achievement_incomplete_style.border_width_bottom = 2
	achievement_complete_style = _make_box_style(Color.WHITE, Color.WHITE)


func _make_box_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	return style


func _update_button_styles() -> void:
	_apply_button_style(settings_box, settings_text, selected_index == SELECT_SETTINGS)
	_apply_button_style(achievements_box, achievements_text, selected_index == SELECT_ACHIEVEMENTS)
	_apply_button_style(sync_box, sync_text, selected_index == SELECT_SYNC)
	_apply_button_style(return_box, return_text, selected_index == SELECT_RETURN)


func _apply_button_style(box: Control, text_label: Label, selected: bool) -> void:
	box.add_theme_stylebox_override("panel", selected_box_style if selected else normal_box_style)
	text_label.add_theme_color_override(
		"font_color",
		Color(0.0, 0.0, 0.0, 1.0) if selected else Color(1.0, 1.0, 1.0, 1.0)
	)


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
	_hide_main_menu_for_submenu()
	settings_backdrop.visible = false
	settings_panel.visible = false
	settings_overlay.open_settings()


func _close_settings() -> void:
	settings_open = false
	settings_panel.visible = false
	settings_overlay.close_settings()
	_restore_main_menu_from_submenu()


func _hide_main_menu_for_submenu() -> void:
	stage_map.visible = false
	selection_arrow.visible = false
	_set_bottom_buttons_visible(false)


func _restore_main_menu_from_submenu() -> void:
	settings_backdrop.visible = false
	stage_map.visible = true
	selection_arrow.visible = true
	_set_bottom_buttons_visible(true)
	blink_timer = 0.0
	blink_white = true
	_update_arrow()
	_update_button_styles()


func _set_bottom_buttons_visible(show_buttons: bool) -> void:
	for button in [settings_box, achievements_box, sync_box, return_box]:
		button.visible = show_buttons


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
			_play_sfx_preview()
		SETTINGS_FULLSCREEN:
			_set_fullscreen(direction < 0)
	_update_settings_ui()


func _play_sfx_preview() -> void:
	if settings_preview_player.stream == null:
		return
	settings_preview_player.stop()
	settings_preview_player.play()


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


func _collect_achievement_nodes() -> void:
	achievement_slots.clear()
	achievement_inners.clear()
	achievement_labels.clear()
	for slot_index in range(ACHIEVEMENT_VISIBLE_COUNT):
		var slot := get_node("CanvasGroup/AchievementsPanel/AchievementSlot%d" % slot_index) as Panel
		var inner := slot.get_node("Inner") as Panel
		var label := inner.get_node("Text") as Label
		achievement_slots.append(slot)
		achievement_inners.append(inner)
		achievement_labels.append(label)


func _open_achievements() -> void:
	achievements_open = true
	achievement_selected = 0
	achievement_scroll_start = 0
	_hide_main_menu_for_submenu()
	settings_backdrop.visible = true
	achievements_panel.visible = true
	_refresh_achievement_list()


func _close_achievements() -> void:
	achievements_open = false
	achievements_panel.visible = false
	_restore_main_menu_from_submenu()


func _handle_achievements_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			_close_achievements()
		KEY_UP:
			achievement_selected = maxi(0, achievement_selected - 1)
			if achievement_selected < achievement_scroll_start:
				achievement_scroll_start = achievement_selected
			_refresh_achievement_list()
		KEY_DOWN:
			achievement_selected = mini(ACHIEVEMENTS.size() - 1, achievement_selected + 1)
			if achievement_selected >= achievement_scroll_start + ACHIEVEMENT_VISIBLE_COUNT:
				achievement_scroll_start = achievement_selected - ACHIEVEMENT_VISIBLE_COUNT + 1
			_refresh_achievement_list()


func _refresh_achievement_list() -> void:
	if achievement_slots.is_empty():
		return
	for visible_index in range(ACHIEVEMENT_VISIBLE_COUNT):
		var achievement_index := achievement_scroll_start + visible_index
		var selected := achievement_index == achievement_selected
		var completed := bool(achievement_completed[achievement_index])
		achievement_slots[visible_index].add_theme_stylebox_override(
			"panel",
			achievement_focus_style if selected else achievement_no_focus_style
		)
		achievement_inners[visible_index].add_theme_stylebox_override(
			"panel",
			achievement_complete_style if completed else achievement_incomplete_style
		)
		achievement_labels[visible_index].text = "%02d  %s" % [achievement_index + 1, ACHIEVEMENTS[achievement_index]]
		achievement_labels[visible_index].add_theme_color_override(
			"font_color",
			Color.BLACK if completed else Color.WHITE
		)


func set_achievement_completed(achievement_index: int, completed: bool) -> void:
	if achievement_index < 0 or achievement_index >= achievement_completed.size():
		return
	achievement_completed[achievement_index] = completed
	_refresh_achievement_list()


func _setup_sync_music_player() -> void:
	sync_music_player = AudioStreamPlayer.new()
	sync_music_player.name = "SyncCalibrationMusic"
	sync_music_player.bus = BUS_MUSIC
	var stream := load(SYNC_MUSIC_PATH)
	if stream is AudioStream:
		sync_music_player.stream = stream
	add_child(sync_music_player)


func _build_sync_note_textures() -> void:
	var source_image: Image = SYNC_NOTE_TEXTURE.get_image()
	if source_image == null:
		sync_chart_note_texture = SYNC_NOTE_TEXTURE
		sync_note_outline_texture = SYNC_NOTE_TEXTURE
		return
	source_image.convert(Image.FORMAT_RGBA8)
	var chart_image: Image = source_image.duplicate()
	for pixel_y in range(chart_image.get_height()):
		for pixel_x in range(chart_image.get_width()):
			var source_color: Color = chart_image.get_pixel(pixel_x, pixel_y)
			if source_color.a <= 0.0:
				continue
			var border_amount: float = max(source_color.r, max(source_color.g, source_color.b))
			var mapped_color: Color = Color.WHITE.lerp(SYNC_NOTE_COLOR, border_amount)
			mapped_color.a = source_color.a
			chart_image.set_pixel(pixel_x, pixel_y, mapped_color)
	sync_chart_note_texture = ImageTexture.create_from_image(chart_image)
	var image_size := Vector2i(source_image.get_width(), source_image.get_height())
	var image_rect := Rect2i(Vector2i.ZERO, image_size)
	var white_image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	white_image.fill(Color.WHITE)
	var outline_image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	outline_image.fill(Color.TRANSPARENT)
	for offset_y in range(-SYNC_NOTE_OUTLINE_RADIUS, SYNC_NOTE_OUTLINE_RADIUS + 1):
		for offset_x in range(-SYNC_NOTE_OUTLINE_RADIUS, SYNC_NOTE_OUTLINE_RADIUS + 1):
			if offset_x * offset_x + offset_y * offset_y > SYNC_NOTE_OUTLINE_RADIUS * SYNC_NOTE_OUTLINE_RADIUS:
				continue
			outline_image.blit_rect_mask(white_image, source_image, image_rect, Vector2i(offset_x, offset_y))
	sync_note_outline_texture = ImageTexture.create_from_image(outline_image)
	sync_target_outline.texture = sync_note_outline_texture
	sync_target_outline.modulate = Color.WHITE
	sync_target_note.texture = SYNC_NOTE_TEXTURE
	sync_target_note.modulate = SYNC_NOTE_COLOR


func _open_sync() -> void:
	sync_open = true
	sync_preview_ms = roundi(GameSettings.audio_offset_seconds * 1000.0)
	_hide_main_menu_for_submenu()
	settings_backdrop.visible = true
	sync_panel.visible = true
	_stop_sync_calibration()
	_update_sync_ui()


func _close_sync() -> void:
	_stop_sync_calibration()
	sync_open = false
	sync_panel.visible = false
	_restore_main_menu_from_submenu()


func _handle_sync_input(key_event: InputEventKey) -> void:
	match key_event.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			_close_sync()
		KEY_ENTER, KEY_KP_ENTER:
			if sync_state == SYNC_STATE_IDLE:
				_start_sync_calibration()
			else:
				_save_sync_calibration()
		KEY_SPACE, KEY_UP, KEY_F, KEY_K:
			if sync_state == SYNC_STATE_RUNNING:
				_register_sync_hit()


func _start_sync_calibration() -> void:
	_stop_sync_calibration()
	sync_state = SYNC_STATE_COUNTDOWN
	sync_countdown_elapsed = 0.0
	sync_measurements.clear()
	sync_countdown_text.text = "3"
	_update_sync_ui()


func _begin_sync_notes() -> void:
	sync_state = SYNC_STATE_RUNNING
	sync_elapsed = 0.0
	sync_countdown_text.visible = false
	_create_sync_notes()
	sync_menu_music_was_playing = menu_music_player != null and menu_music_player.playing
	if sync_menu_music_was_playing:
		menu_music_player.stream_paused = true
	if sync_music_player.stream:
		sync_music_player.play(sync_audio_start_time)
	_update_sync_ui()


func _create_sync_notes() -> void:
	_clear_sync_notes()
	var chart_notes: Array[Dictionary] = _load_sync_chart_notes()
	if chart_notes.is_empty():
		return
	var first_chart_time: float = float(chart_notes[0]["chart_time"])
	var fall_lead_time: float = (SYNC_TARGET_Y - SYNC_START_Y) / SYNC_NOTE_SPEED
	sync_audio_start_time = maxf(0.0, first_chart_time - fall_lead_time)
	for note_index in range(chart_notes.size()):
		var chart_data: Dictionary = chart_notes[note_index]
		var note_node := Control.new()
		note_node.name = "CalibrationNote%d" % note_index
		note_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note_node.size = Vector2(72.0, 72.0)
		note_node.position = Vector2(44.0, SYNC_START_Y)
		var outline_node := TextureRect.new()
		outline_node.texture = sync_note_outline_texture
		outline_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		outline_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline_node.size = note_node.size
		outline_node.modulate = Color.BLACK
		note_node.add_child(outline_node)
		var chart_node := TextureRect.new()
		chart_node.texture = sync_chart_note_texture
		chart_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chart_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chart_node.size = note_node.size
		note_node.add_child(chart_node)
		sync_note_field.add_child(note_node)
		sync_notes.append({
			"time": float(chart_data["chart_time"]) - sync_audio_start_time,
			"node": note_node,
			"judged": false,
		})


func _load_sync_chart_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(SYNC_CHART_PATH):
		push_warning("Sync chart not found: %s" % SYNC_CHART_PATH)
		return result
	var chart_text: String = FileAccess.get_file_as_string(SYNC_CHART_PATH)
	var parsed_data: Variant = JSON.parse_string(chart_text)
	if not parsed_data is Dictionary:
		push_warning("Invalid sync chart JSON: %s" % SYNC_CHART_PATH)
		return result
	var chart_data: Dictionary = parsed_data
	var raw_notes: Array = chart_data.get("notes", [])
	var used_times: Dictionary = {}
	for raw_note in raw_notes:
		if not raw_note is Dictionary:
			continue
		var note_data: Dictionary = raw_note
		if String(note_data.get("side", "player")) != "player":
			continue
		var chart_time: float = float(note_data.get("time", 0.0))
		var time_key: String = "%.6f" % chart_time
		if used_times.has(time_key):
			continue
		used_times[time_key] = true
		result.append({
			"chart_time": chart_time,
		})
		if result.size() >= SYNC_NOTE_COUNT:
			break
	return result


func _clear_sync_notes() -> void:
	for note_data in sync_notes:
		var note_node: Control = note_data["node"]
		if is_instance_valid(note_node):
			note_node.queue_free()
	sync_notes.clear()


func _update_sync_calibration(delta: float) -> void:
	if sync_state == SYNC_STATE_COUNTDOWN:
		sync_countdown_elapsed += delta
		var countdown_value := 3 - int(floor(sync_countdown_elapsed))
		if countdown_value <= 0:
			_begin_sync_notes()
		else:
			sync_countdown_text.text = str(countdown_value)
		return
	if sync_state != SYNC_STATE_RUNNING:
		return
	sync_elapsed += delta
	for note_data in sync_notes:
		var note_time := float(note_data["time"])
		var note_node: Control = note_data["node"]
		if bool(note_data["judged"]):
			continue
		note_node.position.y = SYNC_TARGET_Y + (sync_elapsed - note_time) * SYNC_NOTE_SPEED
		note_node.visible = note_node.position.y >= SYNC_START_Y and note_node.position.y <= SYNC_END_Y
		if sync_elapsed > note_time + SYNC_HIT_WINDOW:
			note_data["judged"] = true
			note_node.visible = false


func _register_sync_hit() -> void:
	var closest_note: Dictionary = {}
	var closest_error: float = INF
	for note_data in sync_notes:
		if bool(note_data["judged"]):
			continue
		var error: float = abs(sync_elapsed - float(note_data["time"]))
		if error < closest_error:
			closest_error = error
			closest_note = note_data
	if closest_note.is_empty() or closest_error > SYNC_HIT_WINDOW:
		return
	var signed_error: float = sync_elapsed - float(closest_note["time"])
	sync_measurements.append(signed_error)
	var closest_time: float = float(closest_note["time"])
	for note_data in sync_notes:
		if bool(note_data["judged"]):
			continue
		if abs(float(note_data["time"]) - closest_time) > 0.001:
			continue
		note_data["judged"] = true
		var note_node: Control = note_data["node"]
		note_node.visible = false
	sync_preview_ms = roundi(_average_sync_measurement() * 1000.0)
	_play_sfx_preview()
	_pop_sync_target_note()
	_update_sync_ui()


func _average_sync_measurement() -> float:
	if sync_measurements.is_empty():
		return float(sync_preview_ms) / 1000.0
	var total := 0.0
	for measurement in sync_measurements:
		total += measurement
	return clamp(total / float(sync_measurements.size()), -0.25, 0.25)


func _pop_sync_target_note() -> void:
	sync_target_note.pivot_offset = sync_target_note.size * 0.5
	sync_target_outline.pivot_offset = sync_target_outline.size * 0.5
	sync_target_note.scale = Vector2(1.18, 1.18)
	sync_target_outline.scale = Vector2(1.18, 1.18)
	var pop_tween := create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK)
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(sync_target_note, "scale", Vector2.ONE, 0.16)
	pop_tween.parallel().tween_property(sync_target_outline, "scale", Vector2.ONE, 0.16)


func _save_sync_calibration() -> void:
	if not sync_measurements.is_empty():
		sync_preview_ms = roundi(_average_sync_measurement() * 1000.0)
	GameSettings.save_audio_offset(float(sync_preview_ms) / 1000.0)
	_stop_sync_calibration()
	_update_sync_ui()


func _stop_sync_calibration() -> void:
	if sync_music_player:
		sync_music_player.stop()
	if sync_menu_music_was_playing and menu_music_player:
		menu_music_player.stream_paused = false
	sync_menu_music_was_playing = false
	_clear_sync_notes()
	sync_state = SYNC_STATE_IDLE
	sync_countdown_text.visible = false
	sync_target_note.scale = Vector2.ONE
	sync_target_outline.scale = Vector2.ONE
	_update_sync_ui()


func _update_sync_ui() -> void:
	if not sync_current_text:
		return
	var sign_text := "+" if sync_preview_ms >= 0 else ""
	sync_current_text.text = "현재 싱크: %s%d ms" % [sign_text, sync_preview_ms]
	match sync_state:
		SYNC_STATE_COUNTDOWN:
			sync_countdown_text.visible = true
			sync_target_note.visible = false
			sync_target_outline.visible = false
			sync_button_text.text = "카운트다운 중"
		SYNC_STATE_RUNNING:
			sync_countdown_text.visible = false
			sync_target_note.visible = true
			sync_target_outline.visible = true
			sync_button_text.text = "Enter로 싱크 저장"
		_:
			sync_countdown_text.visible = false
			sync_target_note.visible = true
			sync_target_outline.visible = true
			sync_button_text.text = "싱크 맞추기"


func confirm_selected() -> void:
	confirming = true
	if selected_index == SELECT_HOME and selected_stage != STAGE_HOME:
		await _confirm_stage_selection()
	else:
		for i in range(CONFIRM_BLINK_COUNT):
			_set_selected_button_confirm_flash(i % 2 == 0)
			await get_tree().create_timer(CONFIRM_BLINK_INTERVAL).timeout

	await _activate_selected()
	confirming = false
	blink_timer = 0.0
	blink_white = true
	_update_arrow()
	_update_button_styles()


func _confirm_stage_selection() -> void:
	if stage_scroll_tween and stage_scroll_tween.is_valid() and stage_scroll_tween.is_running():
		await stage_scroll_tween.finished

	if player_move_tween and player_move_tween.is_valid():
		player_move_tween.kill()
	player_move_tween = create_tween()
	player_move_tween.set_trans(Tween.TRANS_CUBIC)
	player_move_tween.set_ease(Tween.EASE_OUT)
	player_move_tween.tween_property(
		players_layer,
		"position:x",
		float(PLAYER_MAP_X[selected_stage]),
		PLAYER_MOVE_DURATION
	)

	for i in range(CONFIRM_BLINK_COUNT):
		var flash_on: bool = i % 2 == 0
		stage_flash_overlay.set_flash(flash_on)
		selection_arrow.add_theme_color_override(
			"font_color",
			Color.BLACK if flash_on else Color.WHITE
		)
		await get_tree().create_timer(CONFIRM_BLINK_INTERVAL).timeout

	stage_flash_overlay.set_flash(false)
	current_stage = selected_stage


func _activate_selected() -> void:
	if selected_index == SELECT_HOME:
		if selected_stage == STAGE_1:
			get_tree().change_scene_to_file("res://Main.tscn")
		return
	if selected_index == SELECT_SETTINGS:
		_open_settings()
		return
	if selected_index == SELECT_ACHIEVEMENTS:
		_open_achievements()
		return
	if selected_index == SELECT_SYNC:
		_open_sync()
		return
	if selected_index == SELECT_RETURN:
		get_tree().change_scene_to_file("res://StartMenu.tscn")


func _set_selected_button_confirm_flash(inverted: bool) -> void:
	match selected_index:
		SELECT_SETTINGS:
			_apply_button_style(settings_box, settings_text, inverted)
		SELECT_ACHIEVEMENTS:
			_apply_button_style(achievements_box, achievements_text, inverted)
		SELECT_SYNC:
			_apply_button_style(sync_box, sync_text, inverted)
		SELECT_RETURN:
			_apply_button_style(return_box, return_text, inverted)
		_:
			selection_arrow.add_theme_color_override(
				"font_color",
				Color(1.0, 1.0, 1.0, 1.0) if inverted else Color(0.0, 0.0, 0.0, 1.0)
			)


func _exit_tree() -> void:
	if menu_music_player:
		menu_music_player.stop()


func _play_menu_music() -> void:
	menu_music_player = AudioStreamPlayer.new()
	menu_music_player.name = "MenuMusic"
	add_child(menu_music_player)

	var stream := load(MENU_MUSIC_PATH)
	if stream is AudioStream:
		menu_music_player.stream = stream
	if menu_music_player.stream is AudioStreamWAV:
		var wav_stream := menu_music_player.stream as AudioStreamWAV
		wav_stream.loop_begin = 0
		wav_stream.loop_end = int(wav_stream.get_length() * wav_stream.mix_rate)
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	menu_music_player.bus = BUS_MUSIC
	menu_music_player.volume_db = 0.0
	menu_music_player.stream_paused = false
	await get_tree().process_frame
	menu_music_player.play()
