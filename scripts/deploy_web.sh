#!/usr/bin/env bash
#
# 웹 빌드를 GitHub Pages와 Vercel 양쪽에 한 번에 재배포합니다.
#
#   bash scripts/deploy_web.sh
#
# 순서: Godot 익스포트 -> 부속 파일 복사 -> gh-pages 브랜치 갱신 -> Vercel 배포
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT/build/web"
BRANCH="gh-pages"
PAGES_URL="https://alxxxxndr.github.io/extreme-hero/"
VERCEL_URL="https://extreme-hero.vercel.app"

# 임시 worktree 정리는 중간에 실패해도 반드시 실행되도록 trap으로 보장합니다.
TMP_BASE=""
WORKTREE=""
cleanup() {
  if [ -n "$WORKTREE" ] && [ -e "$WORKTREE" ]; then
    git -C "$ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
  fi
  git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
  if [ -n "$TMP_BASE" ] && [ -d "$TMP_BASE" ]; then
    rm -rf "$TMP_BASE"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 1) Godot 웹 익스포트
# ---------------------------------------------------------------------------
echo "[1/4] Godot 웹 빌드를 만드는 중입니다... (수 분 걸릴 수 있습니다)"
mkdir -p "$WEB_DIR"
godot --headless --path "$ROOT/godot-game" --export-release "Web" "$WEB_DIR/index.html"

# ---------------------------------------------------------------------------
# 2) 배포용 부속 파일 채우기
# ---------------------------------------------------------------------------
echo "[2/4] 배포용 부속 파일을 채우는 중입니다..."

# coi-serviceworker: GitHub Pages에서 COOP/COEP 헤더를 서비스 워커로 주입합니다.
# 익스포트 산출물에는 포함되지 않으므로 매번 복사해야 합니다.
cp "$ROOT/godot-game/web_extras/coi-serviceworker.min.js" "$WEB_DIR/"

# .nojekyll: GitHub Pages가 밑줄로 시작하는 파일을 버리지 않게 합니다.
touch "$WEB_DIR/.nojekyll"

# vercel.json: Vercel 쪽 COOP/COEP 헤더 설정. 없으면 게임이 로딩 중에 멈춥니다.
if [ ! -f "$WEB_DIR/vercel.json" ]; then
  echo "오류: $WEB_DIR/vercel.json 이 없습니다." >&2
  echo "      이 파일이 있어야 Vercel이 COOP/COEP 헤더를 보내 줍니다." >&2
  echo "      docs/ops/REDEPLOY.md 를 참고해 다시 만든 뒤 실행하세요." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3) GitHub Pages (gh-pages 브랜치) 갱신
#
#    임시 git worktree를 쓰는 이유: 지금 작업 중인 master 작업 트리를 건드리지
#    않기 위해서입니다. 같은 폴더에서 브랜치를 갈아타면 작업 중이던 파일이
#    사라지거나 뒤섞일 수 있지만, worktree는 별도 폴더에 gh-pages만 따로
#    펼치므로 원본 작업 트리는 그대로 남습니다.
#
#    gh-pages에 히스토리를 쌓지 않는 이유: 배포본 한 벌이 약 84MB
#    (index.pck 45MB + index.wasm 38MB)라, 커밋을 누적하면 재배포할 때마다
#    저장소가 그만큼 불어납니다. 그래서 매번 부모 없는(orphan) 커밋 하나로
#    통째로 갈아끼우고 force-push 합니다. gh-pages는 항상 커밋 1개만 갖습니다.
#    소스 코드의 커밋 기록은 master에 그대로 보존되므로 잃는 것이 없습니다.
# ---------------------------------------------------------------------------
echo "[3/4] GitHub Pages($BRANCH 브랜치)를 갱신하는 중입니다..."

TMP_BASE="$(mktemp -d)"
WORKTREE="$TMP_BASE/$BRANCH"

# 지난 배포가 남긴 로컬 브랜치를 치웁니다. (원격 내용은 아래 force-push로 덮습니다.)
git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
git -C "$ROOT" branch -D "$BRANCH" >/dev/null 2>&1 || true

git -C "$ROOT" worktree add --detach "$WORKTREE" HEAD >/dev/null
git -C "$WORKTREE" checkout --orphan "$BRANCH" >/dev/null 2>&1
git -C "$WORKTREE" rm -rf --quiet . >/dev/null 2>&1 || true

# 남은 파일을 비우고 (.git 은 남김) 새 빌드로 채웁니다.
find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# .vercel 은 로컬 배포 연결 정보라 공개 브랜치에 올리지 않습니다.
rsync -a --exclude '.vercel' "$WEB_DIR/" "$WORKTREE/"

git -C "$WORKTREE" add -A
git -C "$WORKTREE" commit -q -m "deploy: web build $(date '+%Y-%m-%d %H:%M')"
git -C "$WORKTREE" push --force origin "$BRANCH"
echo "      - 푸시 완료. 실제 반영까지 1~2분 걸릴 수 있습니다."

# ---------------------------------------------------------------------------
# 4) Vercel 프로덕션 배포
# ---------------------------------------------------------------------------
echo "[4/4] Vercel에 배포하는 중입니다..."
vercel --cwd "$WEB_DIR" deploy --prod --yes

# ---------------------------------------------------------------------------
echo ""
echo "배포가 끝났습니다."
echo "  GitHub Pages (1순위): $PAGES_URL"
echo "  Vercel (미러):        $VERCEL_URL"
