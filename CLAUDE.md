# CLAUDE.md — 작업 컨텍스트 (v2)

이 파일은 Claude Code가 자동으로 읽는 프로젝트 컨텍스트다. 코드 수정 전에 여기 규칙과 구조를 먼저 따른다.

## 프로젝트 요약
2인 협동 리듬 RPG. 두 플레이어가 각자 파트를 연주해 몬스터의 리듬 공격을 방어하고, **하이라이트 순간 마구잡이 연타로 함께 딜을 폭발**시킨다. 자세한 기획은 `DESIGN.md`.

## 기획 v1 → v2 전환
이 프로젝트는 원래 "재즈바 배경의 1인 리듬 배틀"(v1)이었다가 **"2인 협동 리듬 RPG"(v2)**로 컨셉이 완전히 바뀌었다. 코드에 v1 잔재가 남아있으니 아래 "코드 리팩터 지도"를 반드시 참고할 것.

## 실행 환경
- **엔진: Godot 4.7**, 언어: GDScript
- **렌더러: Compatibility (gl_compatibility) 고정.** ⚠️ Forward+로 바꾸지 말 것 — Godot 4.7 stable은 Forward+ 프로젝트를 열 때 크래시하는 알려진 버그가 있다. 이 게임은 순수 2D라 Compatibility로 충분.
- 실행: Godot에서 F5. 메인 씬은 `Main.tscn`.

## 파일 구조
```
project.godot   설정 (Compatibility 렌더러 고정)
Main.tscn       루트 Node2D "Main" + Main.gd
Main.gd         전체 로직 (v1 잔재 있음, 리팩터 대상)
audio/          v1 자리표시용 재즈 합성음 (v2에선 칩튠으로 교체 예정)
DESIGN.md       기획서 v2
CLAUDE.md       이 파일
```

## 코드 리팩터 지도 (v1 → v2)

### ✅ 살릴 것 (재사용)
- **노트 낙하 시스템**: `Note` 클래스, `_process`의 노트 스크롤·판정 흐름
- **판정 로직**: `_judge_head`, `W_PERFECT/W_GOOD/W_MISS` 상수, PERFECT/GOOD/MISS 등급
- **입력 처리 뼈대**: `_setup_input`, InputMap 등록 방식
- **오디오 파이프라인**: `_setup_audio`, `_load`, `_play_tone`, `AudioStreamPlayer` 풀
- **채보 형식**: `_n(beat, lane, side, type, length, ...)` 함수 시그니처와 노트 필드
- **그리기 뼈대**: `_draw_arrow`, `_draw_receptor`, `_draw_note` (색상·스타일은 칩튠 톤으로 재조정)
- **카운트인/재시작**: `song_time` 음수 시작, restart 액션
- **싱크 오프셋 조정**: `[` `]` 키로 `AUDIO_OFFSET` 조정하는 로직

### ❌ 버릴 것 (제거 or 대체)
- **스포트라이트 게이지** (`spotlight`, `_draw_performer`, 스포트라이트 미터 렌더링): 몬스터 HP + 플레이어 HP + 공용 게이지 3개로 교체
- **`_update_opponent`** (상대 자동연주): v2엔 자동연주 상대 없음. 대신 몬스터가 노트를 "쏘고" P1/P2가 나눠서 받는 구조
- **콜 앤 리스폰스 채보 구조** (`_build_chart`의 상대 콜→플레이어 응수 교대): v2는 P1/P2가 동시에 각자 파트를 침
- **재즈바 배경/연주자 실루엣 그래픽**: 몬스터+플레이어 2인 배치로 교체
- **`side` 필드의 의미**: v1에선 side=0(상대)/1(플레이어). v2에선 side=0(P1)/1(P2). 이름은 유지해도 되지만 의미가 바뀜을 명심.

### ➕ 새로 추가할 것
- **P2 입력 처리**: 기존 P1의 방향키 판정을 그대로 복제해서 P2용 키(WASD 등)로. `LANE_KEYS_P1` / `LANE_KEYS_P2` 두 세트.
- **공용 게이지 시스템**: `shared_gauge: float` (0~1). Perfect마다 증가, Miss는 게이지 안 건드림.
- **HP 시스템**: `monster_hp`, `p1_hp`, `p2_hp`. Miss마다 해당 플레이어 HP만 감소.
- **곡 구간 관리**: 곡을 phase(A/B/highlight/break)로 나누는 타임라인. `song_phases: Array[Dict]` 같은 구조.
- **하이라이트 모드 전환**: phase가 highlight일 때 노트 렌더링/판정 대신 **마구잡이 연타 카운터** 모드로 전환. 게이지 부족 시 기절.
- **딜 계산**: 하이라이트 종료 시 `p1_taps + p2_taps` × 배율 = 몬스터 HP 감소.
- **몬스터/스테이지 데이터**: 스테이지별 곡·채보·몬스터 HP·하이라이트 타이밍을 데이터로 분리 (json이나 gdscript 리소스).
- **스테이지 선택 화면, 결과 화면**: 새 씬으로.

## 코딩 규칙 / 함정
1. **들여쓰기는 탭.** 스페이스 섞지 말 것.
2. **타입 없는 배열/딕셔너리 원소에 `:=`(자동추론) 쓰지 말 것.** Godot 4.7은 "Cannot infer the type" 파싱 에러. 예: `var a := LANE_KEYS[i]` ❌ → `var a: String = LANE_KEYS[i]` ✅
3. 게임 요소는 **`_draw`로 그린다** (v1의 방식 유지). 별도 Control 노드 남발 금지.
4. 오디오는 `res://audio/*.wav`를 `_load()`로. 파일 없으면 null 반환하고 무음 진행. null 체크 유지.
5. 시간 단위: 채보는 **beat**, 런타임 판정은 **초(`song_time`)**. `_n`이 beat→초 변환.
6. **v1 코드 이해 없이 v2 기능 얹지 말 것.** side 필드 의미 바뀐 것, 상대 자동연주 제거되는 것 같은 게 헷갈리기 쉬움. 먼저 v1 로직 파악하고 대체.

## 현재 상태
- v1 프로토타입은 돌아감 (재즈 컨셉, 스포트라이트, 콜 앤 리스폰스). 지인 피드백 "FNF 짭"으로 폐기 결정.
- v2 기획 확정됨. 아직 코드 반영 안 됨.

## 다음 작업 (로드맵)
아래 순서 권장. 코드는 v1을 리팩터하는 방식으로.

### 1단계: v2 뼈대 이식
1. `spotlight` 관련 다 제거, `shared_gauge` 도입
2. `_update_opponent` 제거, 모든 노트를 P1/P2 노트로 재분류
3. P2 입력키 InputMap에 추가, 판정 로직 P1/P2 각각 처리
4. HP 3개(monster/p1/p2) 도입, Miss가 HP만 깎게 수정
5. `_draw` 배경/UI를 v2 레이아웃(몬스터 상단 중앙 + 좌우 플레이어)으로 재작성

### 2단계: 곡 구간 시스템
1. `song_phases` 타임라인 도입 (A/B/highlight/break 구간)
2. `_process`에서 현재 phase 감지
3. highlight phase 진입 시 노트 스크롤 중단, 연타 카운터 모드로 전환
4. 게이지 MAX 여부에 따라 딜 or 기절 분기
5. highlight 종료 시 몬스터 HP 감소, 게이지 리셋

### 3단계: 콘텐츠
1. 칩튠 곡 확보 (Suno) → wav로 audio/ 폴더에
2. 곡에 맞춰 채보 데이터 작성 (P1 파트 / P2 파트 분리)
3. 스테이지 2개 + 보스 1개 데이터

### 4단계: 메타 화면
1. 시작 메뉴 (start/tutorial/exit)
2. 스테이지 선택 화면
3. 결과 화면

## 하지 말 것
- Forward+ 렌더러로 전환 (4.7 크래시)
- 재즈바/스포트라이트/콜앤리스폰스 관련 코드 유지 (v2 컨셉과 안 맞음)
- 스토리/컷신 추가 (무스토리 컨셉)
- v1의 `side=0(상대)` 개념을 v2 코드에 남기기 (혼란 유발)
- 판정 규칙 자체를 재즈답게 비틀기 (스윙 박자 강제 등) — 인영님이 이 방향 명시적으로 거절함
