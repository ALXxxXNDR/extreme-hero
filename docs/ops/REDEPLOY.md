# 웹 빌드 재배포 절차

게임 제목을 고치거나 코드를 수정한 뒤, 웹 빌드를 다시 만들어 배포하는 순서입니다.

## 명령 한 줄

저장소 루트에서 아래 한 줄만 실행하면 **두 배포처가 한 번에 갱신됩니다.**

```bash
bash scripts/deploy_web.sh
```

이 스크립트가 순서대로 해 줍니다.

1. Godot 웹 빌드를 새로 만듭니다 (`build/web/`).
2. 배포용 부속 파일(coi-serviceworker, `.nojekyll`)을 채우고 `vercel.json`이 있는지 확인합니다.
3. `gh-pages` 브랜치를 새 빌드로 갈아끼우고 GitHub에 푸시합니다.
4. Vercel 프로덕션에 배포합니다.

마지막에 배포 주소 두 개가 출력되면 끝난 것입니다.

## 배포 주소

| 구분 | 주소 |
|---|---|
| **플레이 링크 (1순위)** | **https://alxxxxndr.github.io/extreme-hero/** |
| 미러 (예비) | https://extreme-hero.vercel.app |
| 소스 저장소 | https://github.com/ALXxxXNDR/extreme-hero |

- 재배포해도 주소는 그대로 유지됩니다. 심사위원에게 보낸 링크를 다시 보낼 필요 없습니다.

## coi-serviceworker가 필요한 이유

- **왜 필요한가** — 이 게임의 웹 빌드는 스레드를 쓰기 때문에(`variant/thread_support=true`) 브라우저가 `SharedArrayBuffer`를 허용해야 하고, 그러려면 서버가 `Cross-Origin-Opener-Policy: same-origin`과 `Cross-Origin-Embedder-Policy: require-corp` 두 헤더를 보내 줘야 합니다.
- **Vercel** — `build/web/vercel.json`으로 이 두 헤더를 직접 지정합니다. 헤더가 이미 있으므로 coi-serviceworker는 아무 일도 하지 않고 지나갑니다.
- **GitHub Pages** — 커스텀 헤더를 설정할 방법이 없어서, 서비스 워커가 헤더를 대신 붙여 주는 coi-serviceworker를 함께 올립니다. 덕분에 두 배포처에 같은 산출물을 그대로 올려도 안전합니다.

> ⚠️ **`godot-game/web_extras/` 폴더를 지우면 안 됩니다.** 이 폴더의 `coi-serviceworker.min.js`가 배포 때마다 복사되며, 없으면 GitHub Pages 쪽 게임이 로딩 중에 멈춥니다. `godot-game/export_presets.cfg`의 `html/head_include`에 있는 `<script src="coi-serviceworker.min.js"></script>` 한 줄도 마찬가지입니다.

## 제목을 바꾸려면

브라우저 탭에 뜨는 이름은 `godot-game/project.godot`의 `config/name` 값입니다. 현재 값은 `극딜 용사`입니다.

1. `godot-game/project.godot`를 열어 `config/name="극딜 용사"` 를 원하는 제목으로 고칩니다.
2. 위 **명령 한 줄**을 다시 실행합니다. (익스포트를 다시 해야 탭 이름이 반영됩니다.)

## 배포가 잘 됐는지 확인

### GitHub Pages

```bash
curl -sI https://alxxxxndr.github.io/extreme-hero/ | head -1
```

`HTTP/2 200` 이 나오면 정상입니다.

- 푸시 후 **실제 반영까지 1~2분** 걸릴 수 있습니다. 바로 확인하면 이전 빌드가 보이거나 404가 날 수 있으니, 1~2분 기다렸다가 다시 확인하세요.
- 처음 접속할 때 **화면이 한 번 깜빡이며 자동으로 새로고침되는 것은 정상입니다.** coi-serviceworker가 서비스 워커를 등록하고 헤더를 적용하기 위해 한 번만 새로고침하는 과정입니다. 두 번째 접속부터는 깜빡이지 않습니다.

### Vercel

```bash
curl -sI https://extreme-hero.vercel.app/ | grep -iE "^HTTP/|cross-origin"
```

`HTTP/2 200` 과 함께 아래 두 줄이 나와야 정상입니다. 이 헤더가 없으면 게임이 로딩 중에 멈춥니다.

```
cross-origin-embedder-policy: require-corp
cross-origin-opener-policy: same-origin
```

이 헤더는 `build/web/vercel.json`이 지정합니다. **이 파일을 지우면 안 됩니다.** 익스포트를 다시 해도 이 파일은 지워지지 않지만, `build/web` 폴더를 통째로 지웠다면 다시 만들어야 합니다. (파일이 없으면 배포 스크립트가 2단계에서 안내와 함께 멈춥니다.)

## 로컬에서 먼저 확인하고 싶다면

배포 전에 내 컴퓨터에서 열어볼 때만 쓰는 방법입니다. 웹 빌드는 위의 두 헤더가 없으면 실행되지 않기 때문에, 그냥 `index.html`을 더블클릭하면 열리지 않습니다.

```bash
cd build/web   # 저장소 루트 기준
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
- `exclude_filter` 로 `art/screenshots/*`, `art/reference/*`, `art/external/game-icons/*` 를 빌드에서 뺐습니다. 앞의 둘은 게임 실행에 쓰이지 않는 문서·QA용 이미지라 약 9MB를 줄였습니다. `art/external/game-icons/*`는 CC BY 3.0 아이콘 팩으로, 게임 안에서 참조하는 곳이 없는데 배포본에 실리면 게임 내 크레딧 표기 의무가 생기므로 뺐습니다. (저장소에는 `LICENSES.md` 전문과 함께 그대로 보관합니다 — 파일을 지우면 안 됩니다.)
- 익스포트 템플릿은 `~/Library/Application Support/Godot/export_templates/4.7.1.stable/` 에 설치돼 있습니다. 이 폴더가 비면 익스포트가 실패하므로, 그때는 Godot 편집기의 `편집기 → 익스포트 템플릿 관리`에서 다시 내려받으면 됩니다.

## 참고 — 배포 스크립트가 하는 일

- `gh-pages` 브랜치는 **임시 git worktree**에서 갱신합니다. 지금 작업 중인 `master` 작업 트리를 전혀 건드리지 않기 위해서입니다. 작업이 끝나면 임시 폴더는 자동으로 정리됩니다.
- `.vercel` 폴더(로컬 배포 연결 정보)는 공개 브랜치에 올라가지 않도록 제외합니다.
- `gh-pages`는 매번 부모 없는(orphan) 커밋 하나로 통째로 갈아끼워 force-push 합니다. 빌드 내용이 이전과 같아도 건너뛰지 않고 항상 푸시합니다.
