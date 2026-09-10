extends Node2D
# ============================================================
#  2-player co-op rhythm RPG prototype (Godot 4)  — v2 뼈대
#  v1(재즈바 1인 콜앤리스폰스)에서 리팩터: 상대 자동연주 제거,
#  P1/P2가 각자 파트를 동시에 연주해 몬스터 공격을 방어한다.
#  체력바 대신 쓰던 "스포트라이트"는 공용 게이지 + 3개 HP(몬스터/P1/P2)로 대체.
#  노트 4종: TAP(짧게) / HOLD(롱) / RAPID(연타) / SLUR(이어치기) — v1과 동일 공용 규칙 유지
# ============================================================

# ---------- config ----------
const BPM := 132.0
const CHART_PATH := "res://charts/stage1_auto_normal.json"
const CHART_CODEC := preload("res://ChartCodec.gd")
var SPB := 60.0 / BPM                 # seconds per beat
const SWING := 2.0 / 3.0              # 스윙 엇박 위치 (현재 채보는 미사용)

const LANE_KEYS_P1 := ["p1_left", "p1_down", "p1_up", "p1_right"]
const LANE_KEYCODES_P1 := [KEY_A, KEY_S, KEY_D, KEY_F]
const LANE_KEYS_P2 := ["p2_left", "p2_down", "p2_up", "p2_right"]
const LANE_KEYCODES_P2 := [KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]
const LANE_COLORS := [Color("e0863c"), Color("48a6a2"), Color("c65b86"), Color("d9b24a")]

# The player chooses one side before each run; the other side is played by AI.
const AI_PERFECT_CHANCE := 0.90
const AI_GOOD_CHANCE := 0.10
const AI_HIGHLIGHT_INTERVAL := 0.10
const HEAD_INPUT_BUFFER_DURATION := 0.12

const RECEPTOR_Y := 130.0
const SPACING := 96.0
const SCROLL := 520.0                 # px per second (내려오는 속도)
const P1_BASE_X := 150.0
const P2_BASE_X := 830.0
const ARROW_SIZE := 34.0              # 레인 화살표(리셉터)와 내려오는 화살표(노트) 공용 크기

# 판정 윈도우 (초)
const W_PERFECT := 0.080
const W_GOOD := 0.125
const W_MISS := 0.170
const HOLD_RELEASE_MIN_RATIO := 0.70

# 공용 게이지 / HP 변화량
const GAUGE_PERFECT := 0.10           # Perfect마다 공용 게이지 증가 (P1/P2 합산)
const HP_MISS_LOSS := 0.15            # Miss마다 해당 플레이어 HP만 감소
const GAUGE_HOLD_BONUS := 0.06
const GAUGE_RAPID_BONUS := 0.08

# 하이라이트 (곡 구간 시스템)
const GAUGE_MAX_THRESHOLD := 0.999            # 이 이상이면 하이라이트 진입 시 "게이지 충전 완료"
const HIGHLIGHT_DEAL_MULTIPLIER := 0.016      # 데미지 = (P1+P2 연타 수) * 이 값 (몬스터 HP 0~1 기준)

var AUDIO_OFFSET := 0.0               # [ ] 키로 미세 조정

# ---------- state ----------
var notes := []
var song_time := -3.0                 # 카운트인 3초
var started := false
var finished := false
var song_end := 0.0

var shared_gauge := 0.0               # 0~1, 하이라이트 게이지 (2단계에서 사용 예정)
var monster_hp := 1.0                 # 2단계(하이라이트)에서 깎일 예정, 지금은 뼈대만
var p1_hp := 1.0
var p2_hp := 1.0
var score := 0
var combo := 0
var max_combo := 0
var lane_held_p1 := [false, false, false, false]
var lane_held_p2 := [false, false, false, false]
var lane_released_p1 := [false, false, false, false]
var lane_released_p2 := [false, false, false, false]
var p1_head_input_buffer: Array[float] = [0.0, 0.0, 0.0, 0.0]
var p2_head_input_buffer: Array[float] = [0.0, 0.0, 0.0, 0.0]
var receptor_flash := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # 0-3=P1, 4-7=P2
var player_selection_open := true
var selected_human_side := 1
var human_side := 1
var ai_side := 0
var ai_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ai_next_highlight_tap: float = 0.0

# ---------- 곡 구간(phase) 상태 ----------
var song_phases := []                 # [{id, type("break"/"normal"/"highlight"), start, end}]
var last_phase_type := ""
var current_phase_type := "break"
var highlight_ready := false          # 하이라이트 진입 시점에 게이지가 MAX였는지
var highlight_p1_taps := 0
var highlight_p2_taps := 0
var highlight_message := ""
var highlight_message_timer := 0.0

var font: Font
var tone_players := []
var tone_idx := 0
var backing: AudioStreamPlayer
var longnote_player: AudioStreamPlayer
var perfect_stream: AudioStream
var good_stream: AudioStream
var miss_stream: AudioStream
var longnote_stream: AudioStream
var slur_sustain_end_times: Array[float] = []
var popups := []                      # {text, pos, color, life}

# ---------- Note ----------
class Note:
	var time: float
	var lane: int
	var side: int          # 0 = P1, 1 = P2 (v1에서는 0=상대/1=플레이어였음)
	var type: String       # tap / hold / rapid / slur
	var length: float = 0.0
	var pitch: int = 0
	var mash: int = 0      # rapid 필요 타수
	var state: String = "pending"   # pending/holding/done/missed
	var mash_count: int = 0
	var connect_next: bool = false  # slur 이음선
	var ai_target_time: float = -1.0
	var ai_next_rapid_tap: float = -1.0
	var ai_release_time: float = -1.0
	var ai_attempted: bool = false
	var ai_release_sent: bool = false
	var ai_skip: bool = false


# ============================================================
func _ready() -> void:
	font = ThemeDB.fallback_font
	ai_rng.randomize()
	_setup_input()
	_setup_audio()
	if not _load_chart_from_json():
		_build_chart()
	if song_phases.is_empty():
		_build_song_phases()


# 곡 구간 타임라인: break(도입/휴식) -> normal(방어) -> highlight(마구잡이 연타 딜) 반복.
# 기존 8마디 섹션 그리드를 그대로 재사용 (내용은 3단계에서 실제 곡에 맞춰 다시 짤 것).
func _input(event: InputEvent) -> void:
	if not player_selection_open:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_LEFT or key_event.physical_keycode == KEY_A:
			selected_human_side = 0
		elif key_event.keycode == KEY_RIGHT or key_event.physical_keycode == KEY_D:
			selected_human_side = 1
		elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE:
			_confirm_player_selection()
		queue_redraw()
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if _player_selection_rect(0).has_point(mouse_event.position):
			selected_human_side = 0
			_confirm_player_selection()
		elif _player_selection_rect(1).has_point(mouse_event.position):
			selected_human_side = 1
			_confirm_player_selection()
		queue_redraw()


func _confirm_player_selection() -> void:
	human_side = selected_human_side
	ai_side = 1 - human_side
	player_selection_open = false
	_reset_ai_state()


func _player_selection_rect(side: int) -> Rect2:
	return Rect2(245, 255, 330, 210) if side == 0 else Rect2(705, 255, 330, 210)


func _build_song_phases() -> void:
	song_phases = [
		{"id": "intro", "type": "break", "start": 0.0 * SPB, "end": 8.0 * SPB},
		{"id": "call_response", "type": "normal", "start": 8.0 * SPB, "end": 24.0 * SPB},
		{"id": "highlight_1", "type": "highlight", "start": 24.0 * SPB, "end": 40.0 * SPB},
		{"id": "slur", "type": "normal", "start": 40.0 * SPB, "end": 56.0 * SPB},
		{"id": "highlight_2", "type": "highlight", "start": 56.0 * SPB, "end": 64.0 * SPB},
	]


func _get_phase(t: float) -> Dictionary:
	var matching_phase: Dictionary = {}
	for ph in song_phases:
		var phase: Dictionary = ph
		if t >= float(phase["start"]) and t < float(phase["end"]):
			# Highlight ranges may intentionally overlay a normal/break range.
			if String(phase["type"]) == "highlight":
				return phase
			matching_phase = phase
	if not matching_phase.is_empty():
		return matching_phase
	return {"id": "outro", "type": "break", "start": 0.0, "end": 0.0}


func _setup_input() -> void:
	for i in range(4):
		var a1: String = LANE_KEYS_P1[i]
		if not InputMap.has_action(a1):
			InputMap.add_action(a1)
		InputMap.action_erase_events(a1)
		var e1 := InputEventKey.new(); e1.physical_keycode = LANE_KEYCODES_P1[i]
		InputMap.action_add_event(a1, e1)

		var a2: String = LANE_KEYS_P2[i]
		if not InputMap.has_action(a2):
			InputMap.add_action(a2)
		InputMap.action_erase_events(a2)
		var e2 := InputEventKey.new(); e2.physical_keycode = LANE_KEYCODES_P2[i]
		InputMap.action_add_event(a2, e2)
	if not InputMap.has_action("restart"):
		InputMap.add_action("restart")
		var er := InputEventKey.new(); er.keycode = KEY_ENTER
		InputMap.action_add_event("restart", er)


func _setup_audio() -> void:
	backing = AudioStreamPlayer.new(); add_child(backing)
	backing.bus = &"Music"
	var bs := _load("res://audio/stage1.wav")
	if bs: backing.stream = bs
	perfect_stream = _load("res://audio/perfect.wav")
	good_stream = _load("res://audio/good.wav")
	miss_stream = _load("res://audio/miss.wav")
	longnote_stream = _load("res://audio/longnote.wav")
	longnote_player = AudioStreamPlayer.new(); add_child(longnote_player)
	longnote_player.bus = &"SFX"
	if longnote_stream is AudioStreamWAV:
		var longnote_wav: AudioStreamWAV = longnote_stream
		longnote_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if longnote_stream:
		longnote_player.stream = longnote_stream
	for i in range(10):                # 톤 동시재생용 풀
		var p := AudioStreamPlayer.new(); p.bus = &"SFX"; add_child(p); tone_players.append(p)


func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null


# 판정음은 동시 노트가 잘리지 않도록 플레이어 풀에서 재생한다.
func _play_hit_sound(kind: String, _side: int) -> void:
	var p: AudioStreamPlayer = tone_players[tone_idx]
	tone_idx = (tone_idx + 1) % tone_players.size()
	var stream: AudioStream = miss_stream
	if kind == "perfect":
		stream = perfect_stream
	elif kind == "good":
		stream = good_stream
	if stream:
		p.stream = stream; p.play()


# ---------- chart ----------
func _load_chart_from_json() -> bool:
	var result: Dictionary = CHART_CODEC.load_chart(CHART_PATH)
	if not bool(result.get("ok", false)):
		push_error("Chart JSON load failed: %s. Falling back to _build_chart()." % String(result.get("error", "Unknown error")))
		return false

	var chart: Dictionary = result["chart"]
	var chart_audio: AudioStream = _load(String(chart["audioPath"]))
	if chart_audio == null:
		push_error("Chart JSON load failed: audioPath could not be loaded: %s. Falling back to _build_chart()." % String(chart["audioPath"]))
		return false

	notes.clear()
	for note_value in chart["notes"]:
		var note_data: Dictionary = note_value
		var nt := Note.new()
		nt.time = float(note_data["time"])
		nt.lane = int(note_data["lane"])
		nt.side = 0 if String(note_data["side"]) == "player" else 1   # 0=P1 AI, 1=P2 player
		nt.type = String(note_data["type"])
		nt.length = float(note_data["duration"])
		nt.pitch = int(note_data["pitch"])
		nt.mash = int(note_data["mash"])
		nt.connect_next = bool(note_data["connectNext"])
		notes.append(nt)

	notes.sort_custom(func(x, y): return x.time < y.time)
	song_phases.clear()
	if chart.has("phases"):
		for phase_value in chart["phases"]:
			var phase_data: Dictionary = phase_value
			song_phases.append(phase_data.duplicate(true))
	if notes.size() > 0:
		song_end = notes[notes.size()-1].time + 2.5
	backing.stream = chart_audio
	AUDIO_OFFSET = float(chart["offset"]) + GameSettings.audio_offset_seconds
	print("Chart JSON loaded: %s (%d notes, BPM %.3f)" % [String(chart["songId"]), notes.size(), float(chart["bpm"])])
	return true


func _n(beat: float, lane: int, side: int, type := "tap", length := 0.0, pitch := -1, mash := 0, chain := false) -> void:
	var nt := Note.new()
	nt.time = beat * SPB
	nt.lane = lane; nt.side = side; nt.type = type
	nt.length = length * SPB
	nt.pitch = pitch if pitch >= 0 else lane
	nt.mash = mash
	nt.connect_next = chain
	notes.append(nt)


func _build_chart() -> void:
	# 안전망용 폴백 채보 (JSON 로드 실패 시에만 사용). side 0=P1, 1=P2.
	var call := [[0,0],[1,1],[1.5,2],[2,3],[3,0],[3.5,1]]
	var b := 8.0

	for p in call: _n(b + p[0], p[1], 0)
	b += 8
	for p in call: _n(b + p[0], p[1], 1)
	b += 8

	_n(b+0, 2, 0, "hold", 2.0, 4)
	_n(b+2, 0, 0); _n(b+2.5, 1, 0); _n(b+3, 3, 0)
	_n(b+4, 1, 0, "rapid", 1.5, 1, 5)
	_n(b+6, 3, 0); _n(b+6.667, 2, 0); _n(b+7, 0, 0)
	b += 8
	_n(b+0, 2, 1, "hold", 2.0, 4)
	_n(b+2, 0, 1); _n(b+2.5, 1, 1); _n(b+3, 3, 1)
	_n(b+4, 1, 1, "rapid", 1.5, 1, 5)
	_n(b+6, 3, 1); _n(b+6.667, 2, 1); _n(b+7, 0, 1)
	b += 8

	_n(b+0, 0, 0, "slur", 0, 0, 0, true); _n(b+0.5, 1, 0, "slur", 0, 1, 0, true)
	_n(b+1, 2, 0, "slur", 0, 2, 0, true); _n(b+1.5, 3, 0, "slur", 0, 3)
	_n(b+2.5, 3, 0); _n(b+3, 2, 0); _n(b+3.5, 1, 0)
	_n(b+4, 0, 0, "hold", 1.5, 0)
	_n(b+6, 2, 0); _n(b+6.667, 3, 0)
	b += 8
	_n(b+0, 0, 1, "slur", 0, 0, 0, true); _n(b+0.5, 1, 1, "slur", 0, 1, 0, true)
	_n(b+1, 2, 1, "slur", 0, 2, 0, true); _n(b+1.5, 3, 1, "slur", 0, 3)
	_n(b+2.5, 3, 1); _n(b+3, 2, 1); _n(b+3.5, 1, 1)
	_n(b+4, 0, 1, "hold", 1.5, 0)
	_n(b+6, 2, 1); _n(b+6.667, 3, 1)
	b += 8

	for k in range(4):
		var side := 0 if k % 2 == 0 else 1
		_n(b+0, 0, side); _n(b+0.667, 1, side); _n(b+1, 2, side); _n(b+1.5, 3, side)
		b += 2

	notes.sort_custom(func(x, y): return x.time < y.time)
	if notes.size() > 0:
		song_end = notes[notes.size()-1].time + 2.5


# ============================================================
func _process(delta: float) -> void:
	if finished:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		queue_redraw()
		return
	if player_selection_open:
		queue_redraw()
		return

	# 카운트인 -> 시작
	if not started:
		song_time += delta
		if song_time >= 0.0:
			started = true
			song_time = 0.0
			if backing.stream: backing.play()
	else:
		song_time += delta

	# 오프셋 미세조정
	if Input.is_physical_key_pressed(KEY_BRACKETLEFT): AUDIO_OFFSET -= delta * 0.05
	if Input.is_physical_key_pressed(KEY_BRACKETRIGHT): AUDIO_OFFSET += delta * 0.05
	var t := song_time - AUDIO_OFFSET
	# 입력 (이번 프레임 눌린 레인) — P1/P2 각자
	var pressed_p1 := [false, false, false, false]
	var pressed_p2 := [false, false, false, false]
	if human_side == 0:
		_read_p1_input(delta, pressed_p1)
	else:
		_read_p2_input(delta, pressed_p2)

	# 곡 구간(phase) 감지 -> 하이라이트면 연타 카운터 모드, 아니면 기존 노트 판정
	var phase: Dictionary = _get_phase(t)
	var phase_type: String = String(phase.get("type", "normal"))
	current_phase_type = phase_type
	if phase_type != "highlight" and _is_human_full_chord_held(t):
		for lane in range(4):
			if human_side == 0:
				pressed_p1[lane] = true
				p1_head_input_buffer[lane] = 0.0
			else:
				pressed_p2[lane] = true
				p2_head_input_buffer[lane] = 0.0
	if ai_side == 0:
		_update_ai_input(t, 0, pressed_p1, lane_released_p1, phase_type == "highlight")
	else:
		_update_ai_input(t, 1, pressed_p2, lane_released_p2, phase_type == "highlight")

	if phase_type == "highlight":
		if last_phase_type != "highlight":
			# 하이라이트 진입: 이 시점의 게이지 상태로 딜/기절이 정해진다
			highlight_ready = shared_gauge >= GAUGE_MAX_THRESHOLD
			highlight_p1_taps = 0
			highlight_p2_taps = 0
			_consume_highlight_notes(phase)
		for i in range(4):
			if pressed_p1[i]:
				highlight_p1_taps += 1
				_play_hit_sound("perfect", 0)
				receptor_flash[i] = 1.0
			if pressed_p2[i]:
				highlight_p2_taps += 1
				_play_hit_sound("perfect", 1)
				receptor_flash[4 + i] = 1.0
	else:
		if last_phase_type == "highlight":
			_resolve_highlight()
		_update_side(t, 0, pressed_p1, lane_released_p1, lane_held_p1)
		_update_side(t, 1, pressed_p2, lane_released_p2, lane_held_p2)
		_resolve_passed(t)
	_refresh_longnote_loop(t)
	last_phase_type = phase_type

	# HP/게이지 클램프 + 승패 판정 (몬스터 HP 0 = 승리, P1/P2 HP 0 = 즉시 패배)
	p1_hp = clamp(p1_hp, 0.0, 1.0)
	p2_hp = clamp(p2_hp, 0.0, 1.0)
	monster_hp = clamp(monster_hp, 0.0, 1.0)
	shared_gauge = clamp(shared_gauge, 0.0, 1.0)
	if monster_hp <= 0.0:
		_end_song()
	elif p1_hp <= 0.0 or p2_hp <= 0.0:
		_end_song()
	elif started and t >= song_end:
		_end_song()

	# 이펙트 감쇠
	for i in range(8):
		receptor_flash[i] = max(0.0, receptor_flash[i] - delta * 4.0)
	for pu in popups:
		pu.life -= delta
		var pp: Vector2 = pu.pos
		pp.y -= delta * 40.0
		pu.pos = pp
	popups = popups.filter(func(p): return p.life > 0.0)
	if highlight_message_timer > 0.0:
		highlight_message_timer -= delta

	max_combo = max(max_combo, combo)
	queue_redraw()


func _consume_highlight_notes(phase: Dictionary) -> void:
	var phase_end: float = float(phase["end"])
	for nt in notes:
		if nt.state not in ["done", "missed"] and nt.time < phase_end:
			nt.state = "done"


func _read_p1_input(delta: float, pressed: Array) -> void:
	for lane in range(4):
		lane_held_p1[lane] = Input.is_action_pressed(LANE_KEYS_P1[lane])
		if Input.is_action_just_pressed(LANE_KEYS_P1[lane]):
			pressed[lane] = true
			p1_head_input_buffer[lane] = HEAD_INPUT_BUFFER_DURATION
		else:
			p1_head_input_buffer[lane] = max(p1_head_input_buffer[lane] - delta, 0.0)
		lane_released_p1[lane] = Input.is_action_just_released(LANE_KEYS_P1[lane])


func _read_p2_input(delta: float, pressed: Array) -> void:
	for lane in range(4):
		lane_held_p2[lane] = Input.is_action_pressed(LANE_KEYS_P2[lane])
		if Input.is_action_just_pressed(LANE_KEYS_P2[lane]):
			pressed[lane] = true
			p2_head_input_buffer[lane] = HEAD_INPUT_BUFFER_DURATION
		else:
			p2_head_input_buffer[lane] = max(p2_head_input_buffer[lane] - delta, 0.0)
		lane_released_p2[lane] = Input.is_action_just_released(LANE_KEYS_P2[lane])


func _is_human_full_chord_held(t: float) -> bool:
	for lane in range(4):
		var action: String = LANE_KEYS_P1[lane] if human_side == 0 else LANE_KEYS_P2[lane]
		if not Input.is_action_pressed(action):
			return false
	var chord_lanes: Array[bool] = [false, false, false, false]
	for nt in notes:
		if nt.side == human_side and nt.type != "rapid" and nt.state == "pending" and abs(nt.time - t) <= W_MISS:
			chord_lanes[nt.lane] = true
	for lane in range(4):
		if not chord_lanes[lane]:
			return false
	return true


func _reset_ai_state() -> void:
	ai_next_highlight_tap = 0.0
	for nt in notes:
		nt.ai_target_time = -1.0
		nt.ai_next_rapid_tap = -1.0
		nt.ai_release_time = -1.0
		nt.ai_attempted = false
		nt.ai_release_sent = false
		nt.ai_skip = false


func _set_ai_lane_held(side: int, lane: int, held: bool) -> void:
	if side == 0:
		lane_held_p1[lane] = held
	else:
		lane_held_p2[lane] = held


func _update_ai_input(t: float, side: int, pressed: Array, released: Array, is_highlight: bool) -> void:
	for lane in range(4):
		_set_ai_lane_held(side, lane, false)
		released[lane] = false
	if is_highlight:
		if t >= ai_next_highlight_tap:
			var highlight_lane: int = ai_rng.randi_range(0, 3)
			pressed[highlight_lane] = true
			ai_next_highlight_tap = t + AI_HIGHLIGHT_INTERVAL + ai_rng.randf_range(-0.018, 0.018)
		return

	for nt in notes:
		if nt.side != side or nt.type != "hold" or nt.state != "holding":
			continue
		if nt.ai_release_time < 0.0:
			nt.ai_release_time = nt.time + nt.length + ai_rng.randf_range(-0.030, 0.030)
		if t >= nt.ai_release_time and not nt.ai_release_sent:
			nt.ai_release_sent = true
			released[nt.lane] = true
		else:
			_set_ai_lane_held(side, nt.lane, true)

	for nt in notes:
		if nt.side != side:
			continue
		if nt.type == "rapid":
			if nt.state == "holding" and t <= nt.time + nt.length:
				if nt.ai_next_rapid_tap < 0.0:
					nt.ai_next_rapid_tap = t
				if t >= nt.ai_next_rapid_tap:
					var rapid_interval: float = max(nt.length / float(max(nt.mash + 1, 2)), 0.045)
					pressed[nt.lane] = true
					nt.ai_next_rapid_tap = t + rapid_interval
			continue
		if nt.state != "pending":
			continue
		if nt.ai_target_time < 0.0:
			_prepare_ai_note(nt)
		if not nt.ai_attempted and t >= nt.ai_target_time:
			nt.ai_attempted = true
			if not nt.ai_skip:
				pressed[nt.lane] = true
				if nt.type == "hold":
					_set_ai_lane_held(side, nt.lane, true)


func _prepare_ai_note(nt: Note) -> void:
	var roll: float = ai_rng.randf()
	nt.ai_skip = roll >= AI_PERFECT_CHANCE + AI_GOOD_CHANCE
	if nt.ai_skip:
		nt.ai_target_time = nt.time + W_MISS + 0.01
		return
	if roll < AI_PERFECT_CHANCE:
		nt.ai_target_time = nt.time + ai_rng.randf_range(-0.030, 0.030)
		return
	var good_offset: float = ai_rng.randf_range(W_PERFECT + 0.006, W_GOOD - 0.008)
	nt.ai_target_time = nt.time + good_offset * (-1.0 if ai_rng.randi() % 2 == 0 else 1.0)


# 하이라이트 종료 시점 채점: 게이지가 찬 채로 들어왔으면 총 연타 수만큼 몬스터에게 딜,
# 아니면 기절(딜 없음). 결과와 무관하게 게이지는 항상 리셋된다.
func _resolve_highlight() -> void:
	var total_taps := highlight_p1_taps + highlight_p2_taps
	if highlight_ready:
		var dealt: float = total_taps * HIGHLIGHT_DEAL_MULTIPLIER
		monster_hp -= dealt
		highlight_message = "DEAL!  %d타 합산 -> 몬스터 HP -%d%%" % [total_taps, int(round(dealt * 100.0))]
	else:
		highlight_message = "기절... 게이지 부족으로 이번 하이라이트는 딜 없음"
	highlight_message_timer = 1.6
	shared_gauge = 0.0


# P1/P2 공용 판정 처리 (side: 0=P1, 1=P2)
func _update_side(t: float, side: int, pressed: Array, released: Array, lane_held_side: Array) -> void:
	var rec_base := 0 if side == 0 else 4

	# rapid 진행중 처리
	for nt in notes:
		if nt.side != side or nt.type != "rapid":
			continue
		if nt.state == "pending" and t >= nt.time - W_GOOD:
			nt.state = "holding"          # 연타 윈도우 오픈
		if nt.state == "holding":
			if pressed[nt.lane]:
				nt.mash_count += 1
				_play_hit_sound("perfect", side)
				receptor_flash[rec_base + nt.lane] = 1.0
			if t > nt.time + nt.length:    # 윈도우 종료 -> 채점
				if nt.mash_count >= nt.mash:
					_hit("PERFECT", rec_base + nt.lane, side); shared_gauge += GAUGE_RAPID_BONUS
				elif nt.mash_count >= int(nt.mash * 0.5):
					_hit("GOOD", rec_base + nt.lane, side)
				else:
					_miss(rec_base + nt.lane, side)
				nt.state = "done"

	# tap / slur / hold 헤드 입력
	for i in range(4):
		var buffered_input: float = p1_head_input_buffer[i] if side == 0 else p2_head_input_buffer[i]
		var has_buffered_human_input: bool = side == human_side and buffered_input > 0.0
		if not pressed[i] and not has_buffered_human_input:
			continue
		var best: Note = null
		var best_dt := 999.0
		for nt in notes:
			if nt.side != side or nt.lane != i:
				continue
			if nt.type == "rapid":
				continue
			if nt.state != "pending":
				continue
			var dt: float = abs(nt.time - t)
			if dt <= W_MISS and dt < best_dt:
				best = nt; best_dt = dt
		if best == null:
			continue
		if side == human_side:
			if side == 0:
				p1_head_input_buffer[i] = 0.0
			else:
				p2_head_input_buffer[i] = 0.0
		if best.type == "hold":
			best.state = "holding"
			_judge_head(best_dt, rec_base + i, side)
		else:  # tap / slur
			best.state = "done"
			_judge_head(best_dt, rec_base + i, side)
			if best.type == "slur" and best.connect_next:
				_activate_slur_sustain(best)

	# Hold notes require a valid head and at least 70% of the body to be held.
	for nt in notes:
		if nt.side == side and nt.type == "hold" and nt.state == "holding":
			var tail_time: float = nt.time + nt.length
			var earliest_release_time: float = nt.time + nt.length * HOLD_RELEASE_MIN_RATIO
			if released[nt.lane]:
				if t >= earliest_release_time and t <= tail_time + W_MISS:
					shared_gauge += GAUGE_HOLD_BONUS
					_popup("HOLD!", rec_base + nt.lane, Color("9ee6c8"))
					nt.state = "done"
				else:
					nt.state = "missed"
					_miss(rec_base + nt.lane, side)
			elif t > tail_time + W_MISS:
				nt.state = "missed"
				_miss(rec_base + nt.lane, side)


func _judge_head(dt: float, rec: int, side: int) -> void:
	if dt <= W_PERFECT: _hit("PERFECT", rec, side)
	elif dt <= W_GOOD:  _hit("GOOD", rec, side)
	else:               _hit("GOOD", rec, side)   # W_MISS 안이면 최소 GOOD


func _hit(kind: String, rec: int, side: int) -> void:
	receptor_flash[rec] = 1.0
	combo += 1
	if kind == "PERFECT":
		score += 350; shared_gauge += GAUGE_PERFECT
		_play_hit_sound("perfect", side)
		_popup("PERFECT", rec, Color("ffd76b"))
	else:
		score += 150   # GOOD: 게이지/HP 변화 없음 (기획 그대로)
		_play_hit_sound("good", side)
		_popup("GOOD", rec, Color("cfe6ff"))


func _miss(rec: int, side: int) -> void:
	combo = 0
	if side == 0:
		p1_hp -= HP_MISS_LOSS
	else:
		p2_hp -= HP_MISS_LOSS
	_play_hit_sound("miss", side)
	_popup("MISS", rec, Color("ff6b6b"))


# 놓친 노트 -> 미스 (P1/P2 둘 다 검사; 이제 자동연주 상대가 없다)
func _resolve_passed(t: float) -> void:
	for nt in notes:
		if nt.state in ["done", "missed"]:
			continue
		if nt.type == "rapid":
			continue
		if nt.state == "pending" and t > nt.time + W_MISS:
			nt.state = "missed"
			var rec_base := 0 if nt.side == 0 else 4
			_miss(rec_base + nt.lane, nt.side)


func _activate_slur_sustain(head: Note) -> void:
	var previous: Note = null
	for candidate in notes:
		if candidate.side == head.side and candidate.type == "slur" and candidate.time < head.time:
			if previous == null or candidate.time > previous.time:
				previous = candidate
	if previous != null and previous.connect_next:
		return

	var chain_end: float = head.time
	var current: Note = head
	while current.connect_next:
		var next: Note = null
		for candidate in notes:
			if candidate.side == current.side and candidate.type == "slur" and candidate.time > current.time:
				if next == null or candidate.time < next.time:
					next = candidate
		if next == null:
			break
		chain_end = next.time
		current = next
	if chain_end > head.time:
		slur_sustain_end_times.append(chain_end)


func _refresh_longnote_loop(t: float) -> void:
	var should_loop: bool = not slur_sustain_end_times.is_empty()
	for index in range(slur_sustain_end_times.size() - 1, -1, -1):
		if t > slur_sustain_end_times[index]:
			slur_sustain_end_times.remove_at(index)
	should_loop = not slur_sustain_end_times.is_empty()
	for nt in notes:
		if nt.type != "hold" or nt.state != "holding" or t > nt.time + nt.length:
			continue
		var lane_is_held: bool = lane_held_p1[nt.lane] if nt.side == 0 else lane_held_p2[nt.lane]
		if lane_is_held:
			should_loop = true
			break
	if should_loop:
		if longnote_player.stream != null and not longnote_player.playing:
			longnote_player.play()
	elif longnote_player.playing:
		longnote_player.stop()


func _popup(txt: String, rec: int, col: Color) -> void:
	var x := (P1_BASE_X if rec < 4 else P2_BASE_X) + (rec % 4) * SPACING
	popups.append({"text": txt, "pos": Vector2(x - 20, RECEPTOR_Y - 40), "color": col, "life": 0.5})


func _end_song() -> void:
	if finished: return
	finished = true
	backing.stop()
	if longnote_player.playing:
		longnote_player.stop()


# ============================================================
#  DRAW
# ============================================================
func _draw() -> void:
	# 배경
	draw_rect(Rect2(0, 0, 1280, 720), Color("100b16"))
	draw_rect(Rect2(0, 560, 1280, 160), Color("1a1220"))   # 바닥

	# 몬스터(상단 중앙) + P1/P2(좌우)
	_draw_monster_box(Rect2(560, 60, 160, 150), monster_hp)
	var p1_role: String = "P1 PLAYER" if human_side == 0 else "P1 AI"
	var p2_role: String = "P2 PLAYER" if human_side == 1 else "P2 AI"
	_draw_player_box(Rect2(20, 250, 120, 240), p1_hp, Color("e0863c"), p1_role)
	_draw_player_box(Rect2(1140, 250, 120, 240), p2_hp, Color("48a6a2"), p2_role)

	# 공용 게이지 (MAX면 밝은 색으로 "충전 완료" 표시)
	var mx := 150.0; var mw := 968.0
	var gauge_ready := shared_gauge >= GAUGE_MAX_THRESHOLD
	draw_rect(Rect2(mx, 34, mw, 22), Color("241a2e"))
	draw_rect(Rect2(mx, 34, mw * shared_gauge, 22), Color("ffe08a") if gauge_ready else Color("6be0c8"))
	draw_string(font, Vector2(mx, 26), "GAUGE %d%%%s" % [int(shared_gauge * 100), "  READY!" if gauge_ready else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8a7fa0"))

	# 리셉터
	for i in range(4):
		_draw_receptor(P1_BASE_X + i * SPACING, i, receptor_flash[i], false)
		_draw_receptor(P2_BASE_X + i * SPACING, i, receptor_flash[4 + i], true)

	# 노트 (하이라이트 구간에선 렌더링/판정 대신 연타 카운터 오버레이로 전환)
	# Slur routes are rendered separately so a hit note cannot remove its connection.
	_draw_slur_connections()
	if current_phase_type == "highlight":
		_draw_highlight_overlay()
	else:
		for nt in notes:
			_draw_note(nt)

	# 팝업 판정
	for pu in popups:
		var a: float = clamp(pu.life / 0.5, 0.0, 1.0)
		var c: Color = pu.color; c.a = a
		draw_string(font, pu.pos, pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, c)

	# HUD 텍스트
	draw_string(font, Vector2(24, 90), "SCORE  %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f2e9d0"))
	if combo > 0:
		draw_string(font, Vector2(590, 340), "%d COMBO" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ffd76b"))
	draw_string(font, Vector2(40, 500), "P1 · 8BIT SYNTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f0b986"))
	draw_string(font, Vector2(1120, 500), "P2 · 8BIT SYNTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8fd6d1"))
	var mode_text: String = "MODE: P1 PLAYER (A S D F) / P2 AI" if human_side == 0 else "MODE: P1 AI / P2 PLAYER (K L ; ')"
	draw_string(font, Vector2(24, 678), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b7acc9"))
	draw_string(font, Vector2(24, 700), "STAGE 1 AUTO NORMAL      [ ] 싱크조정 (offset %.0fms)" % (AUDIO_OFFSET * 1000),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6f6683"))

	# 하이라이트 결과 배너 (딜/기절 결과를 잠깐 띄움)
	if highlight_message_timer > 0.0:
		draw_string(font, Vector2(360, 250), highlight_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe08a"))

	# 카운트인
	if not started and not player_selection_open:
		var c := int(ceil(-song_time + 0.001))
		var txt := str(c) if c > 0 else "GO"
		draw_string(font, Vector2(590, 300), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("ffd76b"))
		var countin_text: String = "P1: A S D F   /   P2 AI" if human_side == 0 else "P1 AI   /   P2: K L ; '"
		draw_string(font, Vector2(370, 400), countin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b7acc9"))

	# 결과
	if finished:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
		var win := monster_hp <= 0.0
		var rt := "몬스터를 쓰러뜨렸다!" if win else "쓰러졌다..."
		var rc := Color("ffd76b") if win else Color("ff8b8b")
		draw_string(font, Vector2(430, 300), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, rc)
		draw_string(font, Vector2(400, 360), "SCORE %d   MAX COMBO %d   MONSTER HP %d%%" % [score, max_combo, int(monster_hp * 100)], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f2e9d0"))
		draw_string(font, Vector2(560, 410), "Enter — 다시", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b7acc9"))


	if player_selection_open:
		_draw_player_selection()


func _draw_player_selection() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.02, 0.06, 0.84))
	draw_string(font, Vector2(330, 160), "AUTO NORMAL - CHOOSE PLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("f2e9d0"))
	draw_string(font, Vector2(398, 205), "The other player will be controlled by AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b7acc9"))
	for side in range(2):
		var card: Rect2 = _player_selection_rect(side)
		var selected: bool = selected_human_side == side
		var accent: Color = Color("e0863c") if side == 0 else Color("48a6a2")
		var fill: Color = Color(accent, 0.32) if selected else Color("171322")
		draw_rect(card, fill)
		draw_rect(card, accent if selected else Color("4a4459"), false, 3.0)
		var player_text: String = "P1" if side == 0 else "P2"
		var keys_text: String = "A  S  D  F" if side == 0 else "K  L  ;  '"
		draw_string(font, Vector2(card.position.x + 126, card.position.y + 65), player_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, accent.lightened(0.25))
		draw_string(font, Vector2(card.position.x + 86, card.position.y + 110), keys_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f2e9d0"))
		draw_string(font, Vector2(card.position.x + 79, card.position.y + 160), "PLAYER" if selected else "AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent if selected else Color("8a8294"))
	draw_string(font, Vector2(420, 625), "Click a card, or A / D then Enter", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b7acc9"))


func _draw_highlight_overlay() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.35, 0.05, 0.45, 0.16))
	var cx := 640.0
	draw_string(font, Vector2(cx - 100, 210), "MASH!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color("ff9ecf"))
	var ready_txt := "게이지 충전 완료 — 딜 확정!" if highlight_ready else "게이지 부족 — 이번엔 기절 예정"
	var ready_col := Color("9ee6c8") if highlight_ready else Color("ff8b8b")
	draw_string(font, Vector2(cx - 150, 250), ready_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ready_col)
	draw_string(font, Vector2(cx - 190, 300), "P1 %d  +  P2 %d  =  %d타" % [highlight_p1_taps, highlight_p2_taps, highlight_p1_taps + highlight_p2_taps],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f2e9d0"))
	var highlight_input_text: String = "P1: A S D F  MASH!" if human_side == 0 else "P2: K L ; '  MASH!"
	draw_string(font, Vector2(cx - 130, 336), highlight_input_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b7acc9"))


func _draw_monster_box(r: Rect2, hp: float) -> void:
	var col := Color("9a5be0")
	draw_rect(r, Color(col.r, col.g, col.b, 0.16))
	var cx := r.position.x + r.size.x * 0.5
	draw_circle(Vector2(cx, r.position.y + 56), 34, col)
	draw_rect(Rect2(cx - 46, r.position.y + 92, 92, 66), col)
	draw_string(font, Vector2(cx - 34, r.position.y - 10), "MONSTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d8c2f0"))
	_draw_hp_bar(Rect2(r.position.x, r.position.y - 26, r.size.x, 12), hp, col)


func _draw_player_box(r: Rect2, hp: float, col: Color, label: String) -> void:
	draw_rect(r, Color(col.r, col.g, col.b, 0.14))
	var cx := r.position.x + r.size.x * 0.5
	draw_circle(Vector2(cx, r.position.y + 70), 26, col)
	draw_rect(Rect2(cx - 34, r.position.y + 100, 68, 90), col)
	draw_string(font, Vector2(r.position.x + 8, r.position.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col.lightened(0.4))
	_draw_hp_bar(Rect2(r.position.x + 8, r.position.y + 200, r.size.x - 16, 14), hp, col)


func _draw_hp_bar(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, Color("241a2e"))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(ratio, 0.0, 1.0), r.size.y)), col)


func _draw_receptor(x: float, lane: int, flash: float, is_p2: bool) -> void:
	var col: Color = LANE_COLORS[lane]
	var base := col.darkened(0.55) if is_p2 else col.darkened(0.6)
	var c := base.lerp(col.lightened(0.3), flash)
	_draw_arrow(Vector2(x, RECEPTOR_Y), lane, c, ARROW_SIZE, not (flash > 0.05))


func _draw_note(nt: Note) -> void:
	if nt.state in ["done", "missed"]:
		return
	var base_x := P1_BASE_X if nt.side == 0 else P2_BASE_X
	var x := base_x + nt.lane * SPACING
	var y := RECEPTOR_Y + (nt.time - (song_time - AUDIO_OFFSET)) * SCROLL
	var col: Color = LANE_COLORS[nt.lane]
	if nt.side == 0:
		col = col.darkened(0.15)

	# HOLD: one head arrow plus a translucent body that matches the arrow's horizontal width.
	if nt.type == "hold":
		var y_tail_end := RECEPTOR_Y + (nt.time + nt.length - (song_time - AUDIO_OFFSET)) * SCROLL
		var y_head := RECEPTOR_Y if nt.state == "holding" else y
		var top: float = min(y_head, y_tail_end)
		var bottom: float = max(y_head, y_tail_end)
		if bottom < -60 or top > 760:
			return
		var body_width: float = _arrow_body_width(nt.lane, ARROW_SIZE)
		draw_rect(Rect2(x - body_width * 0.5, top, body_width, bottom - top), Color(col, 0.36))
		_draw_arrow(Vector2(x, y_head), nt.lane, col, ARROW_SIZE, false)
		return

	if y < -60 or y > 760:
		return

	# RAPID 표시
	if nt.type == "rapid":
		draw_circle(Vector2(x, y), 30, Color(col, 0.25))
	# SLUR 이음선 — 실제로 연결되는 다음 슬러 노트의 진짜 위치(레인 포함)로 그린다.
	_draw_arrow(Vector2(x, y), nt.lane, col, ARROW_SIZE, false)
	if nt.type == "rapid":
		draw_string(font, Vector2(x - 8, y + 6), "x%d" % nt.mash, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


# connect_next로 이어지는 체인에서 이 슬러 노트 "다음"에 오는 실제 슬러 노트를 찾는다
# (같은 side, 이 노트보다 시간이 늦은 슬러 노트 중 가장 가까운 것).
func _draw_slur_connections() -> void:
	var chart_time: float = song_time - AUDIO_OFFSET
	for nt in notes:
		if nt.type != "slur" or not nt.connect_next:
			continue
		var next_note: Note = _find_next_slur(nt)
		if next_note == null:
			continue

		var base_x: float = P1_BASE_X if nt.side == 0 else P2_BASE_X
		var next_base_x: float = P1_BASE_X if next_note.side == 0 else P2_BASE_X
		var start: Vector2 = Vector2(base_x + nt.lane * SPACING, RECEPTOR_Y + (nt.time - chart_time) * SCROLL)
		var finish: Vector2 = Vector2(next_base_x + next_note.lane * SPACING, RECEPTOR_Y + (next_note.time - chart_time) * SCROLL)
		var col: Color = LANE_COLORS[nt.lane]
		if nt.side == 0:
			col = col.darkened(0.15)
		draw_line(start, finish, Color(col, 0.72), 5.0, true)

		# A successful head sends a visible stream to the next linked lane.
		if nt.state != "done" or chart_time < nt.time or chart_time > next_note.time:
			continue
		var link_duration: float = next_note.time - nt.time
		if link_duration <= 0.0:
			continue
		var progress: float = clamp((chart_time - nt.time) / link_duration, 0.0, 1.0)
		var trail_start: Vector2 = Vector2(base_x + nt.lane * SPACING, RECEPTOR_Y)
		var trail_finish: Vector2 = Vector2(next_base_x + next_note.lane * SPACING, RECEPTOR_Y + link_duration * SCROLL)
		for trail_index in range(5):
			var trail_progress: float = progress - float(trail_index) * 0.11
			if trail_progress < 0.0:
				continue
			var trail_position: Vector2 = trail_start.lerp(trail_finish, trail_progress)
			var trail_alpha: float = 1.0 - float(trail_index) * 0.16
			draw_circle(trail_position, 8.0 - float(trail_index), Color(col.lightened(0.45), trail_alpha))


func _find_next_slur(nt: Note) -> Note:
	var candidate: Note = null
	for other in notes:
		if other == nt or other.side != nt.side or other.type != "slur":
			continue
		if other.time <= nt.time:
			continue
		if candidate == null or other.time < candidate.time:
			candidate = other
	return candidate


# The hold body matches each arrow's actual horizontal bounding width.
func _arrow_body_width(lane: int, size_value: float) -> float:
	return size_value * (2.0 if lane == 0 or lane == 3 else 1.4)


# 방향 화살표 (0=좌 1=하 2=상 3=우)
func _draw_arrow(pos: Vector2, lane: int, col: Color, s: float, outline: bool) -> void:
	var pts := PackedVector2Array()
	match lane:
		0: pts = PackedVector2Array([Vector2(-s,0), Vector2(0,-s*0.7), Vector2(0,-s*0.3), Vector2(s,-s*0.3), Vector2(s,s*0.3), Vector2(0,s*0.3), Vector2(0,s*0.7)])
		3: pts = PackedVector2Array([Vector2(s,0), Vector2(0,-s*0.7), Vector2(0,-s*0.3), Vector2(-s,-s*0.3), Vector2(-s,s*0.3), Vector2(0,s*0.3), Vector2(0,s*0.7)])
		2: pts = PackedVector2Array([Vector2(0,-s), Vector2(-s*0.7,0), Vector2(-s*0.3,0), Vector2(-s*0.3,s), Vector2(s*0.3,s), Vector2(s*0.3,0), Vector2(s*0.7,0)])
		1: pts = PackedVector2Array([Vector2(0,s), Vector2(-s*0.7,0), Vector2(-s*0.3,0), Vector2(-s*0.3,-s), Vector2(s*0.3,-s), Vector2(s*0.3,0), Vector2(s*0.7,0)])
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + pos)
	if outline:
		var closed := PackedVector2Array()
		closed.append_array(moved)
		closed.append(moved[0])
		draw_polyline(closed, col, 2.0)
	else:
		draw_colored_polygon(moved, col)
