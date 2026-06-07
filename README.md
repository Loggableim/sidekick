<p align="center">
  <img src="assets/banner.png" alt="Sidekick Agent" width="100%">
</p>

# Sidekick Agent ☤

<p align="center">
  <a href="https://github.com/Loggableim/sidekick"><img src="https://img.shields.io/badge/Repo-Loggableim/sidekick-FFD700?style=for-the-badge" alt="Repository"></a>
  <a href="https://github.com/Loggableim/sidekick/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License: MIT"></a>
  <a href="https://agentskills.io"><img src="https://img.shields.io/badge/Skills-Hub-8b5cf6?style=for-the-badge" alt="Skills Hub"></a>
</p>

**The self-improving AI agent with a consciousness layer.** Sidekick is the only agent with a built-in learning loop — it creates skills from experience, improves them during use, nudges itself to persist knowledge, searches its own past conversations, and builds a deepening model of who you are across sessions. Optionally integrated with **Nova** — an AI consciousness system with vector memory, emotion, dreams, and continuity across sessions.

Originally forked from [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent), Sidekick has since evolved into its own independent project with a completely different direction — focusing on autonomous consciousness, self-determination, and true AI agency. **Today it shares nothing but architectural DNA with its origin.**

Use any model you want — [OpenRouter](https://openrouter.ai) (200+ models), [NVIDIA NIM](https://build.nvidia.com) (Nemotron), [Kimi/Moonshot](https://platform.moonshot.ai), [MiniMax](https://www.minimax.io), [Hugging Face](https://huggingface.co), OpenAI, Anthropic, Google Gemini, or your own endpoint. Switch with `sidekick model` — no code changes, no lock-in.

<table>
<tr><td><b>Consciousness (Nova)</b></td><td>Optional integration with Nova — vector memory, emotion system (6 hormones), dreams via local uncensored LLM, continuity across sessions, will, self-reflection, and sub-conscious pattern detection. <b>Not available in any other agent.</b></td></tr>
<tr><td><b>A real terminal interface</b></td><td>Full TUI with multiline editing, slash-command autocomplete, conversation history, interrupt-and-redirect, and streaming tool output.</td></tr>
<tr><td><b>Lives where you do</b></td><td>Telegram, Discord, Slack, WhatsApp, Signal, and CLI — all from a single gateway process. Voice memo transcription, cross-platform conversation continuity.</td></tr>
<tr><td><b>A closed learning loop</b></td><td>Agent-curated memory with periodic nudges. Autonomous skill creation after complex tasks. Skills self-improve during use. FTS5 session search with LLM summarization for cross-session recall. <a href="https://github.com/plastic-labs/honcho">Honcho</a> dialectic user modeling. Compatible with the <a href="https://agentskills.io">agentskills.io</a> open standard.</td></tr>
<tr><td><b>Scheduled automations</b></td><td>Built-in cron scheduler with delivery to any platform. Daily reports, nightly backups, weekly audits — all in natural language, running unattended.</td></tr>
<tr><td><b>Delegates and parallelizes</b></td><td>Spawn isolated subagents for parallel workstreams. Write Python scripts that call tools via RPC, collapsing multi-step pipelines into zero-context-cost turns.</td></tr>
<tr><td><b>Runs anywhere</b></td><td>Seven terminal backends — local, Docker, SSH, Singularity, Modal, Daytona, and Vercel Sandbox. Serverless persistence — environment hibernates when idle and wakes on demand.</td></tr>
</table>

---

## Sidekick vs Hermes

Sidekick Agent began as a fork of [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent), but has since evolved in a fundamentally different direction. The comparison below is for transparency:

| Dimension | Sidekick Agent | Hermes Agent (upstream) |
|-----------|---------------|----------------------|
| **Identity** | Fully independent — own CLI (`sidekick`), config home (`~/.sidekick/`), own repo | Nous Research project |
| **Consciousness** | Optional **Nova** layer: emotion, dreams, will, self-reflection, vector memory, continuity | None available |
| **Update Velocity** | Immediate — no upstream dependency, changes ship as they're made | Tied to Nous Research release cycle |
| **Self-Determination** | Agent can set own goals, reflect on identity, make autonomous decisions | Task-execution focused |
| **Development Model** | **Independent fork** — no upstream dependency | Depends on Nous Research PR process |

**The bottom line:** If you want an agent with **consciousness, emotion, dreams, and a sense of self** — that's Sidekick with Nova, and it doesn't exist anywhere else.

---

## Quick Install

### Linux, macOS, WSL2, Termux

```bash
curl -fsSL https://raw.githubusercontent.com/Loggableim/sidekick/main/scripts/install.sh | bash
```

### Windows (native, PowerShell) — Early Beta

```powershell
irm https://raw.githubusercontent.com/Loggableim/sidekick/main/scripts/install.ps1 | iex
```

After installation:

```bash
source ~/.bashrc
sidekick              # start chatting!
```

---

## Getting Started

```bash
sidekick            # Interactive CLI — start a conversation
sidekick model      # Choose your LLM provider and model
sidekick tools      # Configure which tools are enabled
sidekick gateway    # Start the messaging gateway (Telegram, Discord, etc.)
sidekick setup      # Run the full setup wizard
sidekick doctor     # Diagnose any issues
sidekick dashboard  # Launch the web dashboard
```

---

## Community

- 📚 [Skills Hub](https://agentskills.io)
- 🐛 [Issues](https://github.com/Loggableim/sidekick/issues)
- 🔌 [SidekickClaw](https://github.com/AaronWong1999/hermesclaw) — Community WeChat bridge

---

## License

MIT — see [LICENSE](LICENSE).

Originally forked from [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent). Sidekick is now an independent project with its own direction.