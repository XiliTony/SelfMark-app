#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)" in
  MINGW*|MSYS*)
    ROOT_DIR="$(cd "$SCRIPT_DIR" && pwd -W)"
    export MSYS_NO_PATHCONV=1
    ;;
  *)
    ROOT_DIR="$SCRIPT_DIR"
    ;;
esac
SOURCE="docs/openapi/openapi.yaml"
BUNDLE="docs/openapi/dist/selfmark.openapi.yaml"
BASELINE="docs/openapi/.tmp/main.openapi.yaml"
REDOCLY_IMAGE="redocly/cli:1.34.5"
OASDIFF_IMAGE="tufin/oasdiff:1.11.7"

cd "$ROOT_DIR"
mkdir -p docs/openapi/dist docs/openapi/.tmp
GIT_PREFIX="$(git rev-parse --show-prefix)"
REPO_BUNDLE="${GIT_PREFIX}${BUNDLE}"

docker run --rm \
  -v "$ROOT_DIR:/spec" \
  -w /spec \
  "$REDOCLY_IMAGE" \
  lint "$SOURCE"

docker run --rm \
  -v "$ROOT_DIR:/spec" \
  -w /spec \
  "$REDOCLY_IMAGE" \
  bundle "$SOURCE" --output "$BUNDLE"

if git cat-file -e "origin/main:$REPO_BUNDLE" 2>/dev/null; then
  git show "origin/main:$REPO_BUNDLE" > "$BASELINE"
  docker run --rm \
    -v "$ROOT_DIR:/data:ro" \
    -w /data \
    "$OASDIFF_IMAGE" \
    breaking "$BASELINE" "$BUNDLE"
else
  echo "origin/main 尚无模块化 bundle，首次提交跳过 breaking 检查"
fi
