# 극딜 용사

> 고르지 않은 카드는 전부 마왕의 것이 된다.

5칸 딜싸이클 레일 위에서 카드 순서로 콤보를 설계하는 실시간 액션 로그라이크입니다. Godot 4.7.1로 만들었습니다.

---

## ▶ 플레이 (브라우저, 설치 불필요)

### **[https://alxxxxndr.github.io/extreme-hero/](https://alxxxxndr.github.io/extreme-hero/)**

미러: **<https://extreme-hero.vercel.app>**

참고 — 첫 접속에서 약 55MB를 내려받으므로 1분 정도 걸릴 수 있습니다. 데스크톱 Chrome, 키보드 + 마우스 기준입니다.

---

## 이 게임이 특별한 이유

- **레벨업은 2택1입니다.** 고른 카드는 내 레일에, 버린 카드는 전부 마왕의 딜싸이클로 갑니다. 내가 키우지 않은 것이 그대로 최종 보스가 됩니다.
- **5칸에 놓는 순서 자체가 콤보입니다.** 기름을 칠하고 불을 붙입니다. 카드의 세기가 아니라 배치가 화력을 정합니다.
- **보스도 플레이어와 같은 딜싸이클 규칙으로 싸웁니다.** 상대가 밟은 칸을 세다가 한 바퀴가 끝나 쉬는 틈에 때리는 것이 공략의 문법입니다.
- **낮에는 RPG처럼 사냥하고, 밤에는 몰려옵니다.** 한 스테이지에 머무는 시간이 길어질수록 몬스터가 강해집니다.

---

## 조작

| 입력 | 동작 |
|---|---|
| `WASD` · 방향키 | 이동 · 바라보는 방향 · 선택지 이동 |
| `Shift` | 대시 (짧은 무적) |
| `E` | 성 · 베이스캠프 · 보스문 · 보물상자 · 균열에 들어가기 |
| `Q` | 소비 아이템 쓰기 |
| `Esc` | 5칸 편집 화면 (카드 · 각인 · 장비) |
| `Tab` | 편집 화면에서 레일 ↔ 보관함 전환 |
| `Space` · `Enter` | 확정 |
| 마우스 드래그 | 카드 몸통을 집으면 카드만, 칸 손잡이를 집으면 칸 통째로 |

규칙과 화면별 상세는 게임 소개·설명서에 있습니다.

---

## 문서

- **[게임 소개·설명서](docs/submission/01_게임소개서.md)** — 규칙 · 성장 · 보스 · 밸런스
- **[AI 활용 기술 문서](docs/submission/02_AI활용기술문서.md)** — 제작 과정에서의 AI 활용

---

## 저장소 구성

- `godot-game/` — 게임 본체 (Godot 4.7.1 프로젝트)
- `docs/submission/` — 제출 문서
- `docs/` — 개발 기록 · 핸드오프 36개
- `src/` + `index.html` — 초기 웹 프로토타입 실험. 제출물이 아닙니다

---

## (부록) Godot 소스로 직접 실행

1. 저장소를 클론합니다.
2. Godot 4.7.1에서 `godot-game/project.godot`을 임포트합니다.
3. 편집기 오른쪽 위의 재생 버튼을 누릅니다.

터미널에서는 저장소 루트에서 다음을 실행합니다.

```bash
godot --path godot-game
```

---

## 자동 검사

```bash
bash godot-game/scripts/test/run_all.sh   # 컴파일 + 기능 검사 16종
```

검사 항목 상세와 밸런스 프로브 실행 방법은 [`AGENTS.md`](AGENTS.md)를 참조하세요.

---

## 크레딧

| 에셋 · 라이브러리 | 제작 | 라이선스 |
|---|---|---|
| Ninja Adventure Asset Pack | Pixel-boy & AAA | CC0 |
| Kenney Particle Pack | Kenney | CC0 |
| 갈무리11 (Galmuri11) | quiple | OFL 1.1 |
| coi-serviceworker | Guido Zuidhof | MIT |
| game-icons 113장 | game-icons.net | CC BY 3.0 |

주의 — game-icons 113장은 저장소에만 포함되어 있고 게임 빌드에서는 제외됩니다. 라이선스 전문과 작가 목록은 `godot-game/art/external/LICENSES.md`에 동봉했습니다.
