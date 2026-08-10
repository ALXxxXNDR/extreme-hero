# 웹 빌드 재배포 절차

게임 제목을 고치거나 코드를 수정한 뒤, 웹 빌드를 다시 만들어 배포하는 순서입니다.

- 배포 주소(고정): **https://extreme-hero.vercel.app**
- Vercel 프로젝트: `moomis-projects/extreme-hero` (로그인 계정 `jethy55-6407`)
- 재배포해도 주소는 그대로 유지됩니다. 심사위원에게 보낸 링크를 다시 보낼 필요 없습니다.

## 명령 3줄

저장소 루트(`/Users/moomi/orca/projects/NHN`)에서 순서대로 실행합니다.

```bash
cd /Users/moomi/orca/projects/NHN
godot --headless --path godot-game --export-release "Web" "$PWD/build/web/index.html"
vercel --cwd build/web deploy --prod --yes
```

세 번째 줄이 끝나면 출력에 `Aliased: https://extreme-hero.vercel.app` 가 찍힙니다. 그 주소가 최종 배포본입니다.

## 제목을 바꾸려면

브라우저 탭에 뜨는 이름은 `godot-game/project.godot`의 `config/name` 값입니다. 현재 값은 `딜싸이클 용사`입니다.

1. `godot-game/project.godot`를 열어 `config/name="딜싸이클 용사"` 를 원하는 제목으로 고칩니다.
2. 위 **명령 3줄**을 다시 실행합니다. (익스포트를 다시 해야 탭 이름이 반영됩니다.)

## 배포가 잘 됐는지 확인

```bash
curl -sI https://extreme-hero.vercel.app/ | grep -iE "^HTTP/|cross-origin"
```

`HTTP/2 200` 과 함께 아래 두 줄이 나와야 정상입니다. 이 헤더가 없으면 게임이 로딩 중에 멈춥니다.

```
cross-origin-embedder-policy: require-corp
cross-origin-opener-policy: same-origin
```

이 헤더는 `build/web/vercel.json`이 지정합니다. **이 파일을 지우면 안 됩니다.** 익스포트를 다시 해도 이 파일은 지워지지 않지만, `build/web` 폴더를 통째로 지웠다면 다시 만들어야 합니다.

## 로컬에서 먼저 확인하고 싶다면

배포 전에 내 컴퓨터에서 열어볼 때만 쓰는 방법입니다. 웹 빌드는 위의 두 헤더가 없으면 실행되지 않기 때문에, 그냥 `index.html`을 더블클릭하면 열리지 않습니다.

```bash
cd /Users/moomi/orca/projects/NHN/build/web
python3 -c "
import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm'}
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(('127.0.0.1', 8099), H).serve_forever()
"
```

띄운 뒤 브라우저에서 `http://127.0.0.1:8099` 로 접속합니다. 종료는 `Ctrl+C`입니다.

## 참고 — 익스포트 설정

- **폰트는 `godot-game/art/fonts/`에 포함됨** — 갈무리(Galmuri11, OFL 1.1) TTF와 라이선스 전문이 저장소 안에 들어 있고 `project.godot`의 `gui/theme/custom_font`가 이 파일을 가리킵니다. 웹 빌드에는 시스템 폰트 폴백이 없어 이 설정이 빠지면 한글이 전부 □로 깨지므로, 이 줄과 폰트 파일을 지우면 안 됩니다.
- 프리셋 파일: `godot-game/export_presets.cfg` (프리셋 이름 `Web`)
- `variant/thread_support=true` — 스레드를 쓰는 빌드라 위의 COOP/COEP 헤더가 반드시 필요합니다.
- `exclude_filter` 로 `art/screenshots/*`, `art/reference/*` 를 빌드에서 뺐습니다. 게임 실행에 쓰이지 않는 문서·QA용 이미지라 약 9MB를 줄였습니다.
- 익스포트 템플릿은 `~/Library/Application Support/Godot/export_templates/4.7.1.stable/` 에 설치돼 있습니다. 이 폴더가 비면 익스포트가 실패하므로, 그때는 Godot 편집기의 `편집기 → 익스포트 템플릿 관리`에서 다시 내려받으면 됩니다.
