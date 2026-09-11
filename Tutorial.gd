extends Control

signal mode_selection_finished(cancelled: bool)

@export var mode_select_only := false

const MENU_FONT := preload("res://fonts/Mona12TextJP.ttf")
const CAT_TEXTURE := preload("res://images/cat.png")
const CAT2_TEXTURE := preload("res://images/cat2.png")
const NOTE_TEXTURES := [
	preload("res://images/left.png"),
	preload("res://images/down.png"),
	preload("res://images/up.png"),
	preload("res://images/right.png"),
]
const TYPE_INTERVAL := 0.045
const BLINK_INTERVAL := 0.42
const CONFIRM_BLINK_INTERVAL := 0.045
const CONFIRM_BLINK_COUNT := 10
const TUTORIAL_MUSIC_PATH := "res://audio/tutorial.wav"
const PERFECT_SOUND_P1_PATH := "res://audio/perfect_p1.wav"
const PERFECT_SOUND_P2_PATH := "res://audio/perfect.wav"
const LONGNOTE_SOUND_P1_PATH := "res://audio/longnote_p1.wav"
const LONGNOTE_SOUND_P2_PATH := "res://audio/longnote.wav"
const FLICK_SOUND_P1_PATH := "res://audio/flick_p1.wav"
const FLICK_SOUND_P2_PATH := "res://audio/flick.wav"
const LONGNOTE_START_VOLUME_DB := 0.0
const LONGNOTE_END_VOLUME_DB := -12.0
const FLICK_VOLUME_DB := -8.0
const CHOICE_YES := 0
const CHOICE_NO := 1
const DIALOGUE_MODE_INTRO := "intro"
const DIALOGUE_MODE_BASIC := "basic"
const SIDE_DIALOGUE_NONE := -1
const SIDE_DIALOGUE_P1 := 0
const SIDE_DIALOGUE_P2 := 1
const SIDE_CONTEXT_NONE := -1
const SIDE_CONTEXT_GAUGE := 0
const SIDE_CONTEXT_ATTACK := 1
const SIDE_DIALOGUE_START_DELAY := 0.5
const SIDE_DIALOGUE_NEXT_DELAY := 0.35
const MODE_SCREEN_PLAY_STYLE := 0
const MODE_SCREEN_PLAYER := 1
const MODE_CHOICE_SINGLE := 0
const MODE_CHOICE_MULTI := 1
const PLAYER_CHOICE_GG := 0
const PLAYER_CHOICE_EZ := 1
const LANE_KEYCODES_P1 := [KEY_A, KEY_S, KEY_D, KEY_F]
const LANE_KEYCODES_P2 := [KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]
const LANE_KEYCODES_ARROWS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const LANE_COLORS := [Color("e0863c"), Color("48a6a2"), Color("c65b86"), Color("d9b24a")]
const NOTE_OUTLINE_RADIUS := 12
const PRACTICE_NONE := -1
const PRACTICE_TAP := 0
const PRACTICE_HOLD := 1
const PRACTICE_SLUR := 2
const PRACTICE_RAPID := 3
const PRACTICE_NOTE_SPEED := 280.0
const PRACTICE_HIT_WINDOW := 0.18
const PRACTICE_NOTE_SIZE := 72.0
const PRACTICE_RAPID_DURATION := 2.2
const PRACTICE_RAPID_TAPS := 30

# Typewriter blip sound. Assign the sound in the Inspector on the Tutorial node.
@export var typing_sound: AudioStream
@export_range(-40.0, 6.0, 0.5) var typing_sound_volume_db: float = -14.0
@export_range(1, 10, 1) var typing_sound_char_interval: int = 1
# Per-speaker typewriter blips for the P1/P2 side dialogue bubbles. Falls back to
# typing_sound above (unchanged) whenever the cat bubble is the one typing.
@export var typing_sound_p1: AudioStream
@export var typing_sound_p2: AudioStream
const TYPING_SOUND_PITCH_MIN := 0.95
const TYPING_SOUND_PITCH_MAX := 1.05

class DottedBubble:
	extends Control

	var fill_color := Color.BLACK
	var border_color := Color.WHITE
	var label: Label
	var next_marker: Label
	var tail_side := ""
	var tail_offset := 0.5
	var tail_size := Vector2(28.0, 24.0)
	var dot_size := 4.0
	var dot_gap := 8.0

	func setup(font: Font, font_size: int) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		label = Label.new()
		label.position = Vector2(18.0, 12.0)
		label.size = size - Vector2(36.0, 24.0)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)

		next_marker = Label.new()
		next_marker.position = size - Vector2(44.0, 34.0)
		next_marker.size = Vector2(34.0, 28.0)
		next_marker.add_theme_font_override("font", font)
		next_marker.add_theme_font_size_override("font_size", 22)
		next_marker.add_theme_color_override("font_color", Color.WHITE)
		next_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		next_marker.visible = false
		add_child(next_marker)

	func set_text(text_value: String) -> void:
		label.text = text_value

	func set_tail(side: String, offset_ratio: float) -> void:
		tail_side = side
		tail_offset = offset_ratio
		queue_redraw()

	func set_next_marker(text_value: String, visible_value: bool) -> void:
		next_marker.text = text_value
		next_marker.visible = visible_value

	func set_next_marker_visible(visible_value: bool) -> void:
		next_marker.visible = visible_value

	func set_colors(new_fill: Color, new_border: Color, text_color: Color) -> void:
		fill_color = new_fill
		border_color = new_border
		label.add_theme_color_override("font_color", text_color)
		next_marker.add_theme_color_override("font_color", text_color)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and label:
			label.size = size - Vector2(36.0, 24.0)
			next_marker.position = size - Vector2(44.0, 34.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), fill_color)
		_draw_tail()
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(Vector2(x, 0.0), Vector2(dot_size, dot_size)), border_color)
			draw_rect(Rect2(Vector2(x, size.y - dot_size), Vector2(dot_size, dot_size)), border_color)
			x += dot_gap
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(Vector2(0.0, y), Vector2(dot_size, dot_size)), border_color)
			draw_rect(Rect2(Vector2(size.x - dot_size, y), Vector2(dot_size, dot_size)), border_color)
			y += dot_gap

	func _draw_tail() -> void:
		if tail_side.is_empty():
			return

		var points := PackedVector2Array()
		if tail_side == "bottom":
			var x := size.x * tail_offset
			points = PackedVector2Array([
				Vector2(x - tail_size.x * 0.5, size.y),
				Vector2(x + tail_size.x * 0.5, size.y),
				Vector2(x, size.y + tail_size.y),
			])
		elif tail_side == "left":
			var y := size.y * tail_offset
			points = PackedVector2Array([
				Vector2(0.0, y - tail_size.y * 0.5),
				Vector2(0.0, y + tail_size.y * 0.5),
				Vector2(-tail_size.x, y),
			])
		elif tail_side == "right":
			var y := size.y * tail_offset
			points = PackedVector2Array([
				Vector2(size.x, y - tail_size.y * 0.5),
				Vector2(size.x, y + tail_size.y * 0.5),
				Vector2(size.x + tail_size.x, y),
			])
		else:
			return

		draw_colored_polygon(points, fill_color)
		for point in points:
			draw_rect(Rect2(point - Vector2(dot_size * 0.5, dot_size * 0.5), Vector2(dot_size, dot_size)), border_color)


class StatusBar:
	extends Control

	var current_value := 0.0
	var max_value := 100.0
	var label_text := ""
	var fill_inset := 7.0
	var border_width := 4.0
	var outer_border_width := 0.0
	var base_label: Label
	var fill_clip: Control
	var fill_label: Label

	func setup(font: Font, text_size: int) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		base_label = _make_label(font, text_size, Color.WHITE)
		add_child(base_label)

		fill_clip = Control.new()
		fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill_clip.clip_contents = true
		add_child(fill_clip)

		fill_label = _make_label(font, text_size, Color.BLACK)
		fill_clip.add_child(fill_label)
		_sync_labels()

	func set_stats(new_value: float, new_max_value: float, new_label_text: String) -> void:
		current_value = new_value
		max_value = max(0.001, new_max_value)
		label_text = new_label_text
		_sync_labels()

	func set_outer_black_border(width: float) -> void:
		outer_border_width = max(0.0, width)
		_sync_labels()

	func _make_label(font: Font, text_size: int, color: Color) -> Label:
		var new_label := Label.new()
		new_label.add_theme_font_override("font", font)
		new_label.add_theme_font_size_override("font_size", text_size)
		new_label.add_theme_color_override("font_color", color)
		new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		new_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return new_label

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_sync_labels()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)

		var ratio: float = clamp(current_value / max_value, 0.0, 1.0)
		var bar_rect := Rect2(
			Vector2(outer_border_width, outer_border_width),
			Vector2(max(0.0, size.x - outer_border_width * 2.0), max(0.0, size.y - outer_border_width * 2.0))
		)
		var inner_rect := Rect2(
			bar_rect.position + Vector2(fill_inset, fill_inset),
			Vector2(max(0.0, bar_rect.size.x - fill_inset * 2.0), max(0.0, bar_rect.size.y - fill_inset * 2.0))
		)
		draw_rect(Rect2(inner_rect.position, Vector2(inner_rect.size.x * ratio, inner_rect.size.y)), Color.WHITE, true)
		draw_rect(bar_rect, Color.WHITE, false, border_width)

	func _sync_labels() -> void:
		if not base_label:
			return

		var ratio: float = clamp(current_value / max_value, 0.0, 1.0)
		var bar_pos := Vector2(outer_border_width, outer_border_width)
		var bar_size := Vector2(max(0.0, size.x - outer_border_width * 2.0), max(0.0, size.y - outer_border_width * 2.0))
		var text_pos := bar_pos + Vector2(18.0, 0.0)
		var text_size := Vector2(max(0.0, bar_size.x - 36.0), bar_size.y)
		var inner_pos := bar_pos + Vector2(fill_inset, fill_inset)
		var inner_size := Vector2(max(0.0, bar_size.x - fill_inset * 2.0), max(0.0, bar_size.y - fill_inset * 2.0))

		base_label.text = label_text
		base_label.position = text_pos
		base_label.size = text_size

		fill_clip.position = inner_pos
		fill_clip.size = Vector2(inner_size.x * ratio, inner_size.y)

		fill_label.text = label_text
		fill_label.position = text_pos - inner_pos
		fill_label.size = text_size
		queue_redraw()


class MenuChoiceBox:
	extends Control

	var label: Label
	var fill_color := Color.BLACK
	var border_color := Color.WHITE
	var text_color := Color.WHITE
	var border_width := 4.0

	func setup(font: Font, font_size: int, text_value: String) -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		label = Label.new()
		label.position = Vector2.ZERO
		label.size = size
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		set_text(text_value)
		set_selected(false, false)

	func set_text(text_value: String) -> void:
		if label:
			label.text = text_value

	func set_selected(selected: bool, blink_on_value: bool) -> void:
		if selected and blink_on_value:
			fill_color = Color.WHITE
			border_color = Color.BLACK
			text_color = Color.BLACK
		else:
			fill_color = Color.BLACK
			border_color = Color.WHITE
			text_color = Color.WHITE
		if label:
			label.add_theme_color_override("font_color", text_color)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and label:
			label.position = Vector2.ZERO
			label.size = size

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), fill_color, true)
		draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)


class RhythmArrow:
	extends Control

	signal arrow_pressed(side: int, lane: int)
	signal arrow_released(side: int, lane: int)

	var side := 0
	var lane := 0
	var normal_texture: Texture2D
	var inverted_texture: Texture2D
	var inverted := false
	var feedback_running := false

	func setup(new_side: int, new_lane: int, texture: Texture2D) -> void:
		side = new_side
		lane = new_lane
		normal_texture = texture
		inverted_texture = _make_inverted_texture(texture)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = size * 0.5
		tooltip_text = "note"

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if mouse_event.pressed:
					trigger_feedback()
					arrow_pressed.emit(side, lane)
				else:
					arrow_released.emit(side, lane)
				accept_event()
		elif event is InputEventScreenTouch:
			var touch_event := event as InputEventScreenTouch
			if touch_event.pressed:
				trigger_feedback()
				arrow_pressed.emit(side, lane)
			else:
				arrow_released.emit(side, lane)
			accept_event()

	func _draw() -> void:
		var texture := inverted_texture if inverted and inverted_texture != null else normal_texture
		if texture:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)

	func trigger_feedback() -> void:
		inverted = true
		queue_redraw()
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.22, 1.22), 0.06)
		tween.tween_property(self, "scale", Vector2.ONE, 0.12)
		if not feedback_running:
			feedback_running = true
			await get_tree().create_timer(0.09).timeout
			inverted = false
			feedback_running = false
			queue_redraw()

	func _make_inverted_texture(texture: Texture2D) -> Texture2D:
		if texture == null:
			return null
		var image := texture.get_image()
		if image == null:
			return null
		image.convert(Image.FORMAT_RGBA8)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(1.0 - color.r, 1.0 - color.g, 1.0 - color.b, color.a))
		return ImageTexture.create_from_image(image)


class PracticeNoteLayer:
	extends Control

	var tutorial: Control

	func setup(new_tutorial: Control) -> void:
		tutorial = new_tutorial
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if tutorial:
			tutorial._draw_practice_layer(self)

var cat_bubble: DottedBubble
var p1_bubble: DottedBubble
var p2_bubble: DottedBubble
var yes_bubble: DottedBubble
var no_bubble: DottedBubble
var dialogue_lines: Array[String] = []
var basic_dialogue_lines: Array[String] = []
var dialogue_mode := DIALOGUE_MODE_INTRO
var dialogue_index := 0
var active_bubble: DottedBubble
var active_line := ""
var side_dialogue_step := SIDE_DIALOGUE_NONE
var side_dialogue_context := SIDE_CONTEXT_NONE
var pending_side_dialogue_context := SIDE_CONTEXT_NONE
var typed_chars := 0
var type_timer := 0.0
var typing := false
var choices_open := false
var selected_choice := CHOICE_YES
var blink_timer := 0.0
var blink_on := true
var confirming := false
var next_marker_text := ""
var next_marker_blink_timer := 0.0
var next_marker_on := true
var tutorial_music_player: AudioStreamPlayer
var typing_sound_player: AudioStreamPlayer
var typing_sound_player_p1: AudioStreamPlayer
var typing_sound_player_p2: AudioStreamPlayer
var typing_sound_visible_char_count := 0
var typing_sound_in_bbcode_tag := false
var boss_hp_bar: StatusBar
var gauge_bar: StatusBar
var p1_hp_bar: StatusBar
var p2_hp_bar: StatusBar
var practice_layer: PracticeNoteLayer
var note_arrows := []
var note_inverted_textures := []
var chart_note_textures: Array[Texture2D] = []
var note_outline_textures: Array[Texture2D] = []
var perfect_stream_p1: AudioStream
var perfect_stream_p2: AudioStream
var longnote_stream_p1: AudioStream
var longnote_stream_p2: AudioStream
var flick_stream_p1: AudioStream
var flick_stream_p2: AudioStream
var longnote_player_p1: AudioStreamPlayer
var longnote_player_p2: AudioStreamPlayer
var note_sound_players := []
var note_sound_index := 0
var cat_sprite: TextureRect
var mode_select_active := false
var mode_select_screen := MODE_SCREEN_PLAY_STYLE
var mode_selected_index := MODE_CHOICE_SINGLE
var mode_blink_timer := 0.0
var mode_blink_on := true
var mode_confirming := false
var tutorial_multiplayer := true
var tutorial_human_side := PLAYER_CHOICE_GG
var mode_dim_rect: ColorRect
var mode_prompt_label: Label
var mode_buttons := []
var player_buttons := []
var return_to_start_after_line := false
var lesson_dialogue_active := false
var lesson_pending_practice_type := PRACTICE_NONE
var lesson_pending_sides := [true, true]
var next_marker_enabled := true
var practice_active := false
var practice_type := PRACTICE_NONE
var practice_time := 0.0
var practice_notes := []
var practice_sides := [false, false]
var practice_misses := [0, 0]
var practice_held := [[false, false, false, false], [false, false, false, false]]
var practice_active_slur_chain := [-1, -1]
var practice_active_slur_next_index := [0, 0]
var practice_active_slur_held_lanes := [[], []]
var practice_flick_sustain_end_times := [[], []]
var practice_rng := RandomNumberGenerator.new()
var practice_pointer_active := false
var practice_pointer_side := -1
var practice_pointer_position := Vector2.ZERO


func _ready() -> void:
	if mode_select_only:
		get_node_or_null("Background").visible = false
		_build_mode_select_overlay()
		_show_mode_select_screen(MODE_SCREEN_PLAY_STYLE)
		return
	next_marker_text = PackedByteArray([0xe2, 0x96, 0xb6]).get_string_from_utf8()
	var background := get_node_or_null("Background") as CanvasItem
	if background:
		background.show_behind_parent = true
	cat_sprite = get_node_or_null("Background/cat") as TextureRect
	practice_rng.randomize()
	_build_inverted_note_textures()
	_build_note_outline_textures()
	_build_chart_note_textures()
	_build_dialogue_lines()
	_build_practice_layer()
	_build_status_bars()
	_build_note_arrows()
	_build_bubbles()
	_build_mode_select_overlay()
	_play_tutorial_music()
	_setup_typing_sound_player()
	_setup_side_typing_sound_players()
	_setup_note_sound_players()
	_show_mode_select_screen(MODE_SCREEN_PLAY_STYLE)


func _process(delta: float) -> void:
	if mode_select_active:
		_update_mode_select_blink(delta)
		return

	if practice_active:
		_update_practice(delta)

	if typing:
		type_timer += delta
		while type_timer >= TYPE_INTERVAL and typing:
			type_timer -= TYPE_INTERVAL
			typed_chars += 1
			active_bubble.set_text(active_line.substr(0, typed_chars))
			_handle_typing_sound_for_char(active_line.substr(typed_chars - 1, 1))
			if typed_chars >= active_line.length():
				typing = false
				_on_dialogue_line_complete()

	if choices_open and not confirming:
		blink_timer += delta
		if blink_timer >= BLINK_INTERVAL:
			blink_timer = 0.0
			blink_on = not blink_on
			_update_choice_styles()

	if active_bubble and active_bubble.visible and not typing and next_marker_enabled:
		next_marker_blink_timer += delta
		if next_marker_blink_timer >= BLINK_INTERVAL:
			next_marker_blink_timer = 0.0
			next_marker_on = not next_marker_on
			active_bubble.set_next_marker_visible(next_marker_on)


func _input(event: InputEvent) -> void:
	if not practice_active:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_practice_pointer(mouse_event.position)
		else:
			_end_practice_pointer()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if practice_pointer_active and bool(mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_update_practice_pointer(mouse_motion.position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_practice_pointer(touch_event.position)
		else:
			_end_practice_pointer()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if practice_pointer_active:
			_update_practice_pointer(drag_event.position)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if mode_select_active:
		_handle_mode_select_input(event)
		return

	if practice_active and event is InputEventKey:
		if _handle_practice_key(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return

	if confirming:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and choices_open:
			if Rect2(yes_bubble.position, yes_bubble.size).has_point(mouse_event.position):
				selected_choice = CHOICE_YES
				_update_choice_styles()
				confirm_choice()
			elif Rect2(no_bubble.position, no_bubble.size).has_point(mouse_event.position):
				selected_choice = CHOICE_NO
				_update_choice_styles()
				confirm_choice()
		return

	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://StartMenu.tscn")
		return

	if choices_open:
		match key_event.keycode:
			KEY_LEFT, KEY_RIGHT:
				selected_choice = CHOICE_NO if selected_choice == CHOICE_YES else CHOICE_YES
				blink_timer = 0.0
				blink_on = true
				_update_choice_styles()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				get_viewport().set_input_as_handled()
				confirm_choice()
		return

	if _handle_note_key(key_event):
		get_viewport().set_input_as_handled()
		return

	match key_event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			_advance_dialogue()


func _exit_tree() -> void:
	if tutorial_music_player:
		tutorial_music_player.stop()
	for player in note_sound_players:
		if player:
			player.stop()
	if longnote_player_p1 and longnote_player_p1.playing:
		longnote_player_p1.stop()
	if longnote_player_p2 and longnote_player_p2.playing:
		longnote_player_p2.stop()


func _build_dialogue_lines() -> void:
	dialogue_mode = DIALOGUE_MODE_INTRO
	dialogue_lines = [
		PackedByteArray([0xed, 0x8a, 0x9c, 0xed, 0x86, 0xa0, 0xeb, 0xa6, 0xac, 0xec, 0x96, 0xbc, 0xec, 0x9d, 0x84, 0x20, 0xed, 0x95, 0x98, 0xeb, 0x9f, 0xac, 0x20, 0xec, 0x98, 0xa4, 0xeb, 0x8b, 0xa4, 0xeb, 0x8b, 0x88, 0x2c, 0x0a, 0xed, 0x97, 0x88, 0xec, 0xa0, 0x91, 0xeb, 0x93, 0xa4, 0xec, 0x9d, 0xb4, 0xea, 0xb5, 0xac, 0xeb, 0x82, 0x98, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xec, 0x9b, 0x90, 0xed, 0x95, 0x9c, 0xeb, 0x8b, 0xa4, 0xeb, 0xa9, 0xb4, 0x20, 0xea, 0xb8, 0xb0, 0xec, 0xb4, 0x88, 0xeb, 0xb6, 0x80, 0xed, 0x84, 0xb0, 0x0a, 0xec, 0xb0, 0xa8, 0xea, 0xb7, 0xbc, 0xec, 0xb0, 0xa8, 0xea, 0xb7, 0xbc, 0x20, 0xea, 0xb0, 0x80, 0xeb, 0xa5, 0xb4, 0xec, 0xb3, 0x90, 0xec, 0xa3, 0xbc, 0xec, 0xa7, 0x80, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xea, 0xb7, 0xb8, 0xeb, 0x9f, 0xbc, 0x2c, 0x20, 0xed, 0x8a, 0x9c, 0xed, 0x86, 0xa0, 0xeb, 0xa6, 0xac, 0xec, 0x96, 0xbc, 0xec, 0x9d, 0x84, 0x20, 0xec, 0xa7, 0x84, 0xed, 0x96, 0x89, 0xed, 0x95, 0xa0, 0xea, 0xb9, 0x8c, 0x3f]).get_string_from_utf8(),
	]
	basic_dialogue_lines = [
		PackedByteArray([0xec, 0xa2, 0x8b, 0xec, 0x95, 0x84, 0x2c, 0x20, 0xec, 0xb2, 0x98, 0xec, 0x9d, 0x8c, 0xeb, 0xb6, 0x80, 0xed, 0x84, 0xb0, 0x20, 0xec, 0x95, 0x8c, 0xeb, 0xa0, 0xa4, 0xec, 0xa4, 0x84, 0xea, 0xb2, 0x8c, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xec, 0x9c, 0x84, 0xec, 0x97, 0x90, 0x20, 0xeb, 0x9c, 0xa8, 0xeb, 0x8a, 0x94, 0x20, 0xea, 0xb8, 0xb4, 0x20, 0xeb, 0xa7, 0x89, 0xeb, 0x8c, 0x80, 0xea, 0xb8, 0xb0, 0xeb, 0x8a, 0x94, 0x0a, 0xec, 0xa0, 0x81, 0xec, 0x9d, 0x98, 0x20, 0xec, 0xb2, 0xb4, 0xeb, 0xa0, 0xa5, 0xec, 0x9d, 0xb4, 0xec, 0x95, 0xbc, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xec, 0x95, 0x84, 0xeb, 0x9e, 0x98, 0xec, 0x97, 0x90, 0x20, 0xeb, 0x9c, 0xa8, 0xeb, 0x8a, 0x94, 0x20, 0xea, 0xb8, 0xb4, 0x20, 0xeb, 0xa7, 0x89, 0xeb, 0x8c, 0x80, 0xea, 0xb8, 0xb0, 0xeb, 0x8a, 0x94, 0x0a, 0xeb, 0x84, 0x88, 0xed, 0x9d, 0xac, 0xeb, 0x93, 0xa4, 0xec, 0x9d, 0x98, 0x20, 0xea, 0xb2, 0x8c, 0xec, 0x9d, 0xb4, 0xec, 0xa7, 0x80, 0xec, 0x95, 0xbc, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xea, 0xb2, 0x8c, 0xec, 0x9d, 0xb4, 0xec, 0xa7, 0x80, 0x20, 0xec, 0x9c, 0x84, 0xec, 0x97, 0x90, 0x20, 0xeb, 0x9c, 0xa8, 0xeb, 0x8a, 0x94, 0x20, 0xeb, 0xa7, 0x89, 0xeb, 0x8c, 0x80, 0xea, 0xb8, 0xb0, 0xeb, 0x93, 0xa4, 0xec, 0x9d, 0x80, 0x0a, 0xeb, 0x84, 0x88, 0xed, 0x9d, 0xac, 0xeb, 0x93, 0xa4, 0xec, 0x9d, 0x98, 0x20, 0x48, 0x50, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xea, 0xb7, 0xb8, 0xeb, 0xa6, 0xac, 0xea, 0xb3, 0xa0, 0x20, 0xea, 0xb7, 0xb8, 0x20, 0xec, 0x9c, 0x84, 0xec, 0x97, 0x90, 0x20, 0xeb, 0xa6, 0xac, 0xeb, 0x93, 0xac, 0x20, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0xea, 0xb0, 0x80, 0x20, 0xeb, 0x96, 0xa0, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xec, 0xa0, 0x81, 0xec, 0x9d, 0x80, 0x20, 0xeb, 0xa6, 0xac, 0xeb, 0x93, 0xac, 0xec, 0x9c, 0xbc, 0xeb, 0xa1, 0x9c, 0x20, 0xea, 0xb3, 0xb5, 0xea, 0xb2, 0xa9, 0xec, 0x9d, 0x84, 0x20, 0xed, 0x95, 0x98, 0xec, 0xa7, 0x80, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xeb, 0x84, 0x88, 0xed, 0x9d, 0xac, 0xeb, 0x93, 0xa4, 0xec, 0x9d, 0x80, 0x20, 0xeb, 0xa6, 0xac, 0xeb, 0x93, 0xac, 0xec, 0x97, 0x90, 0x20, 0xeb, 0xa7, 0x9e, 0xec, 0xb6, 0xb0, 0x0a, 0xeb, 0xb0, 0xa9, 0xec, 0x96, 0xb4, 0xeb, 0xa5, 0xbc, 0x20, 0xed, 0x95, 0x98, 0xeb, 0xa9, 0xb4, 0x20, 0xeb, 0x8f, 0xbc, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xed, 0x9d, 0xa5, 0x2c, 0x20, 0xeb, 0x81, 0x9d, 0xea, 0xb9, 0x8c, 0xec, 0xa7, 0x80, 0x20, 0xeb, 0x93, 0xa3, 0xeb, 0x8f, 0x84, 0xeb, 0xa1, 0x9d, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xec, 0xa0, 0x81, 0xea, 0xb3, 0xbc, 0x20, 0xec, 0x83, 0x81, 0xeb, 0x8c, 0x80, 0xed, 0x95, 0xa0, 0x20, 0xeb, 0x95, 0x8c, 0x2c, 0x0a, 0xed, 0x95, 0x98, 0xec, 0x9d, 0xb4, 0xeb, 0x9d, 0xbc, 0xec, 0x9d, 0xb4, 0xed, 0x8a, 0xb8, 0x20, 0xea, 0xb5, 0xac, 0xea, 0xb0, 0x84, 0xec, 0x9d, 0xb4, 0x20, 0xec, 0x83, 0x9d, 0xea, 0xb8, 0xb8, 0x20, 0xea, 0xb1, 0xb0, 0xec, 0x95, 0xbc, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xea, 0xb7, 0xb8, 0x20, 0xeb, 0x95, 0x8c, 0xea, 0xb9, 0x8c, 0xec, 0xa7, 0x80, 0x20, 0xea, 0xb2, 0x8c, 0xec, 0x9d, 0xb4, 0xec, 0xa7, 0x80, 0xeb, 0xa5, 0xbc, 0x20, 0xea, 0xb0, 0x80, 0xeb, 0x93, 0x9d, 0x20, 0xec, 0xb1, 0x84, 0xec, 0x9a, 0xb0, 0xeb, 0xa9, 0xb4, 0x2c, 0x0a, 0xea, 0xb3, 0xb5, 0xea, 0xb2, 0xa9, 0xec, 0x9d, 0x84, 0x20, 0xed, 0x95, 0xa0, 0x20, 0xec, 0x88, 0x98, 0x20, 0xec, 0x9e, 0x88, 0xec, 0x96, 0xb4, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0xea, 0xb7, 0xb8, 0xeb, 0x9f, 0xbc, 0x20, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0xeb, 0xa5, 0xbc, 0x20, 0xec, 0x98, 0x88, 0xec, 0x8a, 0xb5, 0xed, 0x95, 0xb4, 0xeb, 0xb3, 0xb4, 0xec, 0x9e, 0x90, 0x2e]).get_string_from_utf8(),
	]


func _play_tutorial_music() -> void:
	tutorial_music_player = AudioStreamPlayer.new()
	tutorial_music_player.name = "TutorialMusic"
	add_child(tutorial_music_player)

	var stream := load(TUTORIAL_MUSIC_PATH)
	if stream is AudioStream:
		tutorial_music_player.stream = stream
	if tutorial_music_player.stream is AudioStreamWAV:
		var wav_stream := tutorial_music_player.stream as AudioStreamWAV
		wav_stream.loop_begin = 0
		wav_stream.loop_end = int(wav_stream.get_length() * wav_stream.mix_rate)
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	tutorial_music_player.bus = &"Music"
	tutorial_music_player.volume_db = 0.0
	tutorial_music_player.stream_paused = false
	await get_tree().process_frame
	tutorial_music_player.play()


func _setup_typing_sound_player() -> void:
	typing_sound_player = AudioStreamPlayer.new()
	typing_sound_player.name = "TypingSoundPlayer"
	typing_sound_player.bus = &"SFX"
	add_child(typing_sound_player)
	if typing_sound:
		typing_sound_player.stream = typing_sound


func _setup_side_typing_sound_players() -> void:
	typing_sound_player_p1 = AudioStreamPlayer.new()
	typing_sound_player_p1.name = "TypingSoundPlayerP1"
	typing_sound_player_p1.bus = &"SFX"
	add_child(typing_sound_player_p1)
	if typing_sound_p1:
		typing_sound_player_p1.stream = typing_sound_p1

	typing_sound_player_p2 = AudioStreamPlayer.new()
	typing_sound_player_p2.name = "TypingSoundPlayerP2"
	typing_sound_player_p2.bus = &"SFX"
	add_child(typing_sound_player_p2)
	if typing_sound_p2:
		typing_sound_player_p2.stream = typing_sound_p2


func _setup_note_sound_players() -> void:
	perfect_stream_p1 = load(PERFECT_SOUND_P1_PATH)
	perfect_stream_p2 = load(PERFECT_SOUND_P2_PATH)
	longnote_stream_p1 = load(LONGNOTE_SOUND_P1_PATH)
	longnote_stream_p2 = load(LONGNOTE_SOUND_P2_PATH)
	flick_stream_p1 = load(FLICK_SOUND_P1_PATH)
	flick_stream_p2 = load(FLICK_SOUND_P2_PATH)
	_configure_wav_loop(longnote_stream_p1)
	_configure_wav_loop(longnote_stream_p2)
	longnote_player_p1 = _make_longnote_player("TutorialLongnoteP1", longnote_stream_p1)
	longnote_player_p2 = _make_longnote_player("TutorialLongnoteP2", longnote_stream_p2)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "TutorialNoteSound%d" % i
		player.bus = &"SFX"
		add_child(player)
		note_sound_players.append(player)


func _make_longnote_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = &"SFX"
	player.stream = stream
	add_child(player)
	return player


func _configure_wav_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav_stream := stream as AudioStreamWAV
		wav_stream.loop_begin = 0
		wav_stream.loop_end = int(wav_stream.get_length() * wav_stream.mix_rate)
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD


func _build_inverted_note_textures() -> void:
	note_inverted_textures.clear()
	for texture in NOTE_TEXTURES:
		note_inverted_textures.append(_make_inverted_texture(texture))


# Hold and flick notes share the chart styling used in Main.gd.
func _build_chart_note_textures() -> void:
	chart_note_textures.clear()
	for lane in range(NOTE_TEXTURES.size()):
		var source_texture: Texture2D = NOTE_TEXTURES[lane]
		var image := source_texture.get_image()
		if image == null:
			chart_note_textures.append(source_texture)
			continue
		image.convert(Image.FORMAT_RGBA8)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var source_color := image.get_pixel(x, y)
				if source_color.a <= 0.0:
					continue
				var border_amount: float = max(source_color.r, max(source_color.g, source_color.b))
				var mapped_color: Color = Color.WHITE.lerp(LANE_COLORS[lane], border_amount)
				mapped_color.a = source_color.a
				image.set_pixel(x, y, mapped_color)
		chart_note_textures.append(ImageTexture.create_from_image(image))


func _build_note_outline_textures() -> void:
	note_outline_textures.clear()
	for source_texture_value in NOTE_TEXTURES:
		var source_texture: Texture2D = source_texture_value
		var source_image: Image = source_texture.get_image()
		if source_image == null:
			note_outline_textures.append(source_texture)
			continue
		source_image.convert(Image.FORMAT_RGBA8)
		var image_size := Vector2i(source_image.get_width(), source_image.get_height())
		var image_rect := Rect2i(Vector2i.ZERO, image_size)
		var white_image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
		white_image.fill(Color.WHITE)
		var outline_image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
		outline_image.fill(Color.TRANSPARENT)
		for offset_y in range(-NOTE_OUTLINE_RADIUS, NOTE_OUTLINE_RADIUS + 1):
			for offset_x in range(-NOTE_OUTLINE_RADIUS, NOTE_OUTLINE_RADIUS + 1):
				if offset_x * offset_x + offset_y * offset_y > NOTE_OUTLINE_RADIUS * NOTE_OUTLINE_RADIUS:
					continue
				outline_image.blit_rect_mask(white_image, source_image, image_rect, Vector2i(offset_x, offset_y))
		note_outline_textures.append(ImageTexture.create_from_image(outline_image))


func _make_inverted_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1.0 - color.r, 1.0 - color.g, 1.0 - color.b, color.a))
	return ImageTexture.create_from_image(image)


# Called once per newly revealed raw character, in order. Skips whitespace and
# BBCode tag contents so the blip only plays for characters that actually
# appear on screen, and only every Nth visible character per typing_sound_char_interval.
func _handle_typing_sound_for_char(ch: String) -> void:
	if ch == "[":
		typing_sound_in_bbcode_tag = true
		return
	if typing_sound_in_bbcode_tag:
		if ch == "]":
			typing_sound_in_bbcode_tag = false
		return
	if ch == "" or ch == " " or ch == "\n" or ch == "\t" or ch == "\r":
		return

	typing_sound_visible_char_count += 1
	var interval: int = max(1, typing_sound_char_interval)
	if typing_sound_visible_char_count % interval == 0:
		_play_typing_blip()


func _play_typing_blip() -> void:
	# Cat bubble keeps using the original sound/player untouched; P1/P2 side
	# dialogue bubbles get their own voice-flavored blip and player.
	var player := typing_sound_player
	var stream := typing_sound
	if active_bubble == p1_bubble:
		player = typing_sound_player_p1
		stream = typing_sound_p1
	elif active_bubble == p2_bubble:
		player = typing_sound_player_p2
		stream = typing_sound_p2

	if stream == null or player == null:
		return
	player.volume_db = typing_sound_volume_db
	player.pitch_scale = randf_range(TYPING_SOUND_PITCH_MIN, TYPING_SOUND_PITCH_MAX)
	player.play(0.0)


func _build_bubbles() -> void:
	cat_bubble = _make_bubble(Vector2(420.0, 120.0), Vector2(440.0, 118.0), 25)
	cat_bubble.set_tail("bottom", 0.5)
	add_child(cat_bubble)

	p1_bubble = _make_bubble(Vector2(330.0, 370.0), Vector2(250.0, 76.0), 25)
	p1_bubble.set_tail("left", 0.58)
	p1_bubble.visible = false
	add_child(p1_bubble)

	p2_bubble = _make_bubble(Vector2(700.0, 365.0), Vector2(285.0, 76.0), 25)
	p2_bubble.set_tail("right", 0.58)
	p2_bubble.visible = false
	add_child(p2_bubble)

	yes_bubble = _make_bubble(Vector2(390.0, 398.0), Vector2(150.0, 68.0), 27)
	yes_bubble.set_tail("left", 0.55)
	yes_bubble.set_text(PackedByteArray([0xec, 0x9d, 0x91, 0x21]).get_string_from_utf8())
	yes_bubble.visible = false
	add_child(yes_bubble)

	no_bubble = _make_bubble(Vector2(740.0, 398.0), Vector2(160.0, 68.0), 27)
	no_bubble.set_tail("right", 0.55)
	no_bubble.set_text(PackedByteArray([0xec, 0x95, 0x84, 0xeb, 0x8b, 0x88, 0x2e]).get_string_from_utf8())
	no_bubble.visible = false
	add_child(no_bubble)


func _build_status_bars() -> void:
	boss_hp_bar = _make_status_bar(Vector2(40.0, 28.0), Vector2(1200.0, 44.0), 23)
	boss_hp_bar.set_stats(200.0, 200.0, "HP 200/200")
	boss_hp_bar.visible = false
	add_child(boss_hp_bar)

	gauge_bar = _make_status_bar(Vector2(35.0, 652.0), Vector2(1210.0, 54.0), 22)
	gauge_bar.set_stats(0.0, 100.0, PackedByteArray([0xea, 0xb2, 0x8c, 0xec, 0x9d, 0xb4, 0xec, 0xa7, 0x80, 0x20, 0x30, 0x2f, 0x31, 0x30, 0x30]).get_string_from_utf8())
	gauge_bar.set_outer_black_border(5.0)
	gauge_bar.visible = false
	add_child(gauge_bar)

	p1_hp_bar = _make_status_bar(Vector2(35.0, 594.0), Vector2(500.0, 54.0), 22)
	p1_hp_bar.set_stats(50.0, 50.0, "HP 50/50")
	p1_hp_bar.set_outer_black_border(5.0)
	p1_hp_bar.visible = false
	add_child(p1_hp_bar)

	p2_hp_bar = _make_status_bar(Vector2(745.0, 594.0), Vector2(500.0, 54.0), 22)
	p2_hp_bar.set_stats(50.0, 50.0, "HP 50/50")
	p2_hp_bar.set_outer_black_border(5.0)
	p2_hp_bar.visible = false
	add_child(p2_hp_bar)


func _build_practice_layer() -> void:
	practice_layer = PracticeNoteLayer.new()
	practice_layer.name = "PracticeNoteLayer"
	practice_layer.z_index = 10
	practice_layer.setup(self)
	add_child(practice_layer)


func _build_note_arrows() -> void:
	var arrow_box_size := Vector2(72.0, 72.0)
	var y := 512.0
	var spacing := 66.0
	var p1_start_x := 44.0
	var p2_start_x := 1173.0

	for lane in range(4):
		var p1_arrow := _make_note_arrow(0, lane, Vector2(p1_start_x + spacing * lane, y), arrow_box_size)
		p1_arrow.name = "TutorialNoteArrowP1_%d" % lane
		p1_arrow.z_index = 20
		add_child(p1_arrow)
		note_arrows.append(p1_arrow)

	for lane in range(4):
		var p2_arrow := _make_note_arrow(1, lane, Vector2(p2_start_x - spacing * lane, y), arrow_box_size)
		p2_arrow.name = "TutorialNoteArrowP2_%d" % lane
		p2_arrow.z_index = 20
		add_child(p2_arrow)
		note_arrows.append(p2_arrow)

	_hide_note_arrows()


func _make_bubble(pos: Vector2, bubble_size: Vector2, font_size: int) -> DottedBubble:
	var bubble := DottedBubble.new()
	bubble.position = pos
	bubble.size = bubble_size
	bubble.z_index = 40
	bubble.setup(MENU_FONT, font_size)
	bubble.set_colors(Color.BLACK, Color.WHITE, Color.WHITE)
	return bubble


func _make_status_bar(pos: Vector2, bar_size: Vector2, font_size: int) -> StatusBar:
	var status_bar := StatusBar.new()
	status_bar.position = pos
	status_bar.size = bar_size
	status_bar.z_index = 30
	status_bar.setup(MENU_FONT, font_size)
	return status_bar


func _make_note_arrow(side: int, lane: int, pos: Vector2, arrow_box_size: Vector2) -> RhythmArrow:
	var arrow := RhythmArrow.new()
	arrow.position = pos
	arrow.size = arrow_box_size
	arrow.setup(side, lane, NOTE_TEXTURES[lane])
	arrow.arrow_pressed.connect(_on_note_arrow_pressed)
	arrow.arrow_released.connect(_on_note_arrow_released)
	return arrow


func _build_mode_select_overlay() -> void:
	mode_dim_rect = ColorRect.new()
	mode_dim_rect.name = "ModeSelectOverlay"
	mode_dim_rect.color = Color(0.0, 0.0, 0.0, 0.48)
	mode_dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_dim_rect.z_index = 100
	mode_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mode_dim_rect)

	mode_prompt_label = Label.new()
	mode_prompt_label.position = Vector2(0.0, 228.0)
	mode_prompt_label.size = Vector2(1280.0, 58.0)
	mode_prompt_label.add_theme_font_override("font", MENU_FONT)
	mode_prompt_label.add_theme_font_size_override("font_size", 31)
	mode_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	mode_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_dim_rect.add_child(mode_prompt_label)

	var single_button := _make_menu_choice_box(Vector2(245.0, 330.0), Vector2(335.0, 108.0), PackedByteArray([0xec, 0x8b, 0xb1, 0xea, 0xb8, 0x80, 0x20, 0xed, 0x94, 0x8c, 0xeb, 0xa0, 0x88, 0xec, 0x9d, 0xb4, 0xec, 0x96, 0xb4]).get_string_from_utf8())
	var multi_button := _make_menu_choice_box(Vector2(700.0, 330.0), Vector2(335.0, 108.0), PackedByteArray([0xeb, 0xa9, 0x80, 0xed, 0x8b, 0xb0, 0x20, 0xed, 0x94, 0x8c, 0xeb, 0xa0, 0x88, 0xec, 0x9d, 0xb4, 0xec, 0x96, 0xb4]).get_string_from_utf8())
	mode_buttons = [single_button, multi_button]
	mode_dim_rect.add_child(single_button)
	mode_dim_rect.add_child(multi_button)

	var gg_button := _make_menu_choice_box(Vector2(245.0, 330.0), Vector2(335.0, 108.0), "GG")
	var ez_button := _make_menu_choice_box(Vector2(700.0, 330.0), Vector2(335.0, 108.0), "EZ")
	player_buttons = [gg_button, ez_button]
	mode_dim_rect.add_child(gg_button)
	mode_dim_rect.add_child(ez_button)

	mode_dim_rect.visible = false


func _make_menu_choice_box(pos: Vector2, box_size: Vector2, text_value: String) -> MenuChoiceBox:
	var box := MenuChoiceBox.new()
	box.position = pos
	box.size = box_size
	box.setup(MENU_FONT, 40, text_value)
	box.visible = false
	return box


func _show_mode_select_screen(screen: int) -> void:
	mode_select_active = true
	mode_confirming = false
	mode_select_screen = screen
	mode_selected_index = 0
	mode_blink_timer = 0.0
	mode_blink_on = true
	mode_dim_rect.visible = true
	if not mode_select_only:
		cat_bubble.visible = false
		_hide_player_bubbles()
		yes_bubble.visible = false
		no_bubble.visible = false

	for button in mode_buttons:
		button.visible = screen == MODE_SCREEN_PLAY_STYLE
	for button in player_buttons:
		button.visible = screen == MODE_SCREEN_PLAYER

	if screen == MODE_SCREEN_PLAY_STYLE:
		mode_prompt_label.text = PackedByteArray([0xec, 0x96, 0xb4, 0xeb, 0x96, 0xa4, 0x20, 0xeb, 0xaa, 0xa8, 0xeb, 0x93, 0x9c, 0xeb, 0xa1, 0x9c, 0x20, 0xed, 0x94, 0x8c, 0xeb, 0xa0, 0x88, 0xec, 0x9d, 0xb4, 0xed, 0x95, 0x98, 0xec, 0x8b, 0x9c, 0xea, 0xb2, 0xa0, 0xec, 0x8a, 0xb5, 0xeb, 0x8b, 0x88, 0xea, 0xb9, 0x8c, 0x3f]).get_string_from_utf8()
	else:
		mode_prompt_label.text = PackedByteArray([0xeb, 0x88, 0x84, 0xea, 0xb5, 0xac, 0xeb, 0xa1, 0x9c, 0x20, 0xed, 0x94, 0x8c, 0xeb, 0xa0, 0x88, 0xec, 0x9d, 0xb4, 0x20, 0xed, 0x95, 0x98, 0xec, 0x8b, 0x9c, 0xea, 0xb2, 0xa0, 0xec, 0x8a, 0xb5, 0xeb, 0x8b, 0x88, 0xea, 0xb9, 0x8c, 0x3f]).get_string_from_utf8()
	_update_mode_select_styles()


func _current_mode_buttons() -> Array:
	return mode_buttons if mode_select_screen == MODE_SCREEN_PLAY_STYLE else player_buttons


func _update_mode_select_blink(delta: float) -> void:
	if mode_confirming:
		return
	mode_blink_timer += delta
	if mode_blink_timer >= BLINK_INTERVAL:
		mode_blink_timer = 0.0
		mode_blink_on = not mode_blink_on
		_update_mode_select_styles()


func _update_mode_select_styles() -> void:
	var buttons := _current_mode_buttons()
	for i in range(buttons.size()):
		buttons[i].set_selected(i == mode_selected_index, mode_blink_on)


func _handle_mode_select_input(event: InputEvent) -> void:
	if mode_confirming:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var buttons := _current_mode_buttons()
			for i in range(buttons.size()):
				var button: MenuChoiceBox = buttons[i]
				var global_rect := Rect2(button.global_position, button.size)
				if global_rect.has_point(mouse_event.position):
					mode_selected_index = i
					mode_blink_on = true
					_update_mode_select_styles()
					_confirm_mode_selection()
					get_viewport().set_input_as_handled()
					return
		return

	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_ESCAPE:
			if mode_select_only:
				mode_selection_finished.emit(true)
				queue_free()
			else:
				get_tree().change_scene_to_file("res://StartMenu.tscn")
			get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_RIGHT:
			mode_selected_index = 1 - mode_selected_index
			mode_blink_timer = 0.0
			mode_blink_on = true
			_update_mode_select_styles()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			get_viewport().set_input_as_handled()
			_confirm_mode_selection()


func _confirm_mode_selection() -> void:
	if mode_confirming:
		return
	mode_confirming = true
	var chosen_button: MenuChoiceBox = _current_mode_buttons()[mode_selected_index]
	for i in range(CONFIRM_BLINK_COUNT):
		chosen_button.set_selected(true, i % 2 == 0)
		await get_tree().create_timer(CONFIRM_BLINK_INTERVAL).timeout

	mode_confirming = false
	if mode_select_screen == MODE_SCREEN_PLAY_STYLE and mode_selected_index == MODE_CHOICE_SINGLE:
		_show_mode_select_screen(MODE_SCREEN_PLAYER)
	elif mode_select_screen == MODE_SCREEN_PLAY_STYLE and mode_selected_index == MODE_CHOICE_MULTI:
		tutorial_multiplayer = true
		tutorial_human_side = -1
		GameSettings.set_play_mode(true)
		_finish_mode_select()
	else:
		tutorial_multiplayer = false
		tutorial_human_side = mode_selected_index
		GameSettings.set_play_mode(false, tutorial_human_side)
		_finish_mode_select()


func _finish_mode_select() -> void:
	mode_select_active = false
	mode_confirming = false
	mode_dim_rect.visible = false
	if mode_select_only:
		mode_selection_finished.emit(false)
		queue_free()
		return
	_start_dialogue(0)


func _begin_note_lesson() -> void:
	_start_lesson_dialogue([
		PackedByteArray([0xec, 0x9a, 0xb0, 0xec, 0x84, 0xa0, 0xec, 0x9d, 0x80, 0x20, 0xe2, 0x9e, 0x80, 0xea, 0xb8, 0xb0, 0xeb, 0xb3, 0xb8, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0xec, 0x95, 0xbc, 0x2e]).get_string_from_utf8(),
		PackedByteArray([0x47, 0x47, 0xeb, 0x8a, 0x94, 0x20, 0x41, 0x2c, 0x20, 0x53, 0x2c, 0x20, 0x44, 0x2c, 0x20, 0x46, 0xeb, 0xa1, 0x9c, 0x20, 0xec, 0xb9, 0x98, 0xea, 0xb3, 0xa0, 0x2c, 0x0a, 0x45, 0x5a, 0xeb, 0x8a, 0x94, 0x20, 0x4b, 0x2c, 0x20, 0x4c, 0x2c, 0x20, 0x3b, 0x2c, 0x20, 0x27, 0xeb, 0xa1, 0x9c, 0x20, 0xec, 0xb9, 0x98, 0xeb, 0xa9, 0xb4, 0x20, 0xeb, 0x8f, 0xbc, 0x2e, 0x20, 0xed, 0x95, 0xb4, 0xeb, 0xb4, 0x90, 0x21]).get_string_from_utf8(),
	], PRACTICE_TAP, [true, true])


func _start_lesson_dialogue(lines: Array[String], pending_type: int, pending_sides: Array) -> void:
	lesson_dialogue_active = true
	lesson_pending_practice_type = pending_type
	lesson_pending_sides = [bool(pending_sides[0]), bool(pending_sides[1])]
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_mode = DIALOGUE_MODE_BASIC
	_start_dialogue(0)


func _start_pending_practice_after_delay() -> void:
	await get_tree().create_timer(0.35).timeout
	if lesson_pending_practice_type != PRACTICE_NONE:
		_begin_practice_round(lesson_pending_practice_type, lesson_pending_sides)


func _start_dialogue(index: int) -> void:
	dialogue_index = index
	side_dialogue_step = SIDE_DIALOGUE_NONE
	side_dialogue_context = SIDE_CONTEXT_NONE
	pending_side_dialogue_context = SIDE_CONTEXT_NONE
	_update_cat_sprite_for_dialogue()
	cat_bubble.visible = true
	_hide_player_bubbles()
	_start_typed_bubble(cat_bubble, dialogue_lines[dialogue_index])
	if not lesson_dialogue_active:
		_apply_basic_tutorial_step()


func _start_typed_bubble(bubble: DottedBubble, text_value: String) -> void:
	active_bubble = bubble
	active_line = text_value
	typed_chars = 0
	type_timer = 0.0
	typing = true
	next_marker_enabled = false
	typing_sound_visible_char_count = 0
	typing_sound_in_bbcode_tag = false
	active_bubble.visible = true
	active_bubble.set_text("")
	active_bubble.set_next_marker(next_marker_text, false)
	next_marker_blink_timer = 0.0
	next_marker_on = true


func _update_cat_sprite_for_dialogue() -> void:
	if not cat_sprite:
		return

	if dialogue_mode == DIALOGUE_MODE_BASIC and not lesson_dialogue_active and dialogue_index == 7:
		cat_sprite.texture = CAT2_TEXTURE
	else:
		cat_sprite.texture = CAT_TEXTURE


func _advance_dialogue() -> void:
	if typing:
		typed_chars = active_line.length()
		active_bubble.set_text(active_line)
		typing = false
		_on_dialogue_line_complete()
		return

	if return_to_start_after_line:
		return

	if pending_side_dialogue_context != SIDE_CONTEXT_NONE:
		var context := pending_side_dialogue_context
		pending_side_dialogue_context = SIDE_CONTEXT_NONE
		_start_side_dialogue(context, SIDE_DIALOGUE_P1)
		return

	if side_dialogue_step == SIDE_DIALOGUE_P1:
		_start_side_dialogue(side_dialogue_context, SIDE_DIALOGUE_P2)
		return
	if side_dialogue_step == SIDE_DIALOGUE_P2:
		side_dialogue_step = SIDE_DIALOGUE_NONE
		side_dialogue_context = SIDE_CONTEXT_NONE
		_hide_player_bubbles()
		_start_dialogue(dialogue_index + 1)
		return

	if dialogue_index < dialogue_lines.size() - 1:
		_start_dialogue(dialogue_index + 1)
	elif dialogue_mode == DIALOGUE_MODE_INTRO:
		_open_choices()
	elif dialogue_mode == DIALOGUE_MODE_BASIC and not lesson_dialogue_active:
		_begin_note_lesson()


func _on_dialogue_line_complete() -> void:
	if return_to_start_after_line:
		active_bubble.set_next_marker_visible(false)
		call_deferred("_return_to_start_after_delay")
		return

	if side_dialogue_step == SIDE_DIALOGUE_P1:
		active_bubble.set_next_marker_visible(false)
		call_deferred("_continue_side_dialogue_after_delay")
		return

	if side_dialogue_step == SIDE_DIALOGUE_P2:
		active_bubble.set_next_marker(next_marker_text, true)
		next_marker_enabled = true
		next_marker_blink_timer = 0.0
		next_marker_on = true
		return

	if lesson_dialogue_active and lesson_pending_practice_type != PRACTICE_NONE and dialogue_index == dialogue_lines.size() - 1:
		next_marker_enabled = false
		active_bubble.set_next_marker_visible(false)
		call_deferred("_start_pending_practice_after_delay")
		return

	var side_context := _side_context_after_current_cat_line()
	if side_context != SIDE_CONTEXT_NONE:
		pending_side_dialogue_context = side_context
		active_bubble.set_next_marker_visible(false)
		call_deferred("_start_side_dialogue_after_delay", side_context)
		return

	active_bubble.set_next_marker(next_marker_text, true)
	next_marker_enabled = true
	next_marker_blink_timer = 0.0
	next_marker_on = true
	if dialogue_mode == DIALOGUE_MODE_INTRO and dialogue_index == dialogue_lines.size() - 1:
		_open_choices()


func _side_context_after_current_cat_line() -> int:
	if lesson_dialogue_active or dialogue_mode != DIALOGUE_MODE_BASIC or side_dialogue_step != SIDE_DIALOGUE_NONE or pending_side_dialogue_context != SIDE_CONTEXT_NONE:
		return SIDE_CONTEXT_NONE
	if dialogue_index == 2:
		return SIDE_CONTEXT_GAUGE
	if dialogue_index == 6:
		return SIDE_CONTEXT_ATTACK
	return SIDE_CONTEXT_NONE


func _start_side_dialogue_after_delay(context: int) -> void:
	await get_tree().create_timer(SIDE_DIALOGUE_START_DELAY).timeout
	if not typing and side_dialogue_step == SIDE_DIALOGUE_NONE and pending_side_dialogue_context == context and dialogue_mode == DIALOGUE_MODE_BASIC:
		pending_side_dialogue_context = SIDE_CONTEXT_NONE
		_start_side_dialogue(context, SIDE_DIALOGUE_P1)


func _continue_side_dialogue_after_delay() -> void:
	await get_tree().create_timer(SIDE_DIALOGUE_NEXT_DELAY).timeout
	if not typing and side_dialogue_step == SIDE_DIALOGUE_P1:
		_start_side_dialogue(side_dialogue_context, SIDE_DIALOGUE_P2)


func _start_side_dialogue(context: int, step: int) -> void:
	side_dialogue_context = context
	side_dialogue_step = step
	cat_bubble.set_next_marker_visible(false)
	if step == SIDE_DIALOGUE_P1:
		_hide_player_bubbles()

	if context == SIDE_CONTEXT_GAUGE and step == SIDE_DIALOGUE_P1:
		_configure_player_bubble(p1_bubble, Vector2(360.0, 370.0), Vector2(170.0, 76.0))
		_start_typed_bubble(p1_bubble, PackedByteArray([0xea, 0xb2, 0x8c, 0xec, 0x9d, 0xb4, 0xec, 0xa7, 0x80, 0x3f]).get_string_from_utf8())
	elif context == SIDE_CONTEXT_GAUGE and step == SIDE_DIALOGUE_P2:
		_configure_player_bubble(p2_bubble, Vector2(795.0, 365.0), Vector2(120.0, 76.0))
		_start_typed_bubble(p2_bubble, PackedByteArray([0xed, 0x9d, 0xa0, 0x2e]).get_string_from_utf8())
	elif context == SIDE_CONTEXT_ATTACK and step == SIDE_DIALOGUE_P1:
		_configure_player_bubble(p1_bubble, Vector2(345.0, 370.0), Vector2(190.0, 76.0))
		_start_typed_bubble(p1_bubble, PackedByteArray([0xec, 0x9e, 0xac, 0xeb, 0xb0, 0x8c, 0xea, 0xb2, 0xa0, 0xeb, 0x8b, 0xa4, 0x21]).get_string_from_utf8())
	elif context == SIDE_CONTEXT_ATTACK and step == SIDE_DIALOGUE_P2:
		_configure_player_bubble(p2_bubble, Vector2(735.0, 365.0), Vector2(235.0, 76.0))
		_start_typed_bubble(p2_bubble, PackedByteArray([0xea, 0xb3, 0xb5, 0xea, 0xb2, 0xa9, 0xec, 0x9d, 0x80, 0x20, 0xec, 0x96, 0xb8, 0xec, 0xa0, 0x9c, 0x20, 0xed, 0x95, 0xb4, 0x3f]).get_string_from_utf8())


func _configure_player_bubble(bubble: DottedBubble, pos: Vector2, bubble_size: Vector2) -> void:
	if not bubble:
		return
	bubble.position = pos
	bubble.size = bubble_size
	bubble.queue_redraw()


func _hide_player_bubbles() -> void:
	if p1_bubble:
		p1_bubble.visible = false
		p1_bubble.set_next_marker_visible(false)
	if p2_bubble:
		p2_bubble.visible = false
		p2_bubble.set_next_marker_visible(false)


func _open_choices() -> void:
	if choices_open:
		return
	choices_open = true
	selected_choice = CHOICE_YES
	blink_timer = 0.0
	blink_on = true
	yes_bubble.visible = true
	no_bubble.visible = true
	_update_choice_styles()


func _update_choice_styles() -> void:
	_apply_choice_style(yes_bubble, selected_choice == CHOICE_YES and blink_on)
	_apply_choice_style(no_bubble, selected_choice == CHOICE_NO and blink_on)


func _apply_choice_style(bubble: DottedBubble, selected: bool) -> void:
	if selected:
		bubble.set_colors(Color.WHITE, Color.BLACK, Color.BLACK)
	else:
		bubble.set_colors(Color.BLACK, Color.WHITE, Color.WHITE)


func confirm_choice() -> void:
	confirming = true
	var chosen_bubble := yes_bubble if selected_choice == CHOICE_YES else no_bubble
	for i in range(CONFIRM_BLINK_COUNT):
		_apply_choice_style(chosen_bubble, i % 2 == 0)
		await get_tree().create_timer(CONFIRM_BLINK_INTERVAL).timeout

	choices_open = false
	yes_bubble.visible = false
	no_bubble.visible = false
	confirming = false
	if selected_choice == CHOICE_YES:
		_begin_basic_tutorial()
	else:
		_begin_practice_game()


func _begin_basic_tutorial() -> void:
	return_to_start_after_line = false
	dialogue_mode = DIALOGUE_MODE_BASIC
	dialogue_lines = basic_dialogue_lines
	_hide_status_bars()
	_start_dialogue(0)
	print("Tutorial: basic tutorial selected")


func _begin_practice_game() -> void:
	return_to_start_after_line = true
	_hide_status_bars()
	_hide_player_bubbles()
	if cat_sprite:
		cat_sprite.texture = CAT2_TEXTURE
	cat_bubble.visible = true
	_start_typed_bubble(cat_bubble, PackedByteArray([0xea, 0xb7, 0xb8, 0xeb, 0x9f, 0xbc, 0x20, 0xea, 0xba, 0xbc, 0xec, 0xa0, 0xb8, 0x21]).get_string_from_utf8())
	print("Tutorial: no selected, returning to start")


func _return_to_start_after_delay() -> void:
	await get_tree().create_timer(0.45).timeout
	if return_to_start_after_line:
		get_tree().change_scene_to_file("res://StartMenu.tscn")


func _hide_status_bars() -> void:
	if boss_hp_bar:
		boss_hp_bar.visible = false
	if gauge_bar:
		gauge_bar.visible = false
	if p1_hp_bar:
		p1_hp_bar.visible = false
	if p2_hp_bar:
		p2_hp_bar.visible = false
	_hide_note_arrows()


func _hide_note_arrows() -> void:
	for arrow in note_arrows:
		if arrow:
			arrow.visible = false


func _show_note_arrows() -> void:
	for arrow in note_arrows:
		if arrow:
			arrow.visible = true


func _draw() -> void:
	pass


func _draw_practice_layer(canvas: CanvasItem) -> void:
	if practice_notes.is_empty():
		return
	_draw_practice_slur_connections(canvas)
	for note in practice_notes:
		_draw_practice_note(canvas, note)


func _on_note_arrow_pressed(side: int, lane: int) -> void:
	if practice_active:
		if practice_pointer_active:
			return
		practice_held[side][lane] = true
		_handle_practice_press(side, lane)
	else:
		_play_note_hit_sound(side)


func _on_note_arrow_released(side: int, lane: int) -> void:
	if not practice_active:
		return
	if practice_pointer_active:
		return
	practice_held[side][lane] = false
	_handle_practice_release(side, lane)


func _begin_practice_pointer(position: Vector2) -> void:
	var side_lane := _side_lane_at_position(position)
	if side_lane.is_empty():
		return
	var side := int(side_lane[0])
	var lane := int(side_lane[1])
	practice_pointer_active = true
	practice_pointer_side = side
	practice_pointer_position = position
	practice_held[side][lane] = true
	_handle_practice_press(side, lane)


func _update_practice_pointer(position: Vector2) -> void:
	if not practice_pointer_active:
		return
	practice_pointer_position = position
	var side_lane := _side_lane_at_position(position)
	if side_lane.is_empty():
		return
	var side := int(side_lane[0])
	var lane := int(side_lane[1])
	if practice_pointer_side != -1 and side != practice_pointer_side:
		return
	if bool(practice_held[side][lane]):
		return
	_handle_practice_press(side, lane)


func _end_practice_pointer() -> void:
	if not practice_pointer_active:
		return
	var side := practice_pointer_side
	practice_pointer_active = false
	practice_pointer_side = -1
	practice_pointer_position = Vector2.ZERO
	if side < 0 or side > 1:
		return
	for lane in range(4):
		if bool(practice_held[side][lane]):
			practice_held[side][lane] = false
			_handle_practice_release(side, lane)


func _side_lane_at_position(position: Vector2) -> Array:
	for arrow in note_arrows:
		if arrow == null or not arrow.visible:
			continue
		var arrow_rect := Rect2(arrow.global_position, arrow.size * arrow.scale)
		if arrow_rect.has_point(position):
			return [arrow.side, arrow.lane]
	return []


func _begin_practice_round(new_type: int, sides: Array) -> void:
	lesson_pending_practice_type = PRACTICE_NONE
	next_marker_enabled = false
	practice_active = true
	practice_type = new_type
	practice_time = 0.0
	practice_notes.clear()
	practice_sides = [bool(sides[0]), bool(sides[1])]
	practice_misses = [0, 0]
	practice_held = [[false, false, false, false], [false, false, false, false]]
	practice_active_slur_chain = [-1, -1]
	practice_active_slur_next_index = [0, 0]
	practice_active_slur_held_lanes = [[], []]
	practice_flick_sustain_end_times = [[], []]
	practice_pointer_active = false
	practice_pointer_side = -1
	practice_pointer_position = Vector2.ZERO
	_show_note_arrows()
	_build_practice_notes(new_type, practice_sides)
	_queue_practice_redraw()


func _build_practice_notes(new_type: int, sides: Array) -> void:
	match new_type:
		PRACTICE_TAP:
			if sides[0]:
				_add_tap_notes(0, [[1.05, 0], [1.46, 1], [1.90, 2], [2.34, 3], [2.78, 1], [3.22, 0], [3.66, 2]])
			if sides[1]:
				_add_tap_notes(1, [[1.18, 3], [1.58, 2], [2.02, 0], [2.46, 1], [2.90, 3], [3.34, 0], [3.78, 2]])
		PRACTICE_HOLD:
			if sides[0]:
				_add_hold_notes(0, [[1.05, 0, 0.70], [2.05, 2, 0.80], [3.20, 1, 0.62], [4.04, 3, 0.74]])
			if sides[1]:
				_add_hold_notes(1, [[1.22, 3, 0.66], [2.12, 1, 0.78], [3.10, 0, 0.70], [4.02, 2, 0.82]])
		PRACTICE_SLUR:
			var chain_id := 0
			if sides[0]:
				_add_slur_chain(0, [0, 3, 1], 1.05, 0.42, chain_id)
				chain_id += 1
				_add_slur_chain(0, [2, 1], 2.65, 0.42, chain_id)
				chain_id += 1
				_add_slur_chain(0, [3, 2, 0, 1], 3.75, 0.38, chain_id)
				chain_id += 1
			if sides[1]:
				_add_slur_chain(1, [3, 0, 2], 1.20, 0.40, chain_id)
				chain_id += 1
				_add_slur_chain(1, [1, 2], 2.74, 0.42, chain_id)
				chain_id += 1
				_add_slur_chain(1, [0, 1, 3, 2], 3.86, 0.38, chain_id)
		PRACTICE_RAPID:
			if sides[0]:
				practice_notes.append(_make_practice_note(0, -1, PRACTICE_RAPID, 1.35, PRACTICE_RAPID_DURATION))
			if sides[1]:
				practice_notes.append(_make_practice_note(1, -1, PRACTICE_RAPID, 1.50, PRACTICE_RAPID_DURATION))


func _add_tap_notes(side: int, data: Array) -> void:
	for item in data:
		practice_notes.append(_make_practice_note(side, int(item[1]), PRACTICE_TAP, float(item[0]), 0.0))


func _add_hold_notes(side: int, data: Array) -> void:
	for item in data:
		practice_notes.append(_make_practice_note(side, int(item[1]), PRACTICE_HOLD, float(item[0]), float(item[2])))


func _add_slur_chain(side: int, lanes: Array, start_time: float, interval: float, chain_id: int) -> void:
	for i in range(lanes.size()):
		practice_notes.append(_make_practice_note(side, int(lanes[i]), PRACTICE_SLUR, start_time + interval * float(i), 0.0, chain_id, i, lanes.size()))


func _make_practice_note(side: int, lane: int, note_type: int, hit_time: float, duration: float, chain_id: int = -1, chain_index: int = 0, chain_count: int = 1) -> Dictionary:
	return {
		"side": side,
		"lane": lane,
		"type": note_type,
		"hit_time": hit_time,
		"duration": duration,
		"chain_id": chain_id,
		"chain_index": chain_index,
		"chain_count": chain_count,
		"connect_next": chain_index < chain_count - 1,
		"state": "pending",
		"feedback": 0.0,
		"remaining": PRACTICE_RAPID_TAPS,
	}


func _update_practice(delta: float) -> void:
	practice_time += delta
	for note in practice_notes:
		note["feedback"] = max(0.0, float(note["feedback"]) - delta * 8.0)
	if practice_pointer_active:
		_update_practice_pointer(practice_pointer_position)
	_update_practice_ai()
	_resolve_practice_notes()
	_refresh_practice_longnote_loop()
	_queue_practice_redraw()
	if _practice_round_finished():
		_finish_practice_round()


func _update_practice_ai() -> void:
	for note in practice_notes:
		var side := int(note["side"])
		if _is_side_human(side) or not practice_sides[side]:
			continue
		if String(note["state"]) in ["done", "missed"]:
			continue
		if practice_time >= float(note["hit_time"]):
			if int(note["type"]) == PRACTICE_RAPID:
				note["remaining"] = 0
			elif int(note["type"]) == PRACTICE_SLUR:
				_mark_practice_note_done(note, false, false)
				_activate_practice_flick_sustain(note)
				continue
			_mark_practice_note_done(note, false)


func _resolve_practice_notes() -> void:
	for note in practice_notes:
		var state := String(note["state"])
		if state in ["done", "missed"]:
			continue

		var side := int(note["side"])
		var note_type := int(note["type"])
		var hit_time := float(note["hit_time"])
		if note_type == PRACTICE_RAPID:
			if practice_time >= hit_time and state == "pending":
				note["state"] = "active"
			if practice_time > hit_time + float(note["duration"]) and String(note["state"]) == "active":
				if int(note["remaining"]) <= 0:
					_mark_practice_note_done(note, false)
				else:
					_mark_practice_note_missed(note)
			continue

		if note_type == PRACTICE_HOLD and state == "holding":
			if not bool(practice_held[side][int(note["lane"])]):
				_mark_practice_note_missed(note)
			elif practice_time >= hit_time + float(note["duration"]):
				_mark_practice_note_done(note, false)
			continue

		if note_type == PRACTICE_SLUR:
			if practice_time > hit_time + PRACTICE_HIT_WINDOW:
				_mark_practice_note_missed(note)
			continue

		if practice_time > hit_time + PRACTICE_HIT_WINDOW:
			_mark_practice_note_missed(note)


func _practice_round_finished() -> bool:
	if practice_notes.is_empty():
		return false
	for note in practice_notes:
		if String(note["state"]) not in ["done", "missed"]:
			return false
	return true


func _finish_practice_round() -> void:
	practice_active = false
	_stop_practice_longnote_loop()
	_queue_practice_redraw()
	var p1_failed: bool = bool(practice_sides[0]) and int(practice_misses[0]) > 0
	var p2_failed: bool = bool(practice_sides[1]) and int(practice_misses[1]) > 0
	if p1_failed or p2_failed:
		_start_lesson_dialogue([_practice_failure_message(practice_type, p1_failed, p2_failed)], practice_type, [p1_failed, p2_failed])
		return
	_on_practice_success(practice_type)


func _on_practice_success(done_type: int) -> void:
	match done_type:
		PRACTICE_TAP:
			_start_lesson_dialogue([
				PackedByteArray([0xec, 0xa2, 0x8b, 0xec, 0x95, 0x98, 0xec, 0x96, 0xb4, 0x21, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x9d, 0x8c, 0xec, 0x9d, 0x80, 0x20, 0xe2, 0x9e, 0x81, 0xeb, 0xa1, 0xb1, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0xec, 0x95, 0xbc, 0x2e, 0x0a, 0xec, 0x96, 0xb4, 0xec, 0x84, 0x9c, 0x20, 0xed, 0x95, 0xb4, 0xeb, 0xb4, 0x90, 0x2e]).get_string_from_utf8(),
			], PRACTICE_HOLD, [true, true])
		PRACTICE_HOLD:
			_start_lesson_dialogue([
				PackedByteArray([0xec, 0xa2, 0x8b, 0xec, 0x9d, 0x80, 0x20, 0xed, 0x9d, 0x90, 0xeb, 0xa6, 0x84, 0xec, 0x9d, 0xb4, 0xec, 0x95, 0xbc, 0x2e, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x9d, 0x8c, 0xec, 0x9d, 0x80, 0x20, 0xe2, 0x9e, 0x82, 0xed, 0x94, 0x8c, 0xeb, 0xa6, 0xad, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0x2e]).get_string_from_utf8(),
				PackedByteArray([0xec, 0x97, 0xb0, 0xea, 0xb2, 0xb0, 0xeb, 0x90, 0x9c, 0x20, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0xeb, 0xa5, 0xbc, 0x20, 0xec, 0x88, 0x9c, 0xec, 0x84, 0x9c, 0xeb, 0x8c, 0x80, 0xeb, 0xa1, 0x9c, 0x20, 0xec, 0xb3, 0x90, 0xec, 0x95, 0xbc, 0xed, 0x95, 0xb4, 0x2e, 0x0a, 0xed, 0x95, 0xb4, 0xeb, 0xb4, 0x90, 0x21]).get_string_from_utf8(),
			], PRACTICE_SLUR, [true, true])
		PRACTICE_SLUR:
			_start_lesson_dialogue([
				PackedByteArray([0xec, 0x95, 0x84, 0xec, 0xa3, 0xbc, 0x20, 0xec, 0x9e, 0x98, 0xed, 0x96, 0x88, 0xec, 0x96, 0xb4, 0x2e, 0x20, 0xeb, 0xa7, 0x88, 0xec, 0xa7, 0x80, 0xeb, 0xa7, 0x89, 0xec, 0x9d, 0x80, 0x20, 0xe2, 0x9e, 0x83, 0xec, 0x97, 0xb0, 0xed, 0x83, 0x80, 0xeb, 0x85, 0xb8, 0xed, 0x8a, 0xb8, 0xec, 0x95, 0xbc, 0x2e, 0x0a, 0xeb, 0x8b, 0xa8, 0xec, 0x88, 0x9c, 0xed, 0x95, 0xb4, 0x2e, 0x20, 0xea, 0xb7, 0xb8, 0xeb, 0x83, 0xa5, 0x20, 0xec, 0x97, 0xb0, 0xed, 0x83, 0x80, 0xed, 0x95, 0x98, 0xeb, 0xa9, 0xb4, 0x20, 0xeb, 0x8f, 0xbc, 0x21]).get_string_from_utf8(),
			], PRACTICE_RAPID, [true, true])
		PRACTICE_RAPID:
			_finish_tutorial_after_practice()


func _finish_tutorial_after_practice() -> void:
	lesson_dialogue_active = false
	return_to_start_after_line = true
	next_marker_enabled = false
	_hide_player_bubbles()
	if cat_sprite:
		cat_sprite.texture = CAT2_TEXTURE
	cat_bubble.visible = true
	_start_typed_bubble(cat_bubble, PackedByteArray([0xec, 0x9d, 0xb4, 0xec, 0xa0, 0x95, 0xeb, 0x8f, 0x84, 0xeb, 0xa9, 0xb4, 0x20, 0xec, 0xb6, 0xa9, 0xeb, 0xb6, 0x84, 0xed, 0x95, 0xb4, 0x2e, 0x20, 0xec, 0x9d, 0xb4, 0xec, 0xa0, 0x9c, 0x20, 0xeb, 0xb3, 0xb8, 0xea, 0xb2, 0x8c, 0xec, 0x9e, 0x84, 0xec, 0x9d, 0x84, 0x20, 0xed, 0x95, 0x98, 0xeb, 0x9f, 0xac, 0xea, 0xb0, 0x80, 0xeb, 0xb4, 0x90, 0x21]).get_string_from_utf8())


func _practice_failure_message(failed_type: int, p1_failed: bool, p2_failed: bool) -> String:
	if p1_failed and p2_failed:
		var both_messages := [
			PackedByteArray([0xec, 0x9d, 0xb4, 0x20, 0xed, 0x97, 0x88, 0xec, 0xa0, 0x91, 0xeb, 0x93, 0xa4, 0xec, 0x95, 0x84, 0x21, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x8b, 0x9c, 0x20, 0xed, 0x95, 0xb4, 0xeb, 0xb4, 0x90, 0x21]).get_string_from_utf8(),
			PackedByteArray([0xec, 0x9d, 0xb4, 0xec, 0xa0, 0x95, 0xeb, 0x8f, 0x88, 0x20, 0xec, 0x89, 0xbd, 0xec, 0x9e, 0x96, 0xec, 0x95, 0x84, 0x21, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x8b, 0x9c, 0x21]).get_string_from_utf8(),
		]
		return both_messages[practice_rng.randi_range(0, both_messages.size() - 1)]
	if p1_failed:
		var p1_messages := [
			PackedByteArray([0xeb, 0xad, 0x90, 0xed, 0x95, 0xb4, 0x2c, 0x20, 0x47, 0x47, 0x21, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x8b, 0x9c, 0x20, 0xed, 0x95, 0xb4, 0xeb, 0xb4, 0x90, 0x2e]).get_string_from_utf8(),
			PackedByteArray([0x47, 0x47, 0x2c, 0x20, 0xeb, 0x88, 0x88, 0xec, 0x9d, 0x80, 0x20, 0xeb, 0x8b, 0xac, 0xeb, 0xa0, 0xa4, 0x20, 0xec, 0x9e, 0x88, 0xeb, 0x8a, 0x94, 0xea, 0xb1, 0xb0, 0xec, 0x95, 0xbc, 0x3f, 0x21, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x8b, 0x9c, 0x21]).get_string_from_utf8(),
		]
		return p1_messages[practice_rng.randi_range(0, p1_messages.size() - 1)] if failed_type == PRACTICE_SLUR else p1_messages[min(failed_type, 1)]
	var p2_messages := [
		PackedByteArray([0xea, 0xb7, 0xb8, 0xea, 0xb2, 0x83, 0xeb, 0x8f, 0x84, 0x20, 0xeb, 0xaa, 0xbb, 0xed, 0x95, 0xb4, 0x2c, 0x20, 0x45, 0x5a, 0x3f, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x8b, 0x9c, 0x20, 0xed, 0x95, 0xb4, 0xeb, 0xb4, 0x90, 0x2c]).get_string_from_utf8(),
		PackedByteArray([0xec, 0x86, 0x90, 0xea, 0xb0, 0x80, 0xeb, 0x9d, 0xbd, 0xec, 0x9d, 0x80, 0x20, 0xec, 0x9e, 0x88, 0xeb, 0x8a, 0x94, 0xea, 0xb1, 0xb0, 0xec, 0xa7, 0x80, 0x2c, 0x20, 0x45, 0x5a, 0x3f, 0x21, 0x20, 0xeb, 0x8b, 0xa4, 0xec, 0x8b, 0x9c, 0x21]).get_string_from_utf8(),
	]
	return p2_messages[practice_rng.randi_range(0, p2_messages.size() - 1)] if failed_type == PRACTICE_SLUR else p2_messages[min(failed_type, 1)]


func _handle_practice_key(key_event: InputEventKey) -> bool:
	var side_lane := _side_lane_for_key(key_event)
	if side_lane.is_empty():
		return false

	var side := int(side_lane[0])
	var lane := int(side_lane[1])
	if key_event.echo:
		return true

	if key_event.pressed:
		practice_held[side][lane] = true
		_handle_practice_press(side, lane)
	else:
		practice_held[side][lane] = false
		_handle_practice_release(side, lane)
	return true


func _side_lane_for_key(key_event: InputEventKey) -> Array:
	var lane := _lane_for_key(key_event, _configured_lane_keycodes(0))
	if lane != -1:
		return [0, lane]
	lane = _lane_for_key(key_event, _configured_lane_keycodes(1))
	if lane != -1:
		return [1, lane]
	lane = _lane_for_key(key_event, LANE_KEYCODES_ARROWS)
	if lane != -1:
		var side := tutorial_human_side if not tutorial_multiplayer and tutorial_human_side != -1 else 0
		return [side, lane]
	return []


func _handle_practice_press(side: int, lane: int) -> void:
	if not practice_active:
		return
	_trigger_note_arrow(side, lane, false)
	if not practice_sides[side] or not _is_side_human(side):
		return

	match practice_type:
		PRACTICE_RAPID:
			_handle_rapid_press(side)
		PRACTICE_SLUR:
			_handle_flick_press(side, lane)
		_:
			_handle_tap_or_hold_press(side, lane)


func _handle_tap_or_hold_press(side: int, lane: int) -> void:
	var note := _find_best_practice_note(side, lane, practice_type)
	if note.is_empty():
		_count_practice_miss(side)
		return

	if int(note["type"]) == PRACTICE_HOLD:
		note["state"] = "holding"
		note["feedback"] = 1.0
		_play_note_hit_sound(side)
		_refresh_practice_longnote_loop()
	else:
		_mark_practice_note_done(note, true)


func _handle_practice_release(side: int, lane: int) -> void:
	if not practice_active or not practice_sides[side] or not _is_side_human(side):
		return

	if practice_type != PRACTICE_HOLD:
		return

	for note in practice_notes:
		if int(note["side"]) != side or int(note["lane"]) != lane or int(note["type"]) != PRACTICE_HOLD:
			continue
		if String(note["state"]) != "holding":
			continue
		if practice_time >= float(note["hit_time"]) + float(note["duration"]):
			_mark_practice_note_done(note, false)
		else:
			_mark_practice_note_missed(note)
		_refresh_practice_longnote_loop()
		return


func _handle_flick_press(side: int, lane: int) -> void:
	var note := _find_best_practice_note(side, lane, PRACTICE_SLUR)
	if note.is_empty():
		_count_practice_miss(side)
		return
	note["state"] = "done"
	note["feedback"] = 1.0
	_play_note_hit_sound(side)
	_play_flick_hit_sound(side)
	_activate_practice_flick_sustain(note)
	_refresh_practice_longnote_loop()


func _handle_rapid_press(side: int) -> void:
	for note in practice_notes:
		if int(note["side"]) == side and int(note["type"]) == PRACTICE_RAPID and String(note["state"]) == "pending":
			if practice_time >= float(note["hit_time"]) - PRACTICE_HIT_WINDOW:
				note["state"] = "active"
	var note := _active_rapid_note(side)
	if note.is_empty():
		_count_practice_miss(side)
		return
	note["remaining"] = max(0, int(note["remaining"]) - 1)
	note["feedback"] = 1.0
	_play_note_hit_sound(side)
	if int(note["remaining"]) <= 0:
		_mark_practice_note_done(note, true)


func _find_best_practice_note(side: int, lane: int, note_type: int) -> Dictionary:
	var best := {}
	var best_dt := 999.0
	for note in practice_notes:
		if int(note["side"]) != side or int(note["lane"]) != lane or int(note["type"]) != note_type:
			continue
		if String(note["state"]) != "pending":
			continue
		var dt: float = abs(float(note["hit_time"]) - practice_time)
		if dt <= PRACTICE_HIT_WINDOW and dt < best_dt:
			best = note
			best_dt = dt
	return best


func _find_slur_note(side: int, lane: int, chain_id: int, chain_index: int) -> Dictionary:
	var best := {}
	var best_dt := 999.0
	for note in practice_notes:
		if int(note["side"]) != side or int(note["lane"]) != lane or int(note["type"]) != PRACTICE_SLUR:
			continue
		if String(note["state"]) != "pending":
			continue
		if chain_id != -1 and int(note["chain_id"]) != chain_id:
			continue
		if int(note["chain_index"]) != chain_index:
			continue
		var dt: float = abs(float(note["hit_time"]) - practice_time)
		if dt <= PRACTICE_HIT_WINDOW and dt < best_dt:
			best = note
			best_dt = dt
	return best


func _slur_note_by_index(side: int, chain_id: int, chain_index: int) -> Dictionary:
	for note in practice_notes:
		if int(note["side"]) == side and int(note["chain_id"]) == chain_id and int(note["chain_index"]) == chain_index and int(note["type"]) == PRACTICE_SLUR:
			return note
	return {}


func _active_rapid_note(side: int) -> Dictionary:
	for note in practice_notes:
		if int(note["side"]) != side or int(note["type"]) != PRACTICE_RAPID:
			continue
		if String(note["state"]) == "active":
			return note
	return {}


func _mark_practice_note_done(note: Dictionary, with_feedback: bool, play_sound: bool = true) -> void:
	if String(note["state"]) in ["done", "missed"]:
		return
	note["state"] = "done"
	if with_feedback:
		note["feedback"] = 1.0
	if play_sound:
		_play_note_hit_sound(int(note["side"]))


func _mark_practice_note_missed(note: Dictionary) -> void:
	if String(note["state"]) in ["done", "missed"]:
		return
	note["state"] = "missed"
	_count_practice_miss(int(note["side"]))


func _count_practice_miss(side: int) -> void:
	if side < 0 or side > 1:
		return
	practice_misses[side] += 1


func _fail_slur_chain(side: int, chain_id: int) -> void:
	for note in practice_notes:
		if int(note["side"]) == side and int(note["chain_id"]) == chain_id and String(note["state"]) != "missed":
			note["state"] = "missed"
	_count_practice_miss(side)
	_clear_slur_chain_state(side)


func _complete_slur_chain(side: int, chain_id: int) -> void:
	for note in practice_notes:
		if int(note["side"]) == side and int(note["chain_id"]) == chain_id and String(note["state"]) != "missed":
			note["state"] = "done"


func _clear_slur_chain_state(side: int) -> void:
	practice_active_slur_chain[side] = -1
	practice_active_slur_next_index[side] = 0
	practice_active_slur_held_lanes[side] = []


func _activate_practice_flick_sustain(head: Dictionary) -> void:
	if not bool(head["connect_next"]):
		return
	var side := int(head["side"])
	var chain_id := int(head["chain_id"])
	var chain_end := float(head["hit_time"])
	for note in practice_notes:
		if int(note["side"]) == side and int(note["type"]) == PRACTICE_SLUR and int(note["chain_id"]) == chain_id:
			chain_end = max(chain_end, float(note["hit_time"]))
	if side >= 0 and side < practice_flick_sustain_end_times.size() and chain_end > practice_time:
		practice_flick_sustain_end_times[side].append(chain_end)


func _is_side_human(side: int) -> bool:
	return tutorial_multiplayer or tutorial_human_side == side


func _queue_practice_redraw() -> void:
	if practice_layer:
		practice_layer.queue_redraw()


func _draw_practice_slur_connections(canvas: CanvasItem) -> void:
	for note in practice_notes:
		if int(note["type"]) != PRACTICE_SLUR:
			continue
		var next_note := _next_slur_draw_note(note)
		if next_note.is_empty():
			continue
		var start := _practice_note_center(note)
		var finish := _practice_note_center(next_note)
		if start.y < -90.0 and finish.y < -90.0:
			continue
		if start.y > 760.0 and finish.y > 760.0:
			continue
		var lane := int(note["lane"])
		var color: Color = LANE_COLORS[lane]
		if int(note["side"]) == 0:
			color = color.darkened(0.15)
		canvas.draw_line(start, finish, Color(color, 0.72), 5.0, true)

		# Match Main.gd's successful flick trail between linked notes.
		if String(note["state"]) != "done" or practice_time < float(note["hit_time"]) or practice_time > float(next_note["hit_time"]):
			continue
		var link_duration: float = float(next_note["hit_time"]) - float(note["hit_time"])
		if link_duration <= 0.0:
			continue
		var progress: float = clamp((practice_time - float(note["hit_time"])) / link_duration, 0.0, 1.0)
		var trail_start := _receptor_center(int(note["side"]), lane)
		var trail_finish := _receptor_center(int(next_note["side"]), int(next_note["lane"]))
		for trail_index in range(5):
			var trail_progress: float = progress - float(trail_index) * 0.11
			if trail_progress < 0.0:
				continue
			var trail_position: Vector2 = trail_start.lerp(trail_finish, trail_progress)
			var trail_alpha: float = 1.0 - float(trail_index) * 0.16
			canvas.draw_circle(trail_position, 8.0 - float(trail_index), Color(color.lightened(0.45), trail_alpha))


func _next_slur_draw_note(note: Dictionary) -> Dictionary:
	for candidate in practice_notes:
		if int(candidate["type"]) != PRACTICE_SLUR:
			continue
		if int(candidate["side"]) != int(note["side"]) or int(candidate["chain_id"]) != int(note["chain_id"]):
			continue
		if int(candidate["chain_index"]) == int(note["chain_index"]) + 1:
			return candidate
	return {}


func _draw_practice_note(canvas: CanvasItem, note: Dictionary) -> void:
	if String(note["state"]) in ["done", "missed"]:
		return

	var note_type := int(note["type"])
	var center := _practice_note_center(note)
	if note_type == PRACTICE_HOLD:
		_draw_practice_hold_body(canvas, note, center)
		if center.y < -90.0 or center.y > 790.0:
			return
		var hold_feedback := float(note["feedback"])
		_draw_practice_chart_arrow(canvas, int(note["lane"]), center, PRACTICE_NOTE_SIZE * (1.0 + hold_feedback * 0.18))
		return

	if center.y < -90.0 or center.y > 790.0:
		return

	if note_type == PRACTICE_RAPID:
		_draw_practice_rapid_note(canvas, note, center)
		return

	var lane := int(note["lane"])
	var feedback := float(note["feedback"])
	var scale := 1.0 + feedback * 0.18
	var size_value := PRACTICE_NOTE_SIZE * scale
	if note_type in [PRACTICE_HOLD, PRACTICE_SLUR]:
		_draw_practice_chart_arrow(canvas, lane, center, size_value)
		return
	var texture: Texture2D = _practice_note_texture(lane, note_type)
	_draw_practice_arrow_texture(canvas, texture, center, size_value)


func _draw_practice_hold_body(canvas: CanvasItem, note: Dictionary, center: Vector2) -> void:
	var tail_y := _practice_hold_tail_y(note, center)
	if center.y < -90.0 and tail_y < -90.0:
		return
	if center.y > 790.0 and tail_y > 790.0:
		return
	var top_y: float = min(center.y, tail_y)
	var height: float = abs(tail_y - center.y)
	var body_width := PRACTICE_NOTE_SIZE * 0.38
	var body_rect := Rect2(Vector2(center.x - body_width * 0.5, top_y), Vector2(body_width, max(8.0, height)))
	var color: Color = LANE_COLORS[int(note["lane"])]
	if int(note["side"]) == 0:
		color = color.darkened(0.15)
	canvas.draw_rect(body_rect, Color(color, 0.36), true)


func _draw_practice_rapid_note(canvas: CanvasItem, note: Dictionary, center: Vector2) -> void:
	var feedback := float(note["feedback"])
	var scale := 1.0 + feedback * 0.12
	var size_value := 86.0 * scale
	var rect := Rect2(center - Vector2(size_value, size_value) * 0.5, Vector2(size_value, size_value))
	canvas.draw_rect(rect, Color.WHITE, true)
	canvas.draw_rect(rect, Color.BLACK, false, 5.0)
	var count_text := str(max(0, int(note["remaining"])))
	canvas.draw_string(MENU_FONT, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.65), count_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 34, Color.BLACK)


func _practice_note_texture(lane: int, note_type: int) -> Texture2D:
	if lane < 0 or lane >= NOTE_TEXTURES.size():
		return null
	if note_type == PRACTICE_TAP:
		if lane < note_inverted_textures.size() and note_inverted_textures[lane] != null:
			return note_inverted_textures[lane]
	return NOTE_TEXTURES[lane]


func _draw_practice_arrow_texture(canvas: CanvasItem, texture: Texture2D, center: Vector2, size_value: float) -> void:
	if texture == null:
		return
	var rect := Rect2(center - Vector2(size_value, size_value) * 0.5, Vector2(size_value, size_value))
	canvas.draw_texture_rect(texture, rect, false)


func _draw_practice_chart_arrow(canvas: CanvasItem, lane: int, center: Vector2, size_value: float) -> void:
	if lane < 0 or lane >= chart_note_textures.size():
		return
	var rect := Rect2(center - Vector2(size_value, size_value) * 0.5, Vector2(size_value, size_value))
	if lane < note_outline_textures.size():
		canvas.draw_texture_rect(note_outline_textures[lane], rect, false, Color.BLACK)
	canvas.draw_texture_rect(chart_note_textures[lane], rect, false, Color.WHITE)


func _practice_hold_tail_y(note: Dictionary, center: Vector2) -> float:
	return _receptor_center(int(note["side"]), int(note["lane"])).y + (practice_time - float(note["hit_time"]) - float(note["duration"])) * PRACTICE_NOTE_SPEED


func _practice_note_center(note: Dictionary) -> Vector2:
	var receptor := _receptor_center(int(note["side"]), int(note["lane"]))
	var state := String(note["state"])
	if int(note["type"]) == PRACTICE_RAPID and state == "active":
		return receptor
	if int(note["type"]) in [PRACTICE_HOLD, PRACTICE_SLUR] and state == "holding":
		return receptor
	return Vector2(receptor.x, receptor.y + (practice_time - float(note["hit_time"])) * PRACTICE_NOTE_SPEED)


func _receptor_center(side: int, lane: int) -> Vector2:
	if lane == -1:
		var left := _receptor_center(side, 0)
		var right := _receptor_center(side, 3)
		return Vector2((left.x + right.x) * 0.5, (left.y + right.y) * 0.5)
	for arrow in note_arrows:
		if arrow and arrow.side == side and arrow.lane == lane:
			return arrow.position + arrow.size * 0.5
	return Vector2(640.0, 548.0)


func _handle_note_key(key_event: InputEventKey) -> bool:
	if not _note_arrows_visible():
		return false

	var lane := _lane_for_key(key_event, _configured_lane_keycodes(0))
	if lane != -1:
		_trigger_note_arrow(0, lane)
		return true

	lane = _lane_for_key(key_event, _configured_lane_keycodes(1))
	if lane != -1:
		_trigger_note_arrow(1, lane)
		return true

	lane = _lane_for_key(key_event, LANE_KEYCODES_ARROWS)
	if lane != -1:
		var side := tutorial_human_side if not tutorial_multiplayer and tutorial_human_side != -1 else 0
		_trigger_note_arrow(side, lane)
		return true

	return false


func _lane_for_key(key_event: InputEventKey, keycodes: Array) -> int:
	for i in range(keycodes.size()):
		if key_event.keycode == keycodes[i] or key_event.physical_keycode == keycodes[i]:
			return i
	return -1


func _configured_lane_keycodes(side: int) -> Array:
	var keys := []
	var start_index := 0 if side == 0 else 4
	for lane in range(4):
		keys.append(GameSettings.get_lane_key(start_index + lane))
	return keys


func _note_arrows_visible() -> bool:
	for arrow in note_arrows:
		if arrow and arrow.visible:
			return true
	return false


func _trigger_note_arrow(side: int, lane: int, play_sound: bool = true) -> void:
	for arrow in note_arrows:
		if arrow and arrow.side == side and arrow.lane == lane:
			arrow.trigger_feedback()
			if play_sound:
				_play_note_hit_sound(side)
			return


func _play_note_hit_sound(side: int) -> void:
	var stream: AudioStream = perfect_stream_p1 if side == 0 else perfect_stream_p2
	_play_one_shot_stream(stream, 0.0)


func _play_flick_hit_sound(side: int) -> void:
	var stream: AudioStream = flick_stream_p1 if side == 0 else flick_stream_p2
	_play_one_shot_stream(stream, FLICK_VOLUME_DB)


func _play_one_shot_stream(stream: AudioStream, volume_db: float) -> void:
	if note_sound_players.is_empty():
		return

	var player: AudioStreamPlayer = note_sound_players[note_sound_index]
	note_sound_index = (note_sound_index + 1) % note_sound_players.size()
	if stream:
		player.stream = stream
		player.volume_db = volume_db
		player.play(0.0)


func _refresh_practice_longnote_loop() -> void:
	for side in range(practice_flick_sustain_end_times.size()):
		for index in range(practice_flick_sustain_end_times[side].size() - 1, -1, -1):
			if practice_time > float(practice_flick_sustain_end_times[side][index]):
				practice_flick_sustain_end_times[side].remove_at(index)
	var should_loop_p1: bool = not practice_flick_sustain_end_times[0].is_empty()
	var should_loop_p2: bool = not practice_flick_sustain_end_times[1].is_empty()
	var hold_volume_p1 := LONGNOTE_START_VOLUME_DB
	var hold_volume_p2 := LONGNOTE_START_VOLUME_DB
	var has_hold_p1 := false
	var has_hold_p2 := false

	for note in practice_notes:
		var state := String(note["state"])
		var note_type := int(note["type"])
		var side := int(note["side"])
		if state != "holding" or side < 0 or side > 1:
			continue
		if note_type == PRACTICE_HOLD:
			var lane := int(note["lane"])
			if lane < 0 or lane >= 4 or not bool(practice_held[side][lane]):
				continue
			var hold_volume := _practice_longnote_volume_for_note(note)
			if side == 0:
				should_loop_p1 = true
				hold_volume_p1 = hold_volume if not has_hold_p1 else max(hold_volume_p1, hold_volume)
				has_hold_p1 = true
			else:
				should_loop_p2 = true
				hold_volume_p2 = hold_volume if not has_hold_p2 else max(hold_volume_p2, hold_volume)
				has_hold_p2 = true
	_set_longnote_player_active(longnote_player_p1, should_loop_p1, hold_volume_p1)
	_set_longnote_player_active(longnote_player_p2, should_loop_p2, hold_volume_p2)


func _practice_longnote_volume_for_note(note: Dictionary) -> float:
	var duration: float = max(float(note["duration"]), 0.01)
	var progress: float = clamp((practice_time - float(note["hit_time"])) / duration, 0.0, 1.0)
	return lerp(LONGNOTE_START_VOLUME_DB, LONGNOTE_END_VOLUME_DB, progress)


func _set_longnote_player_active(player: AudioStreamPlayer, active: bool, volume_db: float) -> void:
	if player == null:
		return
	if active:
		player.volume_db = volume_db
		if player.stream != null and not player.playing:
			player.play(0.0)
	elif player.playing:
		player.stop()


func _stop_practice_longnote_loop() -> void:
	_set_longnote_player_active(longnote_player_p1, false, LONGNOTE_START_VOLUME_DB)
	_set_longnote_player_active(longnote_player_p2, false, LONGNOTE_START_VOLUME_DB)


func _apply_basic_tutorial_step() -> void:
	if dialogue_mode != DIALOGUE_MODE_BASIC:
		return

	match dialogue_index:
		1:
			boss_hp_bar.visible = true
		2:
			gauge_bar.visible = true
		3:
			p1_hp_bar.visible = true
			p2_hp_bar.visible = true
		4:
			_show_note_arrows()
