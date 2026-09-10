extends Node2D

# Shared black-and-white settings screen.  It is deliberately code-drawn so
# both the map menu and every battle scene can use the same screen.
const UI_FONT := preload("res://fonts/Mona12TextJP.ttf")
const ROW_COUNT := 12
const FIRST_KEY_ROW := 4
const VISIBLE_ROWS := 5
const ROW_HEIGHT := 62.0
const BUS_NAMES := [&"Master", &"Music", &"SFX"]
const ROW_NAMES := ["마스터 볼륨", "배경음 볼륨", "효과음 볼륨", "전체 화면", "1P 왼쪽", "1P 아래", "1P 위", "1P 오른쪽", "2P 왼쪽", "2P 아래", "2P 위", "2P 오른쪽"]

var selected_row := 0
var first_visible_row := 0
var waiting_for_key := false
var fullscreen_enabled := false
var viewport_size := Vector2(1280.0, 720.0)


func _ready() -> void:
	position = Vector2.ZERO
	viewport_size = get_viewport_rect().size
	z_index = 200
	visible = false
	GameSettings.ensure_lane_actions()
	_refresh_fullscreen()


func open_settings() -> void:
	viewport_size = get_viewport_rect().size
	visible = true
	selected_row = 0
	first_visible_row = 0
	waiting_for_key = false
	_refresh_fullscreen()
	queue_redraw()


func close_settings() -> void:
	visible = false
	waiting_for_key = false


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_row(selected_row - 1)
			return true
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_row(selected_row + 1)
			return true
		return true
	if not event is InputEventKey:
		return true
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return true
	if waiting_for_key:
		if key.keycode == KEY_ESCAPE:
			waiting_for_key = false
		else:
			GameSettings.set_lane_key(selected_row - FIRST_KEY_ROW, key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
			waiting_for_key = false
		queue_redraw()
		return true
	match key.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			close_settings()
			return true
		KEY_UP:
			_select_row(selected_row - 1)
		KEY_DOWN:
			_select_row(selected_row + 1)
		KEY_LEFT:
			_change_selected(-1)
		KEY_RIGHT:
			_change_selected(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if selected_row >= FIRST_KEY_ROW:
				waiting_for_key = true
			else:
				_change_selected(1)
		queue_redraw()
	return true


func _select_row(next_row: int) -> void:
	selected_row = clampi(next_row, 0, ROW_COUNT - 1)
	if selected_row < first_visible_row:
		first_visible_row = selected_row
	elif selected_row >= first_visible_row + VISIBLE_ROWS:
		first_visible_row = selected_row - VISIBLE_ROWS + 1
	queue_redraw()


func _change_selected(direction: int) -> void:
	if selected_row < 3:
		var bus_index := AudioServer.get_bus_index(BUS_NAMES[selected_row])
		if bus_index >= 0:
			var current := db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
			var changed := clampf(current + direction * 5.0, 0.0, 100.0)
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(changed / 100.0) if changed > 0.0 else -80.0)
	elif selected_row == 3:
		fullscreen_enabled = not fullscreen_enabled
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	queue_redraw()


func _refresh_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	fullscreen_enabled = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _row_value(row: int) -> String:
	if row < 3:
		var bus_index := AudioServer.get_bus_index(BUS_NAMES[row])
		var volume := 70 if bus_index < 0 else clampi(roundi(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0), 0, 100)
		return "%d/100" % volume
	if row == 3:
		return "ON" if fullscreen_enabled else "OFF"
	return GameSettings.lane_key_text(row - FIRST_KEY_ROW)


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.0, 0.82))
	var panel := Rect2(250.0, 80.0, 780.0, 560.0)
	draw_rect(panel, Color.BLACK)
	draw_rect(panel, Color.WHITE, false, 4.0)
	draw_string(UI_FONT, Vector2(292.0, 130.0), "설정", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(UI_FONT, Vector2(292.0, 165.0), "↑↓ 선택  ←→ 조절  Enter 키 변경  Esc 뒤로", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 0.75, 0.75))
	var list_rect := Rect2(285.0, 190.0, 710.0, 335.0)
	draw_rect(list_rect, Color(0.08, 0.08, 0.08))
	for local_row in range(VISIBLE_ROWS):
		var row := first_visible_row + local_row
		if row >= ROW_COUNT:
			break
		var rect := Rect2(list_rect.position + Vector2(0.0, local_row * ROW_HEIGHT), Vector2(list_rect.size.x, ROW_HEIGHT - 2.0))
		var selected := row == selected_row
		draw_rect(rect, Color.WHITE if selected else Color.BLACK)
		draw_rect(rect, Color.WHITE, false, 2.0)
		var color := Color.BLACK if selected else Color.WHITE
		draw_string(UI_FONT, rect.position + Vector2(20.0, 39.0), ROW_NAMES[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, color)
		var value := "키를 누르세요..." if selected and waiting_for_key else _row_value(row)
		draw_string(UI_FONT, rect.position + Vector2(470.0, 39.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, color)
	if ROW_COUNT > VISIBLE_ROWS:
		var scroll_height := list_rect.size.y * float(VISIBLE_ROWS) / float(ROW_COUNT)
		var scroll_y := list_rect.position.y + (list_rect.size.y - scroll_height) * float(first_visible_row) / float(ROW_COUNT - VISIBLE_ROWS)
		draw_rect(Rect2(1003.0, scroll_y, 7.0, scroll_height), Color.WHITE)
	draw_string(UI_FONT, Vector2(292.0, 590.0), "조작키 설정은 스크롤 아래에 있습니다.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.75, 0.75, 0.75))
