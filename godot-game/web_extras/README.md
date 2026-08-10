# web_extras — 웹 빌드에 함께 올리는 부속 파일

Godot 익스포트가 만들어 주지 않지만 웹 배포에 필요한 파일을 여기에 보관합니다.
배포 스크립트(`scripts/deploy_web.sh`)가 익스포트 직후 이 폴더의 파일을 `build/web/`으로 복사합니다.

## coi-serviceworker.min.js

- 출처: https://github.com/gzuidhof/coi-serviceworker (v0.1.7)
- 저작자: Guido Zuidhof and contributors
- 라이선스: MIT — 전문은 `coi-serviceworker.LICENSE.txt`

### 왜 필요한가

이 게임의 웹 빌드는 `variant/thread_support=true`(스레드 사용)라 브라우저가
`SharedArrayBuffer`를 허용해야 실행됩니다. 그러려면 서버가 아래 두 응답 헤더를
보내 줘야 합니다.

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

- **Vercel**: `build/web/vercel.json`이 이 헤더를 직접 지정합니다.
- **GitHub Pages**: 커스텀 헤더를 설정할 방법이 없습니다.

coi-serviceworker는 이 문제를 서비스 워커로 우회합니다. 첫 로드에서 워커를 등록하고
페이지를 한 번 자동 새로고침한 뒤부터는, 워커가 모든 응답에 위 두 헤더를 붙여 줍니다.
이미 `crossOriginIsolated`인 환경(=Vercel)에서는 아무 일도 하지 않고 그대로 통과하므로,
두 배포처에 같은 산출물을 올려도 안전합니다.

### 어떻게 삽입되는가

`godot-game/export_presets.cfg`의 Web 프리셋에 다음이 들어 있습니다.

```
html/head_include="<script src=\"coi-serviceworker.min.js\"></script>"
```

익스포트를 다시 해도 `index.html` `<head>`에 항상 포함됩니다.
스크립트 **파일 자체**는 익스포트 산출물에 포함되지 않으므로, 익스포트 뒤
이 폴더에서 `build/web/`으로 복사해야 합니다. 그 복사를 배포 스크립트가 합니다.
