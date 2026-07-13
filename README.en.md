<p align="right">
  <a href="./README.md">简体中文</a> | English
</p>

# reasonix-auto-motion

`reasonix-auto-motion` is a workflow template that turns an SRT transcript into multiple motion-graphics scenes and stitches them into a vertical video. Provide `transcription.srt`, then run Reasonix with the instructions in `PROMPT.md`; Reasonix segments the transcript, calls `reasonix run` scene by scene, and uses FFmpeg to produce `final.mp4`.

> **Acknowledgement & Fork Notes**: This project is forked from [vibe-motion/auto-motion](https://github.com/vibe-motion/auto-motion). Credits to the original author. The upstream uses Codex (orchestration) + Claude Code (execution) as its runtime; this fork replaces them with [Reasonix CLI](https://github.com/esengine/DeepSeek-Reasonix) (`reasonix run`) and adds a multi-model smart router: orchestration runs on GLM-5.2, execution on DeepSeek-V4-Pro, web search via a DeepSeek-V4-Flash subagent, and multimodal visual recognition via a Qwen3.7-Plus subagent. The HyperFrames skills under `.claude/skills/` are used with zero changes.



## Architecture

### 1. Orchestration: Reasonix + PROMPT.md

`PROMPT.md` defines the full automation flow:

- Read `transcription.srt` from the current working directory.
- Split the transcript into semantic scenes that continuously cover the full subtitle timeline.
- Create independent scene folders such as `scenes/scene-001` and `scenes/scene-002`.
- Copy the execution template and HyperFrames skills from `exampleFolder`.
- Call `reasonix run` sequentially to generate each scene MP4.
- Check scene duration and output specs, then stitch all scene videos into `final.mp4` with FFmpeg.

### 2. Execution: Reasonix + run-reasonix.sh

`exampleFolder/run-reasonix.sh` is the single-scene execution template. The orchestrator fills in the scene-specific values:

- `SCENE_ID`
- `SCENE_DURATION_SECONDS`
- `SCENE_TEXT`
- `OUTPUT_FILE`
- `FULL_TRANSCRIPT_PATH`

The script invokes Reasonix non-interactively through `reasonix run` and requires fixed progress messages. Raw logs, stderr logs, and user-readable progress are written into each scene folder:

- `reasonix-<scene>.stdout.log`
- `reasonix-<scene>.stderr.log`
- `reasonix-<scene>.user.log`

### 3. Motion Authoring: HyperFrames

`exampleFolder/.claude/skills/` contains the HyperFrames skills used by Reasonix. Reasonix writes an HTML animation project with those skills and renders a 1080x1440, 30fps, silent MP4 with no audio track. The skills directory uses the Claude Code-compatible format; Reasonix reads `.claude/skills/<name>/SKILL.md` natively, loading them with zero changes.

### 4. Validation: auto-test

`auto-test/run.sh` provides an end-to-end test entry point. It creates a temporary workspace, copies the test transcript and templates, asks Reasonix to run the full flow, then uses `auto-test/validate.sh` to verify:

- Required Reasonix progress messages are present.
- The scene MP4 and `final.mp4` exist.
- Video resolution is 1080x1440.
- Frame rate is approximately 30fps.
- Duration is close to the subtitle duration.
- The output has no audio track.

## Prerequisites

Install and configure the following tools first:

- [Reasonix CLI](https://github.com/esengine/DeepSeek-Reasonix) (`npm i -g reasonix`; Node ≥ 22)
- DeepSeek API key: run `reasonix setup` to save it to `~/.reasonix/.env`, or `export DEEPSEEK_API_KEY=sk-...`
- Node.js 22 or newer
- FFmpeg and FFprobe
- `jq`
- Network access, so Reasonix can search for references, install dependencies, or download brand visual assets
- Git Bash on Windows for the bash runtime

Run these checks before starting:

```bash
reasonix --version
reasonix doctor
node --version
ffmpeg -version
ffprobe -version
jq --version
```

## Quick Start

### 1. Prepare the transcript

Place your SRT file at the repository root and name it `transcription.srt`:

```bash
cp /path/to/transcription.srt ./transcription.srt
```

### 2. Run the automation

From the repository root:

```bash
reasonix run "$(cat PROMPT.md)"
```

Reasonix reads `PROMPT.md`, splits the transcript, creates scene folders, calls `reasonix run` scene by scene, and produces:

```text
scenes/
  scene-001/
    scene-001.mp4
    reasonix-scene-001.stdout.log
    reasonix-scene-001.stderr.log
    reasonix-scene-001.user.log
  scene-002/
    scene-002.mp4
final.mp4
```

### 3. Open the result

The final video is written to the repository root:

```bash
open final.mp4
```

## Test

Run the built-in end-to-end test:

```bash
bash auto-test/run.sh
```

Test artifacts are written to `auto-test/.tmp/`, which is ignored by Git.

## Repository Layout

```text
.
├── PROMPT.md                    # Main workflow instructions
├── transcription.srt            # Input transcript
├── exampleFolder/
│   ├── run-reasonix.sh          # Single-scene Reasonix template
│   └── .claude/skills/           # HyperFrames skills (Claude Code-compatible format)
├── auto-test/
│   ├── run.sh                    # End-to-end test entry point
│   ├── validate.sh               # Video validation script
│   └── transcription.srt         # Test transcript
└── final.mp4                     # Generated delivery video
```

## Notes

- Only one `reasonix run` call should run at a time; scene rendering is intentionally sequential.
- Scenes must continuously cover the subtitle timeline, and the sum of scene durations should match the transcript duration.
- If a scene fails, inspect its `stderr.log`, `stdout.log`, and `user.log` first.
- If scene video specs differ, normalize them before stitching.
- `reasonix run` acquires autonomous execution permissions under a non-interactive terminal with no extra flag.
