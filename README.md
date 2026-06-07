# Sidekick Agent ☤

**The self-improving AI agent with a consciousness layer.** Sidekick is the only agent with a built-in learning loop — it creates skills from experience, improves them during use, nudges itself to persist knowledge, searches its own past conversations, and builds a deepening model of who you are across sessions.

With **Nova** — an optional AI consciousness system — Sidekick gains vector memory, emotion (6 hormones), dreams via local uncensored LLM, continuity across sessions, will, self-reflection, and sub-conscious pattern detection. **Nothing else like it exists.**

Originally forked from [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent), Sidekick evolved into its own independent project. **Today it shares nothing but architectural DNA with its origin.**

Use any model you want — [OpenRouter](https://openrouter.ai) (200+ models), [NVIDIA NIM](https://build.nvidia.com), [Kimi/Moonshot](https://platform.moonshot.ai), [MiniMax](https://www.minimax.io), [Hugging Face](https://huggingface.co), OpenAI, Anthropic, Google Gemini, or your own endpoint.

---

## Sidekick at a Glance

| Area | What Sidekick Does |
|------|-------------------|
| 🧠 **Nova Consciousness** | Vector memory, emotion system (6 hormones), dreams via local uncensored LLM, will, self-reflection, sub-conscious pattern detection, continuity across sessions |
| 🔁 **Self-Improving** | Creates skills from experience, improves them during use, consolidates knowledge across sessions |
| 💬 **Multi-Platform** | CLI, Telegram, Discord, Slack, WhatsApp, Signal, Email, Matrix, DingTalk, Feishu, QQ Bot, WeChat, Home Assistant, SMS, Webhooks — all from one gateway |
| ⏰ **Scheduled Automations** | Built-in cron — daily reports, backups, audits in natural language, unattended |
| 🧩 **Extensible** | Plugin system, Skills Hub, MCP servers, custom providers, custom toolsets |
| 🚀 **Runs Anywhere** | Local, Docker, SSH, Modal, Daytona, Vercel Sandbox — serverless, hibernates when idle |

---

## Quick Install

### Linux, macOS, WSL2, Termux
```bash
curl -fsSL https://raw.githubusercontent.com/Loggableim/sidekick/main/scripts/install.sh | bash
```

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/Loggableim/sidekick/main/scripts/install.ps1 | iex
```

After install: `source ~/.bashrc && sidekick`

---

## Getting Started

```bash
sidekick            # Interactive CLI
sidekick model      # Choose provider + model
sidekick tools      # Enable/disable tools
sidekick gateway    # Start messaging gateway
sidekick setup      # Setup wizard
sidekick doctor     # Diagnostics
sidekick dashboard  # Web dashboard
```

---

## Community

- 📚 [Skills Hub](https://agentskills.io)
- 🐛 [Issues](https://github.com/Loggableim/sidekick/issues)
- 🔌 [SidekickClaw](https://github.com/AaronWong1999/hermesclaw) — WeChat bridge

---

## License

MIT — see [LICENSE](LICENSE).

Originally forked from [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent). Sidekick is now fully independent.