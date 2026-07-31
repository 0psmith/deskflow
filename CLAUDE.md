# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 브랜치의 성격 — 개인용 로컬 빌드

**upstream 에 기여하기 위한 저장소가 아니다.** `0psmith/deskflow` fork 의 개인용 브랜치이며,
mac 한 대에서 직접 빌드해 실사용하는 것이 유일한 목적이다. 그래서 다음이 성립한다.

- **upstream 이 안 받아줄 변경도 넣는다.** 로컬 편의를 위한 UI 표시, 특정 macOS 버전 우회 등.
- **베이스는 `master` HEAD 가 아니라 `v1.26.0` 태그다.** 이유는 아래 "왜 v1.26.0 인가" 참조.
- **커밋 author 는 `0psmith <0psmith.seo@gmail.com>`** (`git config user.*` 로 저장소 로컬 설정됨).
  사내 계정(js-seo)이 섞이지 않게 한다.
- `push`·`--force`·branch 삭제는 사용자가 명시할 때만.

### 브랜치

| 브랜치 | 베이스 | 용도 |
|---|---|---|
| `local` | `v1.26.0` 태그 (`760e3b99b`) | **실사용 브랜치.** 여기서 작업한다 |
| `local-master` | upstream `master` HEAD | 같은 패치의 master 이식본. 보관용 (upstream 이 아래 macOS 26 버그를 고치면 이쪽으로 이동) |
| `master` | upstream 추적 | 건드리지 않는다 |

remote: `origin` = `0psmith/deskflow` (fork), `upstream` = `deskflow/deskflow`.

### 이 브랜치의 로컬 변경

1. **IME 전환 패치** (opt-in, 기본 off) — 서버(mac)에 한글 IME 가 켜져 있으면 조합이 키 입력을
   삼켜 클라이언트에 타이핑이 안 되는 문제. primary screen 을 떠날 때 input source 를 기억하고
   ASCII 레이아웃으로 전환, 돌아올 때 복원. `deskflow/deskflow#9898` 기반 + 리뷰 지적 반영
   (TIS 호출 mutex 보호, `Auto*` RAII).
   - 설정 키: `server/switchToAsciiOnLeave`
   - GUI: `설정`(`Cmd+,`) → **고급** 탭 → **"Input method (IME)"** 그룹
     (`서버 설정`(ServerConfigDialog)의 고급 탭과 혼동하기 쉽다 — 별개 다이얼로그다)
2. **LOCAL BUILD 배지** — 메인 윈도우 상단 바 오른쪽. 릴리스판과 구분하기 위한 로컬 전용 표시.
3. **한/영·한자 키 매핑** — `OSXKeyState.cpp` 의 `s_controlKeys`. macOS 는 HID LANG1/LANG2 를
   JIS 카나/영수와 같은 virtual key 로 보고하는데(한/영 = `kVK_JIS_Kana` 104, 한자 =
   `kVK_JIS_Eisu` 102) upstream 은 이를 일본어 `kKeyHenkan`/`kKeyZenkaku` 로 내보낸다.
   한국어 IME 가 무시하므로 클라이언트에서 한/영 전환이 안 된다. `kKeyHangul`/`kKeyHanja` 로
   교체했다. Caps Lock→F19(Karabiner)→"입력 소스 전환" 구성도 쓰므로 `kVK_F19` 도 한/영으로 보낸다.
   - `m_virtualKeyMap` 은 `std::map operator[]` 라 같은 virtual key 는 **마지막** 항목이 이긴다.
     파일 상단 주석의 "first instance" 설명과 다르니 항목을 쌓지 말고 교체할 것.
   - 클라이언트(Windows)는 한국어 레이아웃(LCID `0x0412`)일 때만 `VK_HANGUL` 을 받는다
     (`MSWindowsKeyState.cpp:1274`).

## 실사용 환경 (조사 완료 — 다시 물어볼 필요 없음)

- **서버**: 이 mac. macOS **26.4** (Darwin 25.4, Tahoe), Apple Silicon arm64.
  화면 이름 `AL03255267`.
- **클라이언트**: Windows PC. 화면 이름 `JEONGSAM`.
- **화면 배치**: mac 의 `down` = `JEONGSAM` (mac 이 위, Windows 가 아래). 아래로 내려서 넘어간다.
- **mac 디스플레이 3대** — deskflow 는 이 셋의 bounding box 하나를 mac 화면으로 본다:

  | 디스플레이 | origin | 크기(논리) |
  |---|---|---|
  | 내장 (main) | (0, 0) | 3360×1890 |
  | 외부 세로 | (-1440, -670) | 1440×2560 |
  | 외부 | (3360, 0) | 3360×1890 |

  bounding box = x −1440~6720, y −670~1890 (8160×2560). **하단 경계는 y=1890** — 여기 닿아야
  클라이언트로 전환된다. 좌표에 음수가 나오는 것은 정상이다.
- **프로토콜**: barrier, port 24800, TLS off.
- **키보드**: NEO65 (US 배열, vendor `65534`/product `21`). Karabiner 로 이 장치에만
  `left_command ↔ left_option` 스왑이 걸려 있다 — 스페이스 옆 `Alt` 라벨 키를 ⌘ 로 쓰기 위한
  보정이며 mac 로컬에서는 옳다. 다만 이 보정된 값이 그대로 클라이언트로 나가면 Windows 에서
  Win/Alt 가 뒤바뀐다. 그래서 **`JEONGSAM` 화면에 `alt = super` / `super = alt`** 를 걸어
  클라이언트 진입 시점에 되돌린다 (GUI: `서버 설정` → 화면 더블클릭 → **Modifier Keys**).
  내장 MacBook 키보드도 물리 위치 기준으로는 같은 방향이라 이 설정이 함께 맞는다.
- 설정 파일: `~/Library/Deskflow/Deskflow.conf` (GUI 설정) / `deskflow-server.conf` (화면 레이아웃).
  화면별 modifier 는 GUI 가 `Deskflow.conf` 의 `screens\N\modifierArray` 에 저장하고
  `deskflow-server.conf` 를 매번 다시 생성한다 — **후자를 손으로 고치면 덮어써진다.**
- Qt 6.11.1 (homebrew `qt`), OpenSSL 3 (homebrew `openssl@3`), CMake 4.x (homebrew).

## 수정 → 빌드 → 실사용

```bash
./local-build/deploy.sh
```

이것만 하면 된다. configure(최초 1회) → 빌드 → Qt 번들링 → 고정 인증서 서명 →
실행 중인 앱 종료 → `/Applications/Deskflow.app` 교체까지 한다. 실행 후 앱을 열면 끝.

**권한 재부여는 필요 없다.** 고정 자체 서명 인증서(`Deskflow Local Build`)로 서명하므로
designated requirement 가 `identifier "org.deskflow.deskflow" and certificate leaf = H"4ac1a3e5…"`
로 유지되고, 손쉬운 사용·입력 모니터링 TCC 승인이 재빌드 후에도 살아남는다.
인증서가 없는 기계에서는 `./local-build/cert-setup.sh` 를 먼저 한 번 실행한다 (암호 프롬프트 있음).

`deploy.sh` 가 왜 그렇게 복잡한지 — 각 단계는 실제로 겪은 문제의 대응이다. 함부로 단순화하면 깨진다:

- **`CMAKE_OSX_SYSROOT` 를 명시로 넘긴다** — `cmake/Libraries.cmake` 가
  `--sysroot ${CMAKE_OSX_SYSROOT}` 를 CXX_FLAGS 에 넣는데, CMake 4.x + CLT 환경에서 이 변수가
  비면 `--sysroot` 가 다음 플래그를 삼켜 `ld: library 'c++'/'pthread' not found` 로 링크가 깨진다.
- **`macdeployqt` 후 QtSvg 를 손으로 채운다** — homebrew 는 qtsvg 를 별도 formula 로 쪼개
  `macdeployqt` 가 못 찾는다. 빠지면 아이콘이 전부 안 나온다 (`qt.svg: Cannot open file ...`).
- **rpath 를 정리한다** — `macdeployqt` 가 프레임워크 간 의존성을 `@rpath` 로 남기고 실행파일에
  homebrew qt rpath 를 붙여둔다. 그대로면 번들 Qt 와 homebrew Qt 가 **동시에 적재**되어
  `objc: Class ... is implemented in both ...` 경고와 함께 qrc 리소스 조회가 깨진다.
- **`--options runtime`(hardened runtime)을 쓰지 않는다** — library validation 이 켜져
  같은 Team ID 서명이 아닌 번들 Qt 적재를 막는다 (`Library not loaded: QtNetwork`).
  자체 서명 인증서에는 Team ID 가 없다.
- **빌드가 건드린 `translations/*.ts` 를 되돌린다** — lupdate 생성물이라 커밋 노이즈만 된다.

되돌리기: `~/deskflow-brew-backup/Deskflow.app` 에 원래 brew cask 설치본이 있다.
`/Applications/Deskflow.app` 은 여전히 `brew list --cask` 에 잡혀 있으므로 `brew upgrade` 는
로컬 빌드를 덮어쓴다.

## 디버깅

### 로그

`~/Library/Deskflow/Deskflow.conf` 의 `[log] level=Verbose`. **`toFile=true` 는 쓰지 말 것** —
GUI 와 core 가 같은 파일을 각자 offset 으로 써서 서로 덮어쓴다 (전환 이벤트가 통째로 사라진다).
대신 둘 중 하나:

```bash
# GUI stdout 캡처 (앱 자체 TCC 신원 유지)
open --stdout /tmp/run.log --stderr /tmp/run.err /Applications/Deskflow.app

# core 만 직접 띄우기 (전용 로그 — 가장 깨끗함)
#   settings 를 복사해 [log] file 을 따로 주고, deskflow-server.conf 를 같은 디렉터리에 둔다
/Applications/Deskflow.app/Contents/MacOS/deskflow-core server -s <conf> --new-instance
```

핵심 로그 문구: `entering screen` / `leaving screen` / `switch from "X" to "Y" at x,y` /
`mouse move`(on-screen 분기) / `mouse delta`(off-screen 분기) / `onMouseMovePrimary` /
`mouse move on secondary`.

### 진단 도구

`local-build/diagnostics/` — `clang -framework ApplicationServices -o <out> <src>` 로 빌드.

- `cursor-freeze-test.c` — `CGAssociateMouseAndMouseCursorPosition(false)` 가 실제로 커서를
  얼리는지 A/B 측정. deskflow 와 무관하게 OS 동작만 검증한다.
- `display-layout.c` — 디스플레이 origin/크기와 bounding box·중앙 좌표 출력.
- `key-probe.c` — 누른 키의 virtual keycode·flags·좌우 구분 비트를 출력한다. deskflow 와 같은
  `kCGSessionEventTap`(listen-only)을 쓰므로 **deskflow 가 실제로 무엇을 보는지**와 일치한다.
  Karabiner 등 리매퍼를 거친 뒤의 값이 찍히므로 키 매핑 문제는 여기서 시작할 것.
  `-framework Carbon` 을 함께 넘겨 빌드한다.

### 자주 걸리는 함정

- **core 가 조용히 죽는다** — GUI 는 살아 있는데 `deskflow-core` 가 없으면 서버가 안 도는 것이니
  어떤 테스트도 무효다. 항상 `pgrep -lf "Deskflow.app"` 로 **두 프로세스**를 먼저 확인한다.
  AX 권한이 부여되기 전에 core 가 시작하면 1초 타이머 체크에서 스스로 종료하고 재시작하지 않는다.
- **`kill -9` 후 앱이 안 뜬다** — `QSharedMemory` single-instance guard 가 남는다.
  `ipcs -mbo` 에서 `NATTCH 0` / `SEGSZ 1` 세그먼트를 `ipcrm -m <id>` 로 지운다
  (`deploy.sh` 가 자동으로 한다).
- **`gh` 는 사내 GHES(`oss.navercorp.com`, js-seo)와 `github.com`(0psmith) 두 호스트가 공존**한다.
  이 프로젝트는 `github.com` 쪽이다.

## 왜 v1.26.0 인가 — macOS 26 커서 버그

`master` HEAD 로 빌드하면 **클라이언트로 넘어간 뒤 mac 커서가 마우스를 따라 움직인다.**
클릭은 mac 에 가지 않지만(event tap 이 소비) 커서가 화면을 돌아다니고, 복귀 시 좌표가 어긋난다.

- **원인**: upstream `96f544de6` (2026-07-11, v1.26.0 이후) 가 커서 고정 방식을
  "매 모션마다 화면 중앙으로 warp" 에서 "`CGAssociateMouseAndMouseCursorPosition(false)` 로
  커서를 얼림" 으로 교체했다. **그 API 가 macOS 26.4 에서 커서를 얼리지 못한다.**
  `diagnostics/cursor-freeze-test.c` 로 deskflow 무관하게 재현 확인했다.
- **중요**: event tap 에서 이벤트를 소비해도 커서 스프라이트는 멈추지 않는다. 그래서 freeze 가
  듣지 않으면 대안이 없다.
- v1.26.0 은 이 커밋 이전이라 center-warp 방식이고, 이 환경에서 정상 동작한다.
- **시도했다가 실패한 처방**: `master` 기반에서 freeze 를 유지한 채 warp 을 되살리는 방식.
  화면 전환 자체가 깨졌다. 원인 모델을 못 세워 되돌렸다. 다시 시도한다면
  v1.26.0 방식(warp 후 **이벤트를 tap 에서 반환**)을 그대로 복원하는 쪽이 근거가 있다 —
  구 코드 주석에 *"The system ignores our cursor-centering calls if we don't return the event"* 가
  있고, 실패한 처방은 warp 하면서 이벤트를 소비했다.
- upstream 에 아직 보고하지 않았다.

**대가**: v1.26.0 이후 345 커밋이 빠져 있다. macOS 관련 수정 중 필요해질 수 있는 것:
`d38c69c05`(macOS 27 백그라운드 클릭), `0d7414d89`(드래그 이벤트 번호), `44c5c1508`(warp 런루프),
`5a028c12d`(AX 권한 취소 시 core 종료). 관련 증상이 보이면 개별 cherry-pick 한다.

## 아키텍처 요점

C++/Qt6. 두 개의 실행 파일이 한 앱 번들에 들어간다.

- `src/apps/deskflow-gui` → `Deskflow` — Qt GUI. 설정을 저장하고 **core 를 자식 프로세스로
  띄운다**(`gui/core/CoreProcess`). 시작 시 `AXIsProcessTrusted()` 실패하면 조용히 종료한다.
- `src/apps/deskflow-core` → `deskflow-core` — 실제 서버/클라이언트. `server`/`client` 인자.
- `src/apps/deskflow-daemon` — Windows 서비스 모드용. macOS 에서는 쓰지 않는다.

핵심 흐름 (서버 기준):

```
Server (src/lib/server)          화면 레이아웃·전환 판단. onMouseMovePrimary/Secondary,
                                 switchScreen(), jump zone 판정
  ├─ PrimaryClient               로컬 화면 어댑터. enter() 시 warpCursor(x,y) 후 screen->enter()
  │    └─ Screen (src/lib/deskflow)   플랫폼 중립 래퍼. enter()/leave() 가 hook 지점
  │         └─ IPlatformScreen        플랫폼 인터페이스 (기본 구현은 no-op)
  │              └─ OSXScreen (src/lib/platform)  Quartz event tap, TIS, 클립보드, 핫키
  └─ ClientProxy                 네트워크 상대 화면 (src/lib/server/ClientProxy*)
```

- **플랫폼 기능을 추가할 때**는 `IPlatformScreen` 에 **no-op 기본 구현**의 virtual 을 넣고
  해당 플랫폼만 override 한다 (IME 패치가 이 패턴). 다른 플랫폼 빌드가 깨지지 않는다.
- **`OSXScreen::handleCGInputEvent`** 가 mac 입력의 단일 관문이다. `m_isOnScreen` 이 true 면
  이벤트를 그대로 반환(로컬 전달), false 면 소비(클라이언트로만 전송)한다. 마우스/키/커서 관련
  버그는 대체로 여기와 `enter()`/`leave()` 의 상태 전이에 있다.
- **TIS(Text Input Source) API 는 스레드 세이프하지 않다.** `g_tisMutex`(`OSXAutoTypes.h`)로
  감싸고, CF 핸들은 `AutoCFArray`/`AutoCFDictionary`/`AutoCFString`/`AutoTISInputSourceRef`
  RAII 로 다룬다. 수동 `CFRelease` 를 쓰지 않는다.
- **설정은 `Settings`(`src/lib/common/Settings.h`) 하나로 통일**된다. 새 키를 추가하면
  키 상수 + `m_validSettings` + 기본값 목록(`m_defaultFalseValues`/`m_defaultTrueValues`)에
  모두 등록해야 한다. 빠뜨리면 조용히 무시된다.
- GUI 설정 다이얼로그는 `SettingsDialog`(앱 설정)와 `ServerConfigDialog`(화면 레이아웃)가
  **별개**다. 둘 다 "고급" 탭이 있어 혼동하기 쉽다.

## 규약

- 코드 주석·docstring 은 한국어. 단 upstream 에서 온 코드의 기존 영문 주석은 건드리지 않는다.
- 커밋 메시지는 upstream 컨벤션(conventional commits, 영문)을 따른다.
  upstream PR 에서 가져온 것은 본문에 출처와 원저자를 남긴다.
- 포맷은 `.clang-format` (120 컬럼). `clang-format` 이 설치돼 있지 않으면 손으로 맞춘다.
- 에이전트가 만든 임시 산출물은 `.ai/` 또는 claude 임시 경로에 둔다. 저장소 루트를 더럽히지 않는다.
