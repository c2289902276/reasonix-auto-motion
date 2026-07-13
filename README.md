<p align="right">
  简体中文 | <a href="./README.en.md">English</a>
</p>

# auto-motion

`auto-motion` 是一个把字幕稿自动拆分成多段 MG 动画镜头，并拼接成竖屏视频的工作流模板。你只需要准备 `transcription.srt`，然后让 Reasonix 执行 `PROMPT.md` 中的任务说明；Reasonix 会按字幕语义拆镜头，逐个调用 `reasonix run` 生成单镜头动画，最后用 FFmpeg 拼接出 `final.mp4`。

## 运行证据

下面是一段真实运行过程截图：多镜头任务已经连续运行 1 小时 36 分钟，调度层正在等待执行层完成后续镜头的代码实现和渲染。

<img src="./readme-assets/evidence.png" alt="auto-motion long-running orchestration and execution workflow evidence" width="720" />

## 架构

### 1. 调度层：Reasonix + PROMPT.md

`PROMPT.md` 定义整个自动化流程：

- 读取当前目录的 `transcription.srt`。
- 按语义把字幕拆成连续、完整覆盖总时长的镜头。
- 为每个镜头创建 `scenes/scene-001`、`scenes/scene-002` 等独立目录。
- 从 `exampleFolder` 复制运行模板和 HyperFrames 相关技能。
- 顺序调用 `reasonix run` 生成每个镜头的动画 MP4。
- 检查镜头时长和产物规格，并用 FFmpeg 拼接为 `final.mp4`。

### 2. 执行层：Reasonix + run-reasonix.sh

`exampleFolder/run-reasonix.sh` 是单镜头执行模板。调度层会为每个镜头填写：

- `SCENE_ID`
- `SCENE_DURATION_SECONDS`
- `SCENE_TEXT`
- `OUTPUT_FILE`
- `FULL_TRANSCRIPT_PATH`

脚本使用 `reasonix run` 非交互式调用 Reasonix，并要求 Reasonix 输出固定阶段消息。原始日志、错误日志和用户可读进度分别写入镜头目录中的：

- `reasonix-<scene>.stdout.log`
- `reasonix-<scene>.stderr.log`
- `reasonix-<scene>.user.log`

### 3. 动画层：HyperFrames

`exampleFolder/.claude/skills/` 中包含 HyperFrames 相关技能。Reasonix 会基于这些技能编写 HTML 动画项目，并渲染 1080x1440、30fps、静音、无音轨的 MP4。该 skills 目录采用 Claude Code 兼容格式，Reasonix 原生读取 `.claude/skills/<name>/SKILL.md`，零改动直接加载。

### 4. 验收层：auto-test

`auto-test/run.sh` 提供端到端测试入口。它会创建临时工作区，复制测试字幕和模板，调用 Reasonix 执行完整流程，然后用 `auto-test/validate.sh` 检查：

- Reasonix 阶段消息是否完整。
- 单镜头 MP4 和 `final.mp4` 是否存在。
- 视频是否为 1080x1440。
- 帧率是否约为 30fps。
- 时长是否接近字幕总时长。
- 是否没有音轨。

## 前提条件

请先确保本机已经安装并配置好以下工具：

- [Reasonix CLI](https://github.com/esengine/DeepSeek-Reasonix)（`npm i -g reasonix`，需 Node ≥ 22）
- DeepSeek API key：运行 `reasonix setup` 写入 `~/.reasonix/.env`，或 `export DEEPSEEK_API_KEY=sk-...`
- Node.js 22 或更高版本
- FFmpeg 和 FFprobe
- `jq`
- 可联网环境，用于 Reasonix 搜索素材、安装依赖或下载品牌视觉资产
- Windows 下需 Git Bash 提供 bash 运行时

可以用下面的命令做基础检查：

```bash
reasonix --version
reasonix doctor
node --version
ffmpeg -version
ffprobe -version
jq --version
```

## 快速开始

### 1. 准备字幕文件

把 SRT 字幕文件放到仓库根目录，并命名为 `transcription.srt`：

```bash
cp /path/to/transcription.srt ./transcription.srt
```

### 2. 执行自动生成流程

在仓库根目录运行：

```bash
reasonix run "$(cat PROMPT.md)"
```

Reasonix 会读取 `PROMPT.md`，拆分字幕、创建镜头目录、逐个调用 `reasonix run`，并最终生成：

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

### 3. 查看结果

最终视频在仓库根目录：

```bash
open final.mp4
```

## 测试

运行内置端到端测试：

```bash
bash auto-test/run.sh
```

测试产物会写入 `auto-test/.tmp/`。该目录已被 `.gitignore` 忽略。

## 目录说明

```text
.
├── PROMPT.md                    # 主流程任务说明
├── transcription.srt            # 输入字幕文件
├── exampleFolder/
│   ├── run-reasonix.sh          # 单镜头 Reasonix 调用模板
│   └── .claude/skills/           # HyperFrames 相关技能（Claude Code 兼容格式）
├── auto-test/
│   ├── run.sh                    # 端到端测试入口
│   ├── validate.sh               # 视频产物校验脚本
│   └── transcription.srt         # 测试字幕
└── final.mp4                     # 生成后的视频交付文件
```

## 注意事项

- 同一时间只运行一个 `reasonix run` 调用，不并行渲染多个镜头。
- 每个镜头必须完整覆盖字幕时间轴，镜头时长总和应等于字幕总时长。
- 若某个镜头失败，优先查看对应目录下的 `stderr.log`、`stdout.log` 和 `user.log`。
- 如果视频规格不一致，应先统一转码后再拼接。
- `reasonix run` 在无交互终端下自动获得自主执行权限，无需额外 flag。