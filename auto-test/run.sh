#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT_DIR/auto-test/.tmp/run"
LOG_DIR="$ROOT_DIR/auto-test/.tmp/logs"
PROMPT_FILE="$TEST_DIR/PROMPT.md"
EVENT_LOG="$LOG_DIR/codex-events.jsonl"
LAST_MESSAGE="$LOG_DIR/codex-last-message.txt"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

require_command codex
require_command claude
require_command jq
require_command ffmpeg
require_command ffprobe

rm -rf "$TEST_DIR" "$LOG_DIR"
mkdir -p "$TEST_DIR" "$LOG_DIR"

cp "$ROOT_DIR/PROMPT.md" "$TEST_DIR/PROMPT.md"
cp -R "$ROOT_DIR/exampleFolder" "$TEST_DIR/exampleFolder"
cp "$ROOT_DIR/auto-test/transcription.srt" "$TEST_DIR/transcription.srt"
cp "$ROOT_DIR/auto-test/validate.sh" "$TEST_DIR/validate.sh"
chmod +x "$TEST_DIR/exampleFolder/run-claude-ai.sh" "$TEST_DIR/validate.sh"

cat >>"$PROMPT_FILE" <<'PROMPT_APPEND'

如果当前目录存在 `validate.sh`，说明这是 auto-test 工作区。你需要在生成最终 mp4 后运行 `bash validate.sh .`；如果验收失败，优先修复客观产物问题后重跑验收。auto-test 的通过标准只看客观事实：Codex/Claude 退出状态、阶段消息、`design.md` 是否写入、mp4 是否存在、分辨率是否为 1080x1440、帧率是否为 30fps、时长是否接近字幕时长、是否无音轨。
PROMPT_APPEND

codex exec \
  --cd "$TEST_DIR" \
  --sandbox danger-full-access \
  --ask-for-approval never \
  --skip-git-repo-check \
  --json \
  --output-last-message "$LAST_MESSAGE" \
  - <"$PROMPT_FILE" \
| tee "$EVENT_LOG"

bash "$TEST_DIR/validate.sh" "$TEST_DIR" | tee "$LOG_DIR/validate.log"

echo "auto-test PASS"
echo "workdir: $TEST_DIR"
echo "logs: $LOG_DIR"
