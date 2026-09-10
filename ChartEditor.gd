extends Node2D

const CHART_CODEC := preload("res://ChartCodec.gd")
const CHARTS_PATH := "res://charts"
const BACKUPS_PATH := "res://charts/backups"
const AUDIO_ROOT := "res://audio/"
const LANE_COUNT := 4
const EDITOR_ROW_COUNT := LANE_COUNT * 2
const LANE_KEYS := ["note_left", "note_down", "note_up", "note_right"]
const LANE_KEYCODES := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const LANE_COLORS := [Color("e0863c"), Color("48a6a2"), Color("c65b86"), Color("d9b24a")]
# 실제 게임(Main.gd)의 P1/P2 키 그대로 — 재생 중 이 키를 누르면 그 순간 타이밍에 탭 노트를 찍는다.
# Main.gd 기준: side=="player" -> P1(0), 그 외("opponent") -> P2(1). 에디터도 1P(위)=player, 2P(아래)=opponent.
const REC_KEYCODES_P1 := [KEY_A, KEY_S, KEY_D, KEY_F]      # side="player" (Main.gd 기준 P1)
const REC_KEYCODES_P2 := [KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]  # side="opponent" (Main.gd 기준 P2)
const NOTE_TYPES := ["tap", "hold", "rapid", "slur"]
const SNAP_BEATS := [0.0, 0.25, 0.125, 1.0 / 12.0, 0.0625]
const TIMELINE_RECT := Rect2(150, 186, 1094, 460)
const H_SCROLL_RECT := Rect2(150, 674, 1094, 24)
const RULER_HEIGHT := 34.0
const MAX_HISTORY := 100
const TONE_PLAYER_COUNT := 10
const METRONOME_PLAYER_COUNT := 3
const WAVEFORM_BUCKET_SECONDS := 0.002  # 곡 로드시 1회 분석하는 캐시 해상도(초당 500칸)
const WAVEFORM_CHUNK_FRAMES := 4096
const WAVEFORM_MAX_CHUNKS := 200000     # 안전장치 (무한루프 방지)

# ---------- 테스트 박스 (에디터 안에서 바로 미리듣기+미리치기) ----------
const TEST_BOX_RECT := Rect2(970, 195, 240, 440)   # 세로가 더 긴 작은 박스
const TEST_LANE_X := [1010.0, 1060.0, 1110.0, 1160.0]
const TEST_SCROLL := 220.0              # 테스트 박스 안 스크롤 속도(px/sec)
const TEST_HIT_WINDOW := 0.15           # 테스트 박스 히트 판정 폭(초) — 점수 없이 느낌만 확인용
const TEST_LANE_TOP := 245.0            # 테스트 박스 안, 이 y보다 위는 안 그림(버튼 영역과 안 겹치게)

var font: Font
var audio_player: AudioStreamPlayer
var tone_players: Array[AudioStreamPlayer] = []
var tone_index: int = 0
var perfect_stream: AudioStream
var longnote_stream: AudioStream
var metronome_players: Array[AudioStreamPlayer] = []
var metronome_index: int = 0
var metronome_tick_stream: AudioStream
var metronome_accent_stream: AudioStream
var metronome_enabled: bool = false

# ---------- 웨이브폼 캐시 ----------
# 1단계: 곡 전체를 고정폭(WAVEFORM_BUCKET_SECONDS) 버킷의 min/max로 압축 (로드시 1회만 계산)
var waveform_min: PackedFloat32Array = PackedFloat32Array()
var waveform_max: PackedFloat32Array = PackedFloat32Array()
var waveform_ready: bool = false
# 2단계: 현재 화면 픽셀 폭에 맞춘 min/max (스크롤/줌이 실제로 바뀔 때만 재계산)
var waveform_draw_min: PackedFloat32Array = PackedFloat32Array()
var waveform_draw_max: PackedFloat32Array = PackedFloat32Array()
var waveform_cache_view_start: float = -1.0
var waveform_cache_pixels_per_second: float = -1.0

# ---------- 테스트 박스 상태 ----------
var test_mode_enabled: bool = false
var test_selected_side: String = "player"   # "player"=P1, "opponent"=P2
var test_hit_keys: Array[String] = []       # 이번 테스트 세션에서 이미 친 노트 표시(진짜 채보엔 손 안 댐)

# ---------- 뮤트 (재생 헤드가 노트를 지나칠 때 미리듣기 소리만 끔, 채보 자체는 그대로) ----------
var mute_p1: bool = false
var mute_p2: bool = false

var chart_paths: Array[String] = []
var current_chart_path: String = ""
var chart_data: Dictionary = {}
var notes: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var phases: Array[Dictionary] = []
var playback_time: float = 0.0
var last_chart_time: float = 0.0
var song_length: float = 0.0
var is_playing: bool = false
var recording: bool = false
var dirty: bool = false
var bpm: float = 132.0
var chart_offset: float = 0.0
var pixels_per_second: float = 180.0
var view_start_time: float = 0.0
var snap_index: int = 3
var selected_indices: Array[int] = []
var clipboard: Array[Dictionary] = []
var undo_stack: Array = []
var redo_stack: Array = []
var drag_mode: String = ""
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_time: float = 0.0
var drag_start_row: int = 0
var drag_original_notes: Array[Dictionary] = []
var drag_original_selection: Array[int] = []
var drag_selected_notes: Array[Dictionary] = []
var selection_rect: Rect2 = Rect2()
var resume_after_scrub: bool = false
var click_delete_index: int = -1
var press_moved: bool = false
var box_select_enabled: bool = false
var phase_resize_index: int = -1
var status_text: String = "Ready"

var chart_menu: OptionButton
var type_menu: OptionButton
var snap_menu: OptionButton
var record_toggle: CheckButton
var box_select_toggle: CheckButton
var metronome_toggle: CheckButton
var bpm_edit: LineEdit
var offset_edit: LineEdit
var seek_edit: LineEdit
var time_edit: LineEdit
var lane_edit: LineEdit
var duration_edit: LineEdit
var pitch_edit: LineEdit
var mash_edit: LineEdit
var connect_toggle: CheckButton
var test_toggle: CheckButton
var test_p1_button: Button
var test_p2_button: Button
var test_close_button: Button
var mute_p1_toggle: CheckButton
var mute_p2_toggle: CheckButton


func _ready() -> void:
	font = ThemeDB.fallback_font
	_setup_input()
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = &"Music"
	add_child(audio_player)
	_setup_tone_players()
	_setup_metronome()
	_build_ui()
	_refresh_chart_list()
	if chart_paths.size() > 0:
		_load_chart(chart_paths[0])
	else:
		status_text = "No charts found in res://charts"
	queue_redraw()


func _setup_tone_players() -> void:
	perfect_stream = load("res://audio/perfect.wav")
	longnote_stream = load("res://audio/longnote.wav")
	for _index in range(TONE_PLAYER_COUNT):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		tone_players.append(player)


func _setup_metronome() -> void:
	metronome_tick_stream = load("res://audio/metronome_tick.wav")
	metronome_accent_stream = load("res://audio/metronome_accent.wav")
	for _index in range(METRONOME_PLAYER_COUNT):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		metronome_players.append(player)


func _play_metronome_tick(is_accent: bool) -> void:
	if metronome_players.is_empty():
		return
	var player: AudioStreamPlayer = metronome_players[metronome_index]
	metronome_index = (metronome_index + 1) % metronome_players.size()
	var stream: AudioStream = metronome_accent_stream if is_accent else metronome_tick_stream
	if stream:
		player.stream = stream
		player.play()


# 재생 헤드가 지나친 박자마다 메트로놈 클릭 재생. 마디 1박은 강박(accent), 2/3/4박은 약박(tick).
func _play_metronome_between(from_time: float, to_time: float) -> void:
	if bpm <= 0.0:
		return
	var beat_seconds: float = 60.0 / bpm
	var first_beat: int = int(floor(from_time / beat_seconds)) + 1
	var last_beat: int = int(floor(to_time / beat_seconds))
	for beat_index in range(first_beat, last_beat + 1):
		if beat_index < 0:
			continue
		_play_metronome_tick(beat_index % 4 == 0)


# ============================================================
#  웨이브폼 캐시
# ============================================================
# 곡 로드시 1회만 호출. AudioStreamPlayback.mix_audio()로 디코드된 실제 샘플을 읽어
# WAVEFORM_BUCKET_SECONDS 폭의 버킷마다 min/max를 저장한다. WAV/OggVorbis/MP3 전부
# AudioStreamPlayback 기반이라 포맷별 분기 없이 이 방식 하나로 다 처리된다
# (내부 압축 포맷이 IMA-ADPCM/QOA/Vorbis/MP3여도 mix_audio가 디코드해서 돌려줌).
func _build_waveform_cache(stream: AudioStream) -> void:
	waveform_min = PackedFloat32Array()
	waveform_max = PackedFloat32Array()
	waveform_ready = false
	_invalidate_waveform_draw_cache()
	if stream == null:
		return
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	if playback == null or not playback.has_method("mix_audio"):
		push_warning("Waveform: this stream type does not support sample readback (mix_audio)")
		return
	playback.start(0.0)
	var cur_bucket: int = -1
	var cur_min: float = 0.0
	var cur_max: float = 0.0
	var guard: int = 0
	while guard < WAVEFORM_MAX_CHUNKS:
		guard += 1
		var pos_before: float = playback.get_playback_position()
		var chunk: PackedVector2Array = playback.mix_audio(1.0, WAVEFORM_CHUNK_FRAMES)
		var count: int = chunk.size()
		if count == 0:
			break
		var pos_after: float = playback.get_playback_position()
		var span: float = pos_after - pos_before
		if span <= 0.0:
			span = float(count) / 44100.0  # 방어적 대체값 (포지션이 갱신 안 되는 예외 상황)
		for i in range(count):
			var frame: Vector2 = chunk[i]
			var v: float = (frame.x + frame.y) * 0.5  # 스테레오 -> 모노 다운믹스
			var t: float = pos_before + span * (float(i) / float(count))
			var bucket: int = int(t / WAVEFORM_BUCKET_SECONDS)
			if bucket != cur_bucket:
				if cur_bucket >= 0:
					waveform_min.append(cur_min)
					waveform_max.append(cur_max)
				while waveform_min.size() < bucket:
					waveform_min.append(0.0)
					waveform_max.append(0.0)
				cur_bucket = bucket
				cur_min = v
				cur_max = v
			else:
				cur_min = min(cur_min, v)
				cur_max = max(cur_max, v)
		if count < WAVEFORM_CHUNK_FRAMES:
			break
	if cur_bucket >= 0:
		waveform_min.append(cur_min)
		waveform_max.append(cur_max)
	waveform_ready = waveform_min.size() > 0
	if playback.has_method("stop"):
		playback.stop()


func _invalidate_waveform_draw_cache() -> void:
	waveform_draw_min = PackedFloat32Array()
	waveform_draw_max = PackedFloat32Array()
	waveform_cache_view_start = -1.0
	waveform_cache_pixels_per_second = -1.0


# 화면 픽셀 폭에 맞춘 min/max를 만든다 — view_start_time/pixels_per_second가 실제로
# 바뀌었을 때만 다시 계산하고, 그 외에는 캐시된 배열을 그대로 재사용한다.
func _ensure_waveform_draw_cache() -> void:
	var width: int = int(TIMELINE_RECT.size.x)
	if waveform_draw_min.size() == width and is_equal_approx(waveform_cache_view_start, view_start_time) and is_equal_approx(waveform_cache_pixels_per_second, pixels_per_second):
		return
	var bucket_count: int = waveform_min.size()
	var new_min: PackedFloat32Array = PackedFloat32Array()
	var new_max: PackedFloat32Array = PackedFloat32Array()
	new_min.resize(width)
	new_max.resize(width)
	for x in range(width):
		var t0: float = view_start_time + (float(x) / pixels_per_second)
		var t1: float = view_start_time + (float(x + 1) / pixels_per_second)
		var b0: int = clampi(int(t0 / WAVEFORM_BUCKET_SECONDS), 0, max(bucket_count - 1, 0))
		var b1: int = clampi(int(t1 / WAVEFORM_BUCKET_SECONDS), 0, max(bucket_count - 1, 0))
		if b1 < b0:
			b1 = b0
		var col_min: float = 0.0
		var col_max: float = 0.0
		var first: bool = true
		for b in range(b0, b1 + 1):
			if b < 0 or b >= bucket_count:
				continue
			var mn: float = waveform_min[b]
			var mx: float = waveform_max[b]
			if first:
				col_min = mn
				col_max = mx
				first = false
			else:
				col_min = min(col_min, mn)
				col_max = max(col_max, mx)
		new_min[x] = col_min
		new_max[x] = col_max
	waveform_draw_min = new_min
	waveform_draw_max = new_max
	waveform_cache_view_start = view_start_time
	waveform_cache_pixels_per_second = pixels_per_second


# 재생 헤드가 노트를 지나칠 때 미리듣기 효과음 재생. hold는 longnote(지속음),
# 나머지(tap/slur/rapid)는 perfect(청아한 판정음) — 실제 게임(Main.gd)과 같은 음원 재사용.
func _play_note_preview(note_type: String) -> void:
	if tone_players.is_empty():
		return
	var player: AudioStreamPlayer = tone_players[tone_index]
	tone_index = (tone_index + 1) % tone_players.size()
	var stream: AudioStream = longnote_stream if note_type == "hold" else perfect_stream
	if stream != null:
		player.stream = stream
		player.play()


func _setup_input() -> void:
	for lane in range(LANE_COUNT):
		var action: String = LANE_KEYS[lane]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var primary: InputEventKey = InputEventKey.new()
		primary.keycode = LANE_KEYCODES[lane]
		InputMap.action_add_event(action, primary)
		# 예전 D/F/J/K 대체키는 뺐다 — 실제 게임 키(ASDF/KL;')로 즉석 노트 찍기를 새로 붙이면서
		# D, F가 겹쳐서 한 번 눌렀는데 노트가 두 개 찍히는 문제가 생기기 때문.


func _build_ui() -> void:
	chart_menu = OptionButton.new()
	chart_menu.position = Vector2(18, 16)
	chart_menu.size = Vector2(220, 30)
	chart_menu.focus_mode = Control.FOCUS_NONE
	chart_menu.item_selected.connect(_on_chart_selected)
	add_child(chart_menu)

	_add_button("Play", Rect2(248, 16, 58, 30), _toggle_playback)
	_add_button("From Start", Rect2(312, 16, 92, 30), _play_from_start)
	_add_button("Stop", Rect2(410, 16, 58, 30), _stop_playback)
	_add_button("Save", Rect2(474, 16, 58, 30), _save_chart)
	_add_button("Undo", Rect2(538, 16, 58, 30), _undo)
	_add_button("Redo", Rect2(602, 16, 58, 30), _redo)

	record_toggle = CheckButton.new()
	record_toggle.text = "Record"
	record_toggle.position = Vector2(674, 17)
	record_toggle.size = Vector2(92, 28)
	record_toggle.focus_mode = Control.FOCUS_NONE
	record_toggle.toggled.connect(_on_record_toggled)
	add_child(record_toggle)
	box_select_toggle = CheckButton.new()
	box_select_toggle.text = "Box Select"
	box_select_toggle.position = Vector2(780, 17)
	box_select_toggle.size = Vector2(112, 28)
	box_select_toggle.focus_mode = Control.FOCUS_NONE
	box_select_toggle.toggled.connect(_on_box_select_toggled)
	add_child(box_select_toggle)
	_add_button("Add Highlight", Rect2(906, 16, 128, 30), _add_highlight_phase)
	metronome_toggle = CheckButton.new()
	metronome_toggle.text = "Metronome"
	metronome_toggle.position = Vector2(1042, 17)
	metronome_toggle.size = Vector2(120, 28)
	metronome_toggle.focus_mode = Control.FOCUS_NONE
	metronome_toggle.toggled.connect(_on_metronome_toggled)
	add_child(metronome_toggle)
	test_toggle = CheckButton.new()
	test_toggle.text = "Test"
	test_toggle.position = Vector2(1170, 17)
	test_toggle.size = Vector2(96, 28)
	test_toggle.focus_mode = Control.FOCUS_NONE
	test_toggle.toggled.connect(_on_test_toggled)
	add_child(test_toggle)

	# 테스트 박스 안쪽 버튼들 — 평소엔 숨겨두고 테스트 모드일 때만 보이게 한다.
	test_p1_button = Button.new()
	test_p1_button.text = "P1"
	test_p1_button.position = Vector2(TEST_BOX_RECT.position.x + 10, TEST_BOX_RECT.position.y + 40)
	test_p1_button.size = Vector2(55, 28)
	test_p1_button.focus_mode = Control.FOCUS_NONE
	test_p1_button.visible = false
	test_p1_button.pressed.connect(_on_test_select_p1)
	add_child(test_p1_button)
	test_p2_button = Button.new()
	test_p2_button.text = "P2"
	test_p2_button.position = Vector2(TEST_BOX_RECT.position.x + 70, TEST_BOX_RECT.position.y + 40)
	test_p2_button.size = Vector2(55, 28)
	test_p2_button.focus_mode = Control.FOCUS_NONE
	test_p2_button.visible = false
	test_p2_button.pressed.connect(_on_test_select_p2)
	add_child(test_p2_button)
	test_close_button = Button.new()
	test_close_button.text = "X"
	test_close_button.position = Vector2(TEST_BOX_RECT.end.x - 42, TEST_BOX_RECT.position.y + 40)
	test_close_button.size = Vector2(32, 28)
	test_close_button.focus_mode = Control.FOCUS_NONE
	test_close_button.visible = false
	test_close_button.pressed.connect(_close_test_mode)
	add_child(test_close_button)

	_add_label("BPM", Vector2(18, 62))
	bpm_edit = _add_line_edit(Vector2(58, 56), Vector2(78, 30), "132")
	bpm_edit.text_submitted.connect(_on_bpm_submitted)
	_add_label("Offset", Vector2(148, 62))
	offset_edit = _add_line_edit(Vector2(198, 56), Vector2(86, 30), "0.0")
	offset_edit.text_submitted.connect(_on_offset_submitted)
	_add_label("Go", Vector2(300, 62))
	seek_edit = _add_line_edit(Vector2(323, 56), Vector2(86, 30), "0.0")
	_add_button("Seek", Rect2(415, 56, 56, 30), _seek_from_field)

	_add_label("Type", Vector2(488, 62))
	type_menu = OptionButton.new()
	type_menu.position = Vector2(526, 56)
	type_menu.size = Vector2(92, 30)
	type_menu.focus_mode = Control.FOCUS_NONE
	for note_type in NOTE_TYPES:
		type_menu.add_item(note_type)
	add_child(type_menu)

	_add_label("Snap", Vector2(636, 62))
	snap_menu = OptionButton.new()
	snap_menu.position = Vector2(680, 56)
	snap_menu.size = Vector2(80, 30)
	snap_menu.focus_mode = Control.FOCUS_NONE
	for label in ["Off", "1/4", "1/8", "1/12", "1/16"]:
		snap_menu.add_item(label)
	snap_menu.select(snap_index)
	snap_menu.item_selected.connect(_on_snap_selected)
	add_child(snap_menu)
	_add_button("Delete Highlight", Rect2(784, 56, 150, 30), _delete_highlight_phase)
	mute_p1_toggle = CheckButton.new()
	mute_p1_toggle.text = "Mute P1"
	mute_p1_toggle.position = Vector2(950, 57)
	mute_p1_toggle.size = Vector2(100, 28)
	mute_p1_toggle.focus_mode = Control.FOCUS_NONE
	mute_p1_toggle.toggled.connect(_on_mute_p1_toggled)
	add_child(mute_p1_toggle)
	mute_p2_toggle = CheckButton.new()
	mute_p2_toggle.text = "Mute P2"
	mute_p2_toggle.position = Vector2(1058, 57)
	mute_p2_toggle.size = Vector2(100, 28)
	mute_p2_toggle.focus_mode = Control.FOCUS_NONE
	mute_p2_toggle.toggled.connect(_on_mute_p2_toggled)
	add_child(mute_p2_toggle)

	_add_label("Time", Vector2(18, 110))
	time_edit = _add_line_edit(Vector2(58, 104), Vector2(92, 30), "")
	_add_label("Lane", Vector2(160, 110))
	lane_edit = _add_line_edit(Vector2(200, 104), Vector2(52, 30), "")
	_add_label("Len", Vector2(264, 110))
	duration_edit = _add_line_edit(Vector2(296, 104), Vector2(80, 30), "")
	_add_label("Pitch", Vector2(388, 110))
	pitch_edit = _add_line_edit(Vector2(428, 104), Vector2(52, 30), "")
	_add_label("Mash", Vector2(492, 110))
	mash_edit = _add_line_edit(Vector2(532, 104), Vector2(52, 30), "")
	connect_toggle = CheckButton.new()
	connect_toggle.text = "Connect"
	connect_toggle.position = Vector2(598, 106)
	connect_toggle.size = Vector2(100, 28)
	connect_toggle.focus_mode = Control.FOCUS_NONE
	connect_toggle.toggled.connect(_on_connect_toggled)
	add_child(connect_toggle)
	_add_button("Apply", Rect2(712, 104, 62, 30), _apply_selected_fields)


func _add_button(label: String, rect: Rect2, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = label
	button.position = rect.position
	button.size = rect.size
	# 포커스를 가지면 Godot이 Space/Enter(ui_accept)를 버튼 클릭으로 가로채서
	# 우리 쪽 스페이스바 재생/정지 토글(_unhandled_input)이 아예 안 들어옴 -> 포커스 자체를 끈다.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	add_child(button)


func _add_label(label: String, position_value: Vector2) -> void:
	var control: Label = Label.new()
	control.text = label
	control.position = position_value
	control.size = Vector2(60, 24)
	add_child(control)


func _add_line_edit(position_value: Vector2, size_value: Vector2, value: String) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.text = value
	field.position = position_value
	field.size = size_value
	add_child(field)
	return field


func _refresh_chart_list() -> void:
	chart_paths.clear()
	chart_menu.clear()
	var directory: DirAccess = DirAccess.open(CHARTS_PATH)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json":
			chart_paths.append(CHARTS_PATH.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	chart_paths.sort()
	for path in chart_paths:
		chart_menu.add_item(path.get_file())


func _on_chart_selected(index: int) -> void:
	if index >= 0 and index < chart_paths.size():
		_load_chart(chart_paths[index])


func _load_chart(path: String) -> void:
	_pause_playback()
	var result: Dictionary = CHART_CODEC.load_chart(path)
	if not bool(result.get("ok", false)):
		status_text = "Load failed: %s" % String(result.get("error", "Unknown error"))
		push_error(status_text)
		queue_redraw()
		return
	var loaded_chart: Dictionary = result["chart"]
	var audio_path: String = String(loaded_chart["audioPath"])
	if not audio_path.begins_with(AUDIO_ROOT):
		status_text = "Load failed: audio path is outside res://audio/"
		push_error(status_text)
		queue_redraw()
		return
	var stream: AudioStream = load(audio_path)
	if stream == null:
		status_text = "Load failed: WAV could not be loaded"
		push_error(status_text)
		queue_redraw()
		return

	current_chart_path = path
	chart_data = loaded_chart.duplicate(true)
	notes = _duplicate_notes(chart_data["notes"])
	sections = _duplicate_notes(chart_data["sections"])
	phases = _duplicate_notes(chart_data.get("phases", []))
	bpm = float(chart_data["bpm"])
	chart_offset = float(chart_data["offset"])
	audio_player.stream = stream
	song_length = stream.get_length()
	playback_time = 0.0
	last_chart_time = -chart_offset
	view_start_time = 0.0
	dirty = false
	selected_indices.clear()
	undo_stack.clear()
	redo_stack.clear()
	bpm_edit.text = "%.3f" % bpm
	offset_edit.text = "%.4f" % chart_offset
	seek_edit.text = "0.0"
	_build_waveform_cache(stream)
	status_text = "Loaded %s (waveform %s)" % [path.get_file(), "ready" if waveform_ready else "unavailable"]
	queue_redraw()


func _duplicate_notes(source: Array) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for value in source:
		var data: Dictionary = value
		copy.append(data.duplicate(true))
	return copy


func _process(_delta: float) -> void:
	if is_playing:
		var previous_chart_time: float = last_chart_time
		playback_time = audio_player.get_playback_position()
		if playback_time >= song_length - 0.001:
			_stop_playback()
			queue_redraw()
			return
		var current_chart_time: float = _chart_time()
		if current_chart_time >= previous_chart_time:
			_play_notes_between(previous_chart_time, current_chart_time)
			if metronome_enabled:
				_play_metronome_between(previous_chart_time, current_chart_time)
		last_chart_time = current_chart_time
		_follow_playhead(current_chart_time)
		if recording and not _has_text_focus():
			for lane in range(LANE_COUNT):
				if Input.is_action_just_pressed(_lane_action(lane)):
					_record_lane(lane)
	queue_redraw()


func _lane_action(lane: int) -> String:
	return LANE_KEYS[lane]


func _chart_time() -> float:
	return playback_time - chart_offset


func _play_notes_between(from_time: float, to_time: float) -> void:
	for note in notes:
		var side: String = String(note["side"])
		if (side == "player" and mute_p1) or (side == "opponent" and mute_p2):
			continue
		var note_time: float = float(note["time"])
		if note_time > from_time and note_time <= to_time:
			_play_note_preview(String(note["type"]))


func _follow_playhead(chart_time: float) -> void:
	var visible_duration: float = _visible_duration()
	if chart_time < view_start_time or chart_time > view_start_time + visible_duration:
		view_start_time = clamp(chart_time - visible_duration * 0.35, 0.0, _max_view_start())


func _toggle_playback() -> void:
	if is_playing:
		_pause_playback()
	else:
		if audio_player.stream == null:
			return
		playback_time = clamp(playback_time, 0.0, max(song_length - 0.001, 0.0))
		last_chart_time = _chart_time()
		audio_player.play(playback_time)
		is_playing = true
		status_text = "Playing"


func _play_from_start() -> void:
	_stop_playback()
	_toggle_playback()


func _pause_playback() -> void:
	if is_playing:
		playback_time = audio_player.get_playback_position()
		last_chart_time = _chart_time()
		audio_player.stop()
		is_playing = false
		status_text = "Paused"


func _stop_playback() -> void:
	audio_player.stop()
	is_playing = false
	playback_time = 0.0
	last_chart_time = -chart_offset
	seek_edit.text = "0.0"
	status_text = "At start"


func _seek_from_field() -> void:
	var target: float = clamp(seek_edit.text.to_float(), 0.0, song_length)
	_seek(target)


func _seek(target: float) -> void:
	var resume: bool = is_playing
	if is_playing:
		audio_player.stop()
	playback_time = target
	last_chart_time = _chart_time()
	if resume and audio_player.stream != null:
		audio_player.play(playback_time)
		is_playing = true
	seek_edit.text = "%.3f" % playback_time


# 재생 헤드를 정확히 1박자 앞/뒤로 이동 (direction: -1=왼쪽, +1=오른쪽). 그리드/노트가 쓰는
# 것과 같은 chart-time 좌표계 기준으로 움직인 다음 playback_time으로 환산해서 _seek한다.
func _step_playhead_by_beat(direction: int) -> void:
	if bpm <= 0.0:
		return
	var beat_seconds: float = 60.0 / bpm
	var new_chart_time: float = clamp(_chart_time() + direction * beat_seconds, 0.0, song_length)
	var new_playback_time: float = clamp(new_chart_time + chart_offset, 0.0, song_length)
	_seek(new_playback_time)


func _on_record_toggled(enabled: bool) -> void:
	recording = enabled
	status_text = "Recording" if enabled else "Recording off"


func _on_box_select_toggled(enabled: bool) -> void:
	box_select_enabled = enabled
	status_text = "Box select on" if enabled else "Box select off"


func _on_metronome_toggled(enabled: bool) -> void:
	metronome_enabled = enabled
	status_text = "Metronome on" if enabled else "Metronome off"


func _on_mute_p1_toggled(enabled: bool) -> void:
	mute_p1 = enabled
	status_text = "P1 muted" if enabled else "P1 unmuted"


func _on_mute_p2_toggled(enabled: bool) -> void:
	mute_p2 = enabled
	status_text = "P2 muted" if enabled else "P2 unmuted"


# 테스트 박스 켜기/끄기. 켤 때 재생 중이 아니면 현재 재생 헤드 위치에서 바로 재생을 시작한다.
func _on_test_toggled(enabled: bool) -> void:
	test_mode_enabled = enabled
	test_p1_button.visible = enabled
	test_p2_button.visible = enabled
	test_close_button.visible = enabled
	test_hit_keys.clear()
	if enabled:
		if not is_playing and audio_player.stream != null:
			_toggle_playback()
		status_text = "Test mode: %s" % ("P1 (A S D F)" if test_selected_side == "player" else "P2 (K L ; ')")
	else:
		if is_playing:
			_pause_playback()
		status_text = "Test mode off"


func _close_test_mode() -> void:
	test_toggle.set_pressed_no_signal(false)
	_on_test_toggled(false)


func _on_test_select_p1() -> void:
	test_selected_side = "player"
	test_hit_keys.clear()
	status_text = "Test: P1 (A S D F)"


func _on_test_select_p2() -> void:
	test_selected_side = "opponent"
	test_hit_keys.clear()
	status_text = "Test: P2 (K L ; ')"


# 테스트 박스 안에서 실제 키를 눌렀을 때의 판정 — 채보(notes)는 절대 안 건드리고, 그냥
# 그 레인/사이드에서 가장 가까운 아직 안 친 노트를 "친 것"으로 표시하고 소리만 재생한다.
func _handle_test_input(lane: int, side: String) -> void:
	if side != test_selected_side:
		return
	var chart_time: float = _chart_time()
	var best_key: String = ""
	var best_type: String = "tap"
	var best_dt: float = TEST_HIT_WINDOW
	for note in notes:
		if String(note["side"]) != side or int(note["lane"]) != lane:
			continue
		var key: String = "%s_%d_%.6f" % [String(note["side"]), int(note["lane"]), float(note["time"])]
		if test_hit_keys.has(key):
			continue
		var dt: float = absf(float(note["time"]) - chart_time)
		if dt <= best_dt:
			best_dt = dt
			best_key = key
			best_type = String(note["type"])
	if best_key != "":
		test_hit_keys.append(best_key)
		_play_note_preview(best_type)


func _add_highlight_phase() -> void:
	if song_length <= 0.0:
		status_text = "Add highlight failed: no WAV loaded"
		return
	_begin_edit()
	var default_duration: float = 6.0
	var maximum_start: float = max(song_length - default_duration, 0.0)
	var start_time: float = clamp(_snap_time(_chart_time()), 0.0, maximum_start)
	var end_time: float = min(start_time + default_duration, song_length)
	var phase_id: String = "highlight_%d" % _next_highlight_number()
	phases.append({"id": phase_id, "type": "highlight", "start": start_time, "end": end_time})
	dirty = true
	status_text = "Added %s (drag its right edge to change length)" % phase_id


# 재생 헤드가 걸쳐 있는 하이라이트 구간을 지운다 (Add Highlight의 반대).
func _delete_highlight_phase() -> void:
	var current_time: float = _chart_time()
	var target_index: int = -1
	for index in range(phases.size()):
		var phase: Dictionary = phases[index]
		if String(phase.get("type", "")) != "highlight":
			continue
		if current_time >= float(phase["start"]) and current_time < float(phase["end"]):
			target_index = index
			break
	if target_index < 0:
		status_text = "Delete highlight failed: no highlight at playhead"
		return
	_begin_edit()
	var removed_id: String = String(phases[target_index].get("id", "highlight"))
	phases.remove_at(target_index)
	dirty = true
	status_text = "Deleted %s" % removed_id


func _next_highlight_number() -> int:
	var highest: int = 0
	for phase in phases:
		if String(phase.get("type", "")) != "highlight":
			continue
		var phase_id: String = String(phase.get("id", ""))
		if phase_id.begins_with("highlight_"):
			var suffix: String = phase_id.trim_prefix("highlight_")
			if suffix.is_valid_int():
				highest = max(highest, suffix.to_int())
	return highest + 1


func _record_lane(lane: int) -> void:
	_begin_edit()
	var recorded_time: float = max(0.0, playback_time - chart_offset)
	var note: Dictionary = _make_note(recorded_time, lane, "tap", "player")
	notes.append(note)
	_sort_notes()
	selected_indices.clear()
	selected_indices.append(notes.find(note))
	dirty = true
	status_text = "Recorded lane %d" % (lane + 1)
	_sync_selected_fields()


# 재생 중 실제 게임 키(ASDF/KL;')를 누른 "그 순간"에 탭 노트를 스냅 없이 정확한 타이밍으로 찍는다.
# 정지해도 notes 배열에 그대로 남고, Save를 눌러야 파일에 저장되며, 지우기 전까진 안 없어진다.
func _record_note_at_playhead(lane: int, side: String) -> void:
	_begin_edit()
	var precise_playback_time: float = audio_player.get_playback_position()
	var recorded_time: float = max(0.0, precise_playback_time - chart_offset)
	var note: Dictionary = {
		"time": recorded_time,
		"lane": lane,
		"side": side,
		"type": "tap",
		"duration": 0.0,
		"pitch": lane,
		"mash": 0,
		"connectNext": false,
	}
	notes.append(note)
	_sort_notes()
	selected_indices.clear()
	selected_indices.append(notes.find(note))
	dirty = true
	status_text = "Stamped %s lane %d @ %.3fs" % [("P1" if side == "player" else "P2"), lane + 1, recorded_time]
	_sync_selected_fields()


func _make_note(time_value: float, lane_value: int, note_type: String, side_value: String = "player") -> Dictionary:
	var duration: float = 0.0
	var mash: int = 0
	if note_type == "hold":
		duration = max(_snap_interval(), 0.25)
	elif note_type == "rapid":
		duration = max(_snap_interval(), 0.25)
		mash = 4
	return {
		"time": _snap_time(time_value),
		"lane": lane_value,
		"side": side_value,
		"type": note_type,
		"duration": duration,
		"pitch": lane_value,
		"mash": mash,
		"connectNext": false
	}


func _on_bpm_submitted(_text: String) -> void:
	var value: float = bpm_edit.text.to_float()
	if value > 0.0:
		bpm = value
		dirty = true
		status_text = "BPM updated"
	else:
		bpm_edit.text = "%.3f" % bpm


func _on_offset_submitted(_text: String) -> void:
	chart_offset = offset_edit.text.to_float()
	dirty = true
	status_text = "Offset updated"


func _on_snap_selected(index: int) -> void:
	snap_index = index


func _snap_interval() -> float:
	if snap_index <= 0 or bpm <= 0.0:
		return 0.0
	return (60.0 / bpm) * float(SNAP_BEATS[snap_index])


func _snap_time(time_value: float) -> float:
	var interval: float = _snap_interval()
	if interval <= 0.0:
		return max(time_value, 0.0)
	return max(round(time_value / interval) * interval, 0.0)


func _begin_edit() -> void:
	undo_stack.append(_history_snapshot())
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()


func _undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_history_snapshot())
	_restore_history(undo_stack.pop_back())
	selected_indices.clear()
	dirty = true
	status_text = "Undo"
	_sync_selected_fields()


func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_history_snapshot())
	_restore_history(redo_stack.pop_back())
	selected_indices.clear()
	dirty = true
	status_text = "Redo"
	_sync_selected_fields()


func _sort_notes() -> void:
	notes.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))


func _history_snapshot() -> Dictionary:
	return {"notes": notes.duplicate(true), "phases": phases.duplicate(true)}


func _restore_history(snapshot: Dictionary) -> void:
	notes = _duplicate_notes(snapshot.get("notes", []))
	phases = _duplicate_notes(snapshot.get("phases", []))


func _selected_primary_index() -> int:
	if selected_indices.is_empty():
		return -1
	return selected_indices[0]


func _sync_selected_fields() -> void:
	var index: int = _selected_primary_index()
	if index < 0 or index >= notes.size():
		time_edit.text = ""
		lane_edit.text = ""
		duration_edit.text = ""
		pitch_edit.text = ""
		mash_edit.text = ""
		connect_toggle.set_pressed_no_signal(false)
		return
	var note: Dictionary = notes[index]
	time_edit.text = "%.6f" % float(note["time"])
	lane_edit.text = str(note["lane"])
	duration_edit.text = "%.6f" % float(note["duration"])
	pitch_edit.text = str(note["pitch"])
	mash_edit.text = str(note["mash"])
	# set_pressed_no_signal: 여기서 상태만 반영하고 _on_connect_toggled를 다시 부르지 않는다
	# (안 그러면 노트 선택할 때마다 undo 스냅샷이 쌓임).
	connect_toggle.set_pressed_no_signal(bool(note["connectNext"]))
	var type_index: int = NOTE_TYPES.find(String(note["type"]))
	if type_index >= 0:
		type_menu.select(type_index)


func _apply_selected_fields() -> void:
	var index: int = _selected_primary_index()
	if index < 0 or index >= notes.size():
		return
	var new_time: float = max(time_edit.text.to_float(), 0.0)
	var new_lane: int = clampi(lane_edit.text.to_int(), 0, LANE_COUNT - 1)
	var new_duration: float = max(duration_edit.text.to_float(), 0.0)
	var new_pitch: int = clampi(pitch_edit.text.to_int(), 0, 5)
	var new_mash: int = max(mash_edit.text.to_int(), 0)
	var new_type: String = NOTE_TYPES[type_menu.selected]
	if new_type == "hold" and new_duration <= 0.0:
		new_duration = max(_snap_interval(), 0.01)
	if new_type == "rapid":
		new_duration = max(new_duration, max(_snap_interval(), 0.01))
		new_mash = max(new_mash, 1)
	_begin_edit()
	var note: Dictionary = notes[index]
	note["time"] = _snap_time(new_time)
	note["lane"] = new_lane
	note["duration"] = new_duration
	note["pitch"] = new_pitch
	note["mash"] = new_mash
	note["type"] = new_type
	note["connectNext"] = connect_toggle.button_pressed
	dirty = true
	_sort_notes()
	selected_indices.clear()
	selected_indices.append(notes.find(note))
	status_text = "Note updated"
	_sync_selected_fields()


# 1/2/3/4 단축키: 다음에 새로 찍을 노트 타입을 바꾸고, 지금 선택된 노트가 있으면
# 그 노트(들)의 타입도 바로 바꿔준다.
func _set_note_type_shortcut(type_index: int) -> void:
	if type_index < 0 or type_index >= NOTE_TYPES.size():
		return
	type_menu.select(type_index)
	var new_type: String = NOTE_TYPES[type_index]
	if selected_indices.is_empty():
		status_text = "Next note type: %s" % new_type
		return
	_begin_edit()
	for index in selected_indices:
		if index < 0 or index >= notes.size():
			continue
		var note: Dictionary = notes[index]
		note["type"] = new_type
		if new_type == "hold":
			if float(note["duration"]) <= 0.0:
				note["duration"] = max(_snap_interval(), 0.01)
		elif new_type == "rapid":
			if float(note["duration"]) <= 0.0:
				note["duration"] = max(_snap_interval(), 0.01)
			if int(note["mash"]) < 1:
				note["mash"] = 4
		else:
			note["duration"] = 0.0
			note["mash"] = 0
	dirty = true
	status_text = "Changed %d note(s) to %s" % [selected_indices.size(), new_type]
	_sync_selected_fields()


# Connect 체크박스는 이제 Apply를 안 눌러도 즉시 선택된 노트(들)에 적용된다.
func _on_connect_toggled(enabled: bool) -> void:
	if selected_indices.is_empty():
		return
	_begin_edit()
	for index in selected_indices:
		if index < 0 or index >= notes.size():
			continue
		notes[index]["connectNext"] = enabled
	dirty = true
	status_text = "Connect %s (%d note(s))" % ["on" if enabled else "off", selected_indices.size()]


func _save_chart() -> void:
	if current_chart_path.is_empty():
		status_text = "Save failed: no chart loaded"
		return
	_commit_chart_fields()
	chart_data["bpm"] = bpm
	chart_data["offset"] = chart_offset
	chart_data["laneCount"] = LANE_COUNT
	chart_data["notes"] = notes
	chart_data["sections"] = sections
	chart_data["phases"] = phases
	var validation_error: String = CHART_CODEC.validate_chart(chart_data)
	if not validation_error.is_empty():
		status_text = "Save failed: %s" % validation_error
		push_error(status_text)
		return
	if FileAccess.file_exists(current_chart_path):
		var original: String = FileAccess.get_file_as_string(current_chart_path)
		var absolute_backup_path: String = ProjectSettings.globalize_path(BACKUPS_PATH)
		DirAccess.make_dir_recursive_absolute(absolute_backup_path)
		var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		var backup_path: String = BACKUPS_PATH.path_join("%s_%s.json" % [current_chart_path.get_basename().get_file(), timestamp])
		var backup_file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
		if backup_file == null:
			status_text = "Save failed: backup could not be created"
			push_error(status_text)
			return
		backup_file.store_string(original)
	var file: FileAccess = FileAccess.open(current_chart_path, FileAccess.WRITE)
	if file == null:
		status_text = "Save failed: chart could not be opened"
		push_error(status_text)
		return
	file.store_string(JSON.stringify(chart_data, "\t"))
	dirty = false
	status_text = "Saved with backup"


func _commit_chart_fields() -> void:
	var entered_bpm: float = bpm_edit.text.to_float()
	if entered_bpm > 0.0:
		bpm = entered_bpm
	var entered_offset: float = offset_edit.text.to_float()
	chart_offset = entered_offset


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not _has_text_focus():
			_toggle_playback()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_DELETE and not _has_text_focus():
			_delete_selected()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_D and not _has_text_focus():
			_delete_selected()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_C and not _has_text_focus():
			_copy_selected()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_V and not _has_text_focus():
			_paste_notes()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Z and not _has_text_focus():
			_undo()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Y and not _has_text_focus():
			_redo()
			get_viewport().set_input_as_handled()
			return

		# 1/2/3/4 = tap/hold/rapid/slur. 선택된 노트가 있으면 그 노트(들)의 타입도 바로 바꾼다.
		if event.keycode == KEY_1 and not _has_text_focus():
			_set_note_type_shortcut(0)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_2 and not _has_text_focus():
			_set_note_type_shortcut(1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_3 and not _has_text_focus():
			_set_note_type_shortcut(2)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_4 and not _has_text_focus():
			_set_note_type_shortcut(3)
			get_viewport().set_input_as_handled()
			return

	# 재생 중 실제 게임 키(ASDF=P1, KL;'=P2)를 누르면: 테스트 모드면 테스트 박스 판정,
	# 아니면 그 순간 타이밍에 탭 노트를 바로 찍는다(정지해도 남고 Save해야 저장됨).
	if event is InputEventKey and event.pressed and not event.echo and not _has_text_focus() and is_playing:
		var p1_lane: int = REC_KEYCODES_P1.find(event.keycode)
		if p1_lane >= 0:
			if test_mode_enabled:
				_handle_test_input(p1_lane, "player")
			else:
				_record_note_at_playhead(p1_lane, "player")
			get_viewport().set_input_as_handled()
			return
		var p2_lane: int = REC_KEYCODES_P2.find(event.keycode)
		if p2_lane >= 0:
			if test_mode_enabled:
				_handle_test_input(p2_lane, "opponent")
			else:
				_record_note_at_playhead(p2_lane, "opponent")
			get_viewport().set_input_as_handled()
			return

	# 좌/우 화살표로 재생 헤드를 1박자씩 이동. echo(키 누르고 있기)도 허용해서 계속 누르면
	# 계속 이동한다. 녹음 모드에서는 좌/우가 원래 레인 입력(note_left/note_right)이라 건드리지 않는다.
	if event is InputEventKey and event.pressed and not _has_text_focus() and not recording:
		if event.keycode == KEY_LEFT:
			_step_playhead_by_beat(-1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_RIGHT:
			_step_playhead_by_beat(1)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and drag_mode == "playhead":
		_finish_timeline_drag()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and drag_mode == "phase_resize":
		_finish_timeline_drag()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and drag_mode == "scroll":
		drag_mode = ""
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and _playhead_handle_rect().grow(4.0).has_point(event.position):
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			resume_after_scrub = is_playing
			if is_playing:
				audio_player.stop()
				is_playing = false
			drag_mode = "playhead"
			_set_playhead_from_x(event.position.x)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and H_SCROLL_RECT.grow(4.0).has_point(event.position):
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_mode = "scroll"
				_set_view_start_from_scroll(event.position.x)
			else:
				drag_mode = ""
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and TIMELINE_RECT.grow(4.0).has_point(event.position):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position.x, 1.18)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position.x, 1.0 / 1.18)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				drag_mode = "pan"
				drag_start_mouse = event.position
				drag_start_time = view_start_time
			else:
				drag_mode = ""
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var highlight_index: int = _highlight_end_handle_at(event.position)
				if highlight_index >= 0:
					phase_resize_index = highlight_index
					drag_mode = "phase_resize"
					_begin_edit()
					status_text = "Drag to resize highlight"
				else:
					_handle_timeline_press(event.position, event.shift_pressed)
			else:
				_finish_timeline_drag()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and not drag_mode.is_empty():
		_handle_timeline_drag(event.position)
		get_viewport().set_input_as_handled()


func _handle_timeline_press(mouse: Vector2, additive: bool) -> void:
	click_delete_index = -1
	press_moved = false
	if mouse.y <= TIMELINE_RECT.position.y + RULER_HEIGHT:
		_seek(_time_from_x(mouse.x))
		return
	if box_select_enabled and not selected_indices.is_empty() and _selection_bounds_rect().grow(6.0).has_point(mouse):
		_begin_move_selection(mouse)
		return
	var hit_index: int = _find_note_at(mouse)
	if hit_index >= 0:
		if additive:
			if selected_indices.has(hit_index):
				selected_indices.erase(hit_index)
			else:
				selected_indices.append(hit_index)
		else:
			# 이미 선택돼 있던 블록을 다시 클릭한 경우 -> 드래그 없이 손을 떼면 삭제 후보.
			# 처음 클릭(아직 선택 안 됨)은 그냥 선택만 하고 삭제하지 않는다.
			if selected_indices.has(hit_index):
				click_delete_index = hit_index
			else:
				selected_indices.clear()
				selected_indices.append(hit_index)
		_sync_selected_fields()
		if _is_hold_resize_handle(hit_index, mouse):
			drag_start_mouse = mouse
			drag_start_time = _time_from_x(mouse.x)
			drag_mode = "resize"
			_begin_edit()
		else:
			_begin_move_selection(mouse)
		return

	if box_select_enabled:
		if additive:
			drag_original_selection = selected_indices.duplicate()
		else:
			drag_original_selection.clear()
		if not additive:
			selected_indices.clear()
		selection_rect = Rect2(mouse, Vector2.ZERO)
		drag_start_mouse = mouse
		drag_mode = "select"
		return

	if not additive:
		_begin_edit()
		var new_row: int = _editor_row_from_y(mouse.y)
		# 행 0-3="1P"는 Main.gd 기준 실제 P1(side 0)에 해당하는 "player" 문자열을 써야 한다.
		# (Main.gd: side=="player" -> P1(0), 그 외("opponent") -> P2(1))
		var new_side: String = "player" if new_row < LANE_COUNT else "opponent"
		var new_note: Dictionary = _make_note(_time_from_x(mouse.x), new_row % LANE_COUNT, NOTE_TYPES[type_menu.selected], new_side)
		notes.append(new_note)
		_sort_notes()
		selected_indices.clear()
		selected_indices.append(notes.find(new_note))
		dirty = true
		status_text = "Created %s note" % String(new_note["type"])
		_sync_selected_fields()
		return

	drag_original_selection = selected_indices.duplicate()
	selection_rect = Rect2(mouse, Vector2.ZERO)
	drag_start_mouse = mouse
	drag_mode = "select"


func _begin_move_selection(mouse: Vector2) -> void:
	drag_start_mouse = mouse
	drag_start_time = _time_from_x(mouse.x)
	drag_start_row = _editor_row_from_y(mouse.y)
	drag_original_notes = _duplicate_notes(notes)
	drag_original_selection = selected_indices.duplicate()
	drag_selected_notes.clear()
	for selected_index in drag_original_selection:
		if selected_index >= 0 and selected_index < notes.size():
			drag_selected_notes.append(notes[selected_index])
	drag_mode = "move"
	_begin_edit()


func _handle_timeline_drag(mouse: Vector2) -> void:
	if drag_mode == "playhead":
		_set_playhead_from_x(mouse.x)
		return
	if drag_mode == "scroll":
		_set_view_start_from_scroll(mouse.x)
		return
	if drag_mode == "pan":
		view_start_time = clamp(drag_start_time - (mouse.x - drag_start_mouse.x) / pixels_per_second, 0.0, _max_view_start())
		return
	if drag_mode == "phase_resize":
		if phase_resize_index >= 0 and phase_resize_index < phases.size():
			var phase: Dictionary = phases[phase_resize_index]
			var minimum_length: float = max(_snap_interval(), 0.01)
			var maximum_end: float = max(song_length, float(phase["start"]) + minimum_length)
			var end_time: float = clamp(_snap_time(_time_from_x(mouse.x)), float(phase["start"]) + minimum_length, maximum_end)
			phase["end"] = end_time
			dirty = true
		return
	if drag_mode == "select":
		selection_rect = Rect2(drag_start_mouse, mouse - drag_start_mouse).abs()
		selected_indices = drag_original_selection.duplicate()
		for index in range(notes.size()):
			if selection_rect.intersects(_note_rect(notes[index])) and not selected_indices.has(index):
				selected_indices.append(index)
		_sync_selected_fields()
		return
	if drag_mode == "resize":
		var index: int = _selected_primary_index()
		if index >= 0:
			var note: Dictionary = notes[index]
			var end_time: float = max(_time_from_x(mouse.x), float(note["time"]) + 0.01)
			note["duration"] = max(_snap_time(end_time) - float(note["time"]), max(_snap_interval(), 0.01))
			dirty = true
			_sync_selected_fields()
		return
	if drag_mode == "move":
		if mouse.distance_to(drag_start_mouse) > 3.0:
			press_moved = true
		var time_delta: float = _time_from_x(mouse.x) - drag_start_time
		var row_delta: int = _editor_row_from_y(mouse.y) - drag_start_row
		for selected_index in drag_original_selection:
			if selected_index < 0 or selected_index >= notes.size():
				continue
			var original: Dictionary = drag_original_notes[selected_index]
			var note: Dictionary = notes[selected_index]
			var original_row: int = _editor_row_for_note(original)
			var new_row: int = clampi(original_row + row_delta, 0, EDITOR_ROW_COUNT - 1)
			note["time"] = _snap_time(max(0.0, float(original["time"]) + time_delta))
			note["lane"] = new_row % LANE_COUNT
			note["side"] = "player" if new_row < LANE_COUNT else "opponent"
		dirty = true
		_sync_selected_fields()


func _finish_timeline_drag() -> void:
	if drag_mode == "playhead":
		last_chart_time = _chart_time()
		if resume_after_scrub and audio_player.stream != null:
			audio_player.play(playback_time)
			is_playing = true
			status_text = "Playing from %.3f" % playback_time
		else:
			status_text = "Ready at %.3f" % playback_time
		resume_after_scrub = false
		drag_mode = ""
		return
	if drag_mode == "phase_resize":
		phase_resize_index = -1
		drag_mode = ""
		status_text = "Highlight length updated"
		return
	if drag_mode == "move":
		if click_delete_index >= 0 and not press_moved:
			# 이미 선택돼 있던 블록을 드래그 없이 다시 클릭 -> 삭제 (undo 스냅샷은 press 시점에 이미 저장됨)
			if click_delete_index < notes.size():
				notes.remove_at(click_delete_index)
			selected_indices.clear()
			dirty = true
			status_text = "Deleted note"
			_sync_selected_fields()
			click_delete_index = -1
			press_moved = false
			drag_mode = ""
			selection_rect = Rect2()
			return
		_sort_notes()
		selected_indices.clear()
		for selected_note in drag_selected_notes:
			var index: int = notes.find(selected_note)
			if index >= 0 and not selected_indices.has(index):
				selected_indices.append(index)
		_sync_selected_fields()
	click_delete_index = -1
	press_moved = false
	drag_mode = ""
	selection_rect = Rect2()


func _find_note_at(mouse: Vector2) -> int:
	for index in range(notes.size() - 1, -1, -1):
		if _note_rect(notes[index]).grow(4.0).has_point(mouse):
			return index
	return -1


func _selection_bounds_rect() -> Rect2:
	var has_bounds: bool = false
	var bounds: Rect2 = Rect2()
	for index in selected_indices:
		if index < 0 or index >= notes.size():
			continue
		var note_bounds: Rect2 = _note_rect(notes[index])
		if has_bounds:
			bounds = bounds.merge(note_bounds)
		else:
			bounds = note_bounds
			has_bounds = true
	return bounds


func _is_hold_resize_handle(index: int, mouse: Vector2) -> bool:
	if index < 0 or index >= notes.size():
		return false
	var note: Dictionary = notes[index]
	if String(note["type"]) != "hold":
		return false
	var rect: Rect2 = _note_rect(note)
	return mouse.x >= rect.end.x - 10.0


func _delete_selected() -> void:
	if selected_indices.is_empty():
		return
	_begin_edit()
	drag_mode = ""
	click_delete_index = -1
	press_moved = false
	selection_rect = Rect2()
	selected_indices.sort()
	selected_indices.reverse()
	for index in selected_indices:
		if index >= 0 and index < notes.size():
			notes.remove_at(index)
	selected_indices.clear()
	dirty = true
	status_text = "Deleted notes"
	_sync_selected_fields()
	queue_redraw()


func _copy_selected() -> void:
	clipboard.clear()
	for index in selected_indices:
		if index >= 0 and index < notes.size():
			clipboard.append(notes[index].duplicate(true))
	status_text = "Copied %d notes" % clipboard.size()


func _paste_notes() -> void:
	if clipboard.is_empty():
		return
	_begin_edit()
	var first_time: float = float(clipboard[0]["time"])
	for source in clipboard:
		var note: Dictionary = source.duplicate(true)
		note["time"] = _snap_time(playback_time + (float(note["time"]) - first_time))
		notes.append(note)
	_sort_notes()
	selected_indices.clear()
	for note in clipboard:
		var pasted_time: float = _snap_time(playback_time + (float(note["time"]) - first_time))
		for index in range(notes.size()):
			if float(notes[index]["time"]) == pasted_time and int(notes[index]["lane"]) == int(note["lane"]):
				selected_indices.append(index)
				break
	dirty = true
	status_text = "Pasted %d notes" % clipboard.size()
	_sync_selected_fields()


func _zoom_at(mouse_x: float, multiplier: float) -> void:
	var anchored_time: float = _time_from_x(mouse_x)
	pixels_per_second = clamp(pixels_per_second * multiplier, 40.0, 900.0)
	view_start_time = clamp(anchored_time - (mouse_x - TIMELINE_RECT.position.x) / pixels_per_second, 0.0, _max_view_start())


func _visible_duration() -> float:
	return TIMELINE_RECT.size.x / pixels_per_second


func _max_view_start() -> float:
	return max(song_length - _visible_duration(), 0.0)


func _scroll_thumb_rect() -> Rect2:
	if song_length <= 0.0:
		return Rect2(H_SCROLL_RECT.position.x + 2.0, H_SCROLL_RECT.position.y + 4.0, H_SCROLL_RECT.size.x - 4.0, H_SCROLL_RECT.size.y - 8.0)
	var visible_ratio: float = min(_visible_duration() / song_length, 1.0)
	var thumb_width: float = clamp(H_SCROLL_RECT.size.x * visible_ratio, 48.0, H_SCROLL_RECT.size.x)
	var max_start: float = _max_view_start()
	var ratio: float = 0.0 if max_start <= 0.0 else view_start_time / max_start
	var x: float = H_SCROLL_RECT.position.x + ratio * (H_SCROLL_RECT.size.x - thumb_width)
	return Rect2(x, H_SCROLL_RECT.position.y + 4.0, thumb_width, H_SCROLL_RECT.size.y - 8.0)


func _set_view_start_from_scroll(mouse_x: float) -> void:
	var thumb: Rect2 = _scroll_thumb_rect()
	var usable_width: float = max(H_SCROLL_RECT.size.x - thumb.size.x, 1.0)
	var ratio: float = clamp((mouse_x - H_SCROLL_RECT.position.x - thumb.size.x * 0.5) / usable_width, 0.0, 1.0)
	view_start_time = ratio * _max_view_start()


func _time_from_x(x: float) -> float:
	return max(view_start_time + (x - TIMELINE_RECT.position.x) / pixels_per_second, 0.0)


func _set_playhead_from_x(x: float) -> void:
	var chart_time: float = clamp(_time_from_x(x), 0.0, song_length)
	playback_time = clamp(chart_time + chart_offset, 0.0, song_length)
	last_chart_time = _chart_time()
	seek_edit.text = "%.3f" % playback_time


func _playhead_handle_rect() -> Rect2:
	var x: float = _x_from_time(_chart_time())
	return Rect2(x - 11.0, TIMELINE_RECT.position.y - 15.0, 22.0, 15.0)


func _x_from_time(time_value: float) -> float:
	return TIMELINE_RECT.position.x + (time_value - view_start_time) * pixels_per_second


func _lane_from_y(y: float) -> int:
	return _editor_row_from_y(y) % LANE_COUNT


func _editor_row_from_y(y: float) -> int:
	var lane_height: float = (TIMELINE_RECT.size.y - RULER_HEIGHT) / EDITOR_ROW_COUNT
	return clampi(int((y - TIMELINE_RECT.position.y - RULER_HEIGHT) / lane_height), 0, EDITOR_ROW_COUNT - 1)


func _editor_row_for_note(note: Dictionary) -> int:
	var lane: int = int(note["lane"])
	# Main.gd 기준: side=="player" -> P1(row 0-3, "1P"), 그 외("opponent") -> P2(row 4-7, "2P")
	return lane if String(note["side"]) == "player" else lane + LANE_COUNT


func _note_rect(note: Dictionary) -> Rect2:
	var lane_height: float = (TIMELINE_RECT.size.y - RULER_HEIGHT) / EDITOR_ROW_COUNT
	var x: float = _x_from_time(float(note["time"]))
	var y: float = TIMELINE_RECT.position.y + RULER_HEIGHT + _editor_row_for_note(note) * lane_height + 8.0
	var width: float = 16.0
	if String(note["type"]) == "hold":
		width = max(float(note["duration"]) * pixels_per_second, 16.0)
	return Rect2(x - 8.0, y, width, lane_height - 16.0)


func _has_text_focus() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused is LineEdit


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("11131a"))
	draw_rect(Rect2(0, 146, 1280, 30), Color("1b202b"))
	draw_string(font, Vector2(18, 167), "Chart Editor   %s" % ("UNSAVED" if dirty else "Saved"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd76b") if dirty else Color("9ee6c8"))
	draw_string(font, Vector2(350, 167), "Time %.3f / %.3f   BPM %.3f   Notes %d   Phases %d" % [playback_time, song_length, bpm, notes.size(), phases.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d9dfeb"))
	draw_string(font, Vector2(930, 167), status_text, HORIZONTAL_ALIGNMENT_LEFT, 300, 14, Color("a9b2c5"))

	_draw_timeline()
	if test_mode_enabled:
		_draw_test_box()


func _draw_timeline() -> void:
	draw_rect(TIMELINE_RECT, Color("171c27"))
	_draw_waveform()
	draw_rect(Rect2(TIMELINE_RECT.position, Vector2(TIMELINE_RECT.size.x, RULER_HEIGHT)), Color("242b38"))
	var lane_height: float = (TIMELINE_RECT.size.y - RULER_HEIGHT) / EDITOR_ROW_COUNT
	for row in range(EDITOR_ROW_COUNT):
		var lane: int = row % LANE_COUNT
		var is_player_row: bool = row < LANE_COUNT
		var lane_rect: Rect2 = Rect2(TIMELINE_RECT.position.x, TIMELINE_RECT.position.y + RULER_HEIGHT + row * lane_height, TIMELINE_RECT.size.x, lane_height)
		var lane_color: Color = LANE_COLORS[lane]
		var fill_color: Color = lane_color if is_player_row else lane_color.darkened(0.35)
		draw_rect(lane_rect, Color(fill_color, 0.08))
		draw_line(Vector2(lane_rect.position.x, lane_rect.position.y), Vector2(lane_rect.end.x, lane_rect.position.y), Color("384151"), 1.0)
		draw_string(font, Vector2(18, lane_rect.position.y + lane_height * 0.62), "%s LANE %d" % ["1P" if is_player_row else "2P", lane + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fill_color)
		if row == LANE_COUNT - 1:
			draw_line(Vector2(TIMELINE_RECT.position.x, lane_rect.end.y), Vector2(TIMELINE_RECT.end.x, lane_rect.end.y), Color("d9dfeb", 0.75), 2.0)

	_draw_sections()
	_draw_phases()
	_draw_grid()
	_draw_slur_connections()
	for index in range(notes.size()):
		_draw_note(notes[index], selected_indices.has(index))
	if box_select_enabled and not selected_indices.is_empty():
		_draw_selection_net(_selection_bounds_rect().grow(6.0), Color("a9c7ff", 0.85))
	if drag_mode == "select":
		_draw_selection_net(selection_rect, Color("d4e2ff", 0.95))
	var playhead_x: float = _x_from_time(_chart_time())
	if playhead_x >= TIMELINE_RECT.position.x and playhead_x <= TIMELINE_RECT.end.x:
		draw_line(Vector2(playhead_x, TIMELINE_RECT.position.y), Vector2(playhead_x, TIMELINE_RECT.end.y), Color("ff6b6b"), 2.0)
		var arrow: PackedVector2Array = PackedVector2Array([Vector2(playhead_x - 10.0, TIMELINE_RECT.position.y - 14.0), Vector2(playhead_x + 10.0, TIMELINE_RECT.position.y - 14.0), Vector2(playhead_x, TIMELINE_RECT.position.y - 1.0)])
		draw_colored_polygon(arrow, Color("ff6b6b"))
		draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color("ffd1d1"), 1.0)
	draw_rect(TIMELINE_RECT, Color("657089"), false, 1.0)
	_draw_horizontal_scrollbar()


func _draw_selection_net(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	draw_rect(rect, Color(color, 0.10))
	draw_rect(rect, color, false, 2.0)
	var step: float = 18.0
	var x: float = rect.position.x + step
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(color, 0.22), 1.0)
		x += step
	var y: float = rect.position.y + step
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(color, 0.22), 1.0)
		y += step


func _draw_horizontal_scrollbar() -> void:
	draw_string(font, Vector2(H_SCROLL_RECT.position.x, H_SCROLL_RECT.position.y - 6.0), "Timeline %.2f - %.2f / %.2f" % [view_start_time, min(view_start_time + _visible_duration(), song_length), song_length], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9da8bb"))
	draw_rect(H_SCROLL_RECT, Color("202735"))
	var thumb: Rect2 = _scroll_thumb_rect()
	draw_rect(thumb, Color("6f8bc0"))
	draw_rect(thumb, Color("bdd3ff"), false, 1.0)


func _draw_sections() -> void:
	for section in sections:
		var start_x: float = _x_from_time(float(section["startTime"]))
		var end_x: float = _x_from_time(float(section["endTime"]))
		if end_x < TIMELINE_RECT.position.x or start_x > TIMELINE_RECT.end.x:
			continue
		var color: Color = Color("c65b86")
		if String(section["type"]) == "player":
			color = Color("48a6a2")
		elif String(section["type"]) == "ensemble":
			color = Color("d9b24a")
		draw_rect(Rect2(max(start_x, TIMELINE_RECT.position.x), TIMELINE_RECT.position.y + RULER_HEIGHT, min(end_x, TIMELINE_RECT.end.x) - max(start_x, TIMELINE_RECT.position.x), TIMELINE_RECT.size.y - RULER_HEIGHT), Color(color, 0.035))


func _draw_phases() -> void:
	for phase_index in range(phases.size()):
		var phase: Dictionary = phases[phase_index]
		var start_x: float = _x_from_time(float(phase["start"]))
		var end_x: float = _x_from_time(float(phase["end"]))
		if end_x < TIMELINE_RECT.position.x or start_x > TIMELINE_RECT.end.x:
			continue
		var phase_type: String = String(phase["type"])
		var color: Color = Color("657089")
		if phase_type == "normal":
			color = Color("6f8bc0")
		elif phase_type == "highlight":
			color = Color("f06ea8")
		var visible_start: float = max(start_x, TIMELINE_RECT.position.x)
		var visible_end: float = min(end_x, TIMELINE_RECT.end.x)
		var phase_rect: Rect2 = Rect2(visible_start, TIMELINE_RECT.position.y + RULER_HEIGHT, visible_end - visible_start, TIMELINE_RECT.size.y - RULER_HEIGHT)
		draw_rect(phase_rect, Color(color, 0.11 if phase_type == "highlight" else 0.045))
		draw_rect(Rect2(visible_start, TIMELINE_RECT.position.y + 3.0, phase_rect.size.x, 5.0), Color(color, 0.9))
		if phase_type == "highlight":
			draw_string(font, Vector2(visible_start + 5.0, TIMELINE_RECT.position.y + 24.0), "HIGHLIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd7e8"))
			if end_x >= TIMELINE_RECT.position.x and end_x <= TIMELINE_RECT.end.x:
				var handle: Rect2 = _highlight_end_handle_rect(phase_index)
				draw_rect(handle, Color("ffd6e7"))
				draw_rect(handle, Color("ff79b5"), false, 1.0)


func _highlight_end_handle_rect(phase_index: int) -> Rect2:
	if phase_index < 0 or phase_index >= phases.size():
		return Rect2()
	var phase: Dictionary = phases[phase_index]
	var x: float = _x_from_time(float(phase["end"]))
	return Rect2(x - 4.0, TIMELINE_RECT.position.y, 8.0, TIMELINE_RECT.size.y)


func _highlight_end_handle_at(mouse: Vector2) -> int:
	for phase_index in range(phases.size() - 1, -1, -1):
		var phase: Dictionary = phases[phase_index]
		if String(phase.get("type", "")) != "highlight":
			continue
		if _highlight_end_handle_rect(phase_index).grow(4.0).has_point(mouse):
			return phase_index
	return -1


# 8개 레인/그리드/노트 뒤에 깔리는 반투명 파형. 곡 로드시 만든 waveform_min/max 캐시를
# 화면 픽셀 폭으로 눌러 담은 waveform_draw_min/max(스크롤·줌 바뀔 때만 갱신)로 그린다.
func _draw_waveform() -> void:
	if not waveform_ready:
		return
	_ensure_waveform_draw_cache()
	var width: int = waveform_draw_min.size()
	if width == 0:
		return
	var top: float = TIMELINE_RECT.position.y + RULER_HEIGHT
	var bottom: float = TIMELINE_RECT.end.y
	var mid: float = (top + bottom) * 0.5
	var half_height: float = (bottom - top) * 0.5
	var color: Color = Color(0.93, 0.95, 0.98, 0.24)
	for x in range(width):
		var col_min: float = waveform_draw_min[x]
		var col_max: float = waveform_draw_max[x]
		var y_top: float = mid - col_max * half_height
		var y_bottom: float = mid - col_min * half_height
		if y_bottom - y_top < 1.0:
			y_top -= 0.5
			y_bottom += 0.5
		draw_line(Vector2(TIMELINE_RECT.position.x + x, y_top), Vector2(TIMELINE_RECT.position.x + x, y_bottom), color, 1.0)


func _draw_grid() -> void:
	if bpm <= 0.0:
		return
	var beat_seconds: float = 60.0 / bpm
	var first_beat: int = int(floor(view_start_time / beat_seconds))
	var last_time: float = _time_from_x(TIMELINE_RECT.end.x)
	var last_beat: int = int(ceil(last_time / beat_seconds))
	for beat_index in range(int(first_beat), int(last_beat) + 1):
		var beat_time: float = beat_index * beat_seconds
		var x: float = _x_from_time(beat_time)
		var beat_in_bar: int = beat_index % 4
		var is_bar: bool = beat_in_bar == 0
		# 마디 경계는 굵고 밝게, 마디 안의 1/2/3/4박은 또렷이 보이도록 채워서 그린다.
		var color: Color = Color("9aa6bd", 0.85) if is_bar else Color("75829b", 0.5)
		draw_line(Vector2(x, TIMELINE_RECT.position.y), Vector2(x, TIMELINE_RECT.end.y), color, 2.0 if is_bar else 1.0)
		if is_bar:
			draw_string(font, Vector2(x + 4, TIMELINE_RECT.position.y + 22), "%d" % (beat_index / 4 + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b9c2d3"))
		else:
			draw_string(font, Vector2(x + 3, TIMELINE_RECT.position.y + 22), "%d" % (beat_in_bar + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("828da3"))


# connectNext로 이어지는 슬러 체인에서 이 노트 "다음"에 오는 실제 슬러 노트를 찾는다
# (같은 side, 이 노트보다 시간이 늦은 슬러 노트 중 가장 가까운 것). Main.gd의 _find_next_slur와 동일한 규칙.
func _find_next_slur_editor(note: Dictionary) -> Dictionary:
	var candidate: Dictionary = {}
	var candidate_time: float = 0.0
	var note_time: float = float(note["time"])
	var note_side: String = String(note["side"])
	for other in notes:
		if other == note:
			continue
		if String(other["side"]) != note_side or String(other["type"]) != "slur":
			continue
		var other_time: float = float(other["time"])
		if other_time <= note_time:
			continue
		if candidate.is_empty() or other_time < candidate_time:
			candidate = other
			candidate_time = other_time
	return candidate


# connectNext=true인 슬러 노트마다 실제로 이어지는 다음 슬러 노트까지 불투명한 선을 그린다.
# 노트 박스들보다 먼저 그려서 박스가 선 끝을 자연스럽게 덮게 한다.
func _draw_slur_connections() -> void:
	for note in notes:
		if String(note["type"]) != "slur" or not bool(note["connectNext"]):
			continue
		var next_note: Dictionary = _find_next_slur_editor(note)
		if next_note.is_empty():
			continue
		var rect_a: Rect2 = _note_rect(note)
		var rect_b: Rect2 = _note_rect(next_note)
		if rect_a.end.x < TIMELINE_RECT.position.x and rect_b.end.x < TIMELINE_RECT.position.x:
			continue
		if rect_a.position.x > TIMELINE_RECT.end.x and rect_b.position.x > TIMELINE_RECT.end.x:
			continue
		var from: Vector2 = rect_a.position + rect_a.size * 0.5
		var to: Vector2 = rect_b.position + rect_b.size * 0.5
		# 연결선은 레인 색과 안 겹치게 중립색(크림색)으로 — 레인 정체성은 노트 박스 색이 계속 담당
		draw_line(from, to, Color("f2e9d0", 0.9), 4.0)


func _draw_note(note: Dictionary, selected: bool) -> void:
	var rect: Rect2 = _note_rect(note)
	if rect.end.x < TIMELINE_RECT.position.x or rect.position.x > TIMELINE_RECT.end.x:
		return
	var lane_color: Color = LANE_COLORS[int(note["lane"])]
	var note_type: String = String(note["type"])
	# 레인 색을 그대로 쓴다 — 타입은 색을 바꾸는 게 아니라 라벨/표식(S, x숫자, 홀드 노치)으로만 구분한다.
	var color: Color = lane_color
	draw_rect(rect, Color(color, 0.76))
	draw_rect(rect, Color.WHITE if selected else color.lightened(0.25), false, 2.0 if selected else 1.0)
	if note_type == "hold":
		draw_rect(Rect2(rect.end.x - 6.0, rect.position.y, 6.0, rect.size.y), Color("f2e9d0"))
	elif note_type == "rapid":
		draw_string(font, Vector2(rect.position.x + 3, rect.position.y + rect.size.y * 0.58), "x%d" % int(note["mash"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("16110b"))
	elif note_type == "slur":
		draw_string(font, Vector2(rect.position.x + 3, rect.position.y + rect.size.y * 0.58), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


# 채보 에디터 안에서 바로 미리 쳐볼 수 있는 작은 미리듣기 박스. 실제 notes 배열은 절대
# 건드리지 않고, 화면에 떠서 재생 위치에 맞춰 노트가 리셉터 쪽으로 내려올 뿐이다.
func _draw_test_box() -> void:
	draw_rect(TEST_BOX_RECT, Color("0c0e16", 0.97))
	draw_rect(TEST_BOX_RECT, Color("6f8bc0"), false, 2.0)
	var label: String = "TEST - %s" % ("P1 (A S D F)" if test_selected_side == "player" else "P2 (K L ; ')")
	draw_string(font, Vector2(TEST_BOX_RECT.position.x + 10, TEST_BOX_RECT.position.y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d9dfeb"))

	var receptor_y: float = TEST_BOX_RECT.end.y - 50.0
	draw_line(Vector2(TEST_BOX_RECT.position.x + 6, receptor_y), Vector2(TEST_BOX_RECT.end.x - 6, receptor_y), Color("657089"), 1.0)
	for lane in range(4):
		var lx: float = TEST_LANE_X[lane]
		draw_rect(Rect2(lx - 14, receptor_y - 14, 28, 28), LANE_COLORS[lane].darkened(0.5), false, 2.0)

	var chart_time: float = _chart_time()
	for note in notes:
		if String(note["side"]) != test_selected_side:
			continue
		var lane: int = int(note["lane"])
		if lane < 0 or lane >= 4:
			continue
		var key: String = "%s_%d_%.6f" % [String(note["side"]), lane, float(note["time"])]
		if test_hit_keys.has(key):
			continue
		var note_time: float = float(note["time"])
		var ny: float = receptor_y - (note_time - chart_time) * TEST_SCROLL
		var lx: float = TEST_LANE_X[lane]
		var col: Color = LANE_COLORS[lane]
		if String(note["type"]) == "hold":
			var end_time: float = note_time + float(note["duration"])
			var ny_end: float = receptor_y - (end_time - chart_time) * TEST_SCROLL
			var top: float = min(ny, ny_end)
			var bottom: float = max(ny, ny_end)
			if bottom < TEST_LANE_TOP or top > TEST_BOX_RECT.end.y:
				continue
			draw_rect(Rect2(lx - 5, top, 10, bottom - top), Color(col, 0.5))
		if ny < TEST_LANE_TOP or ny > TEST_BOX_RECT.end.y:
			continue
		draw_rect(Rect2(lx - 12, ny - 12, 24, 24), col)
