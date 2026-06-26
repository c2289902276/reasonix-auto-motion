# 项目规则

- `PROMPT.md` 要像直接写给人类操作者的任务说明，不要暴露执行这份说明的人是 agent、Codex 或 Codex CLI，也不要使用“主控 agent”这类身份设定；可以明确说明需要操作 Claude AI，描述被调用的一侧时可以使用“AI”或“子 agent”。
- `PROMPT.md` 直接以任务需求开头，不写“用户会给你这份说明”之类的元叙述。保持精简，避免重复表达；视频规格、Claude AI 具体提示、联网或品牌素材规则等细节优先放在 `run-claude-ai.sh` 模板里。
