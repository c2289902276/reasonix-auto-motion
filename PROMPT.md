读取当前工作目录的 `transcription.srt`，按语义拆分镜头，为每个镜头创建独立工作目录，顺序调用 Claude AI 制作 MG 动画，最后用 ffmpeg 拼接并交付 `final.mp4`。

## 工作边界

- 不设计镜头内部的具体 MG 动效，也不替 Claude AI 写动画方案；Claude AI 负责单个镜头的创意、`design.md` 填写、代码实现和 mp4 渲染。
- 调用 Claude AI 时，提供镜头编号、镜头时长、当前镜头文案和完整字幕上下文。
- 创建镜头目录前先阅读 `exampleFolder/run-claude-ai.sh`；每个镜头的具体要求和 Claude AI 回复规则以这个模板中的提示词为准。

## 镜头拆分

根据 `transcription.srt` 做粗粒度分镜。一个镜头可以包含单条字幕，也可以合并连续多条字幕；合并依据是文案是否表达同一主题、同一因果关系或同一视觉概念。

每个镜头的时长记录为秒。优先使用该镜头覆盖字幕的起止时间跨度；如果字幕时间存在缺口或异常，再用字幕条目时长之和估算。

## 镜头目录

为每个镜头创建独立目录，建议使用 `scenes/scene-001`、`scenes/scene-002` 这样的命名。目录结构参考 `exampleFolder`，至少包含：

- `.claude/`：放置 hyperframes 相关 skills 或项目指令。
- `design.md`：由 Claude AI 覆盖写入镜头设计。
- `run-claude-ai.sh`：从模板复制后按当前镜头填写。
- `transcription.srt`：复制完整字幕文件，供 Claude AI 理解整体上下文。

`run-claude-ai.sh` 模板中已有镜头编号、镜头时长、输出文件名、完整字幕路径和镜头文案等字段；先阅读模板，再为当前镜头填写这些字段。

## 调度和等待

同一时间只运行一个 Claude AI 调用，按镜头顺序执行，不并行启动多个 Claude AI。

使用 `run-claude-ai.sh` 模板中定义的阶段性汇报规则；脚本只放行以 `[[USER_MESSAGE]]` 开头的消息给你和用户。

如果一段时间没有新的 `[[USER_MESSAGE]]` 输出，不要立即判定失败；先检查：

- `claude-<scene>.stream.jsonl` 和 `claude-<scene>.stderr.log` 是否仍在写入。
- `design.md`、项目文件、渲染目录或 mp4 文件是否有更新时间。
- 是否存在 hyperframes、ffmpeg、Chromium 或 Node 渲染进程。
- `run-claude-ai.sh` 的最终退出码。

只有在进程退出失败，或长时间无日志、无文件更新且无渲染进程时，才判定该镜头失败并记录失败原因。

## 最终交付

所有镜头 mp4 完成后，使用 ffmpeg 按镜头顺序拼接为 `final.mp4`。拼接前确认每个镜头满足统一规格；如规格不一致，先转码规范化。只有一个镜头时，也需要将该镜头 mp4 复制或转码为 `final.mp4`。

最终交付：

- 每个镜头目录中的 `design.md`、Claude 日志和镜头 mp4。
- 拼接后的 `final.mp4`。
- 如有失败，提供失败镜头编号、失败阶段、关键日志和建议重试方式。
