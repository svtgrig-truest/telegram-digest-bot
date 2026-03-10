# telegram-digest-bot

Intelligent daily digest for Telegram via [mcp.ai.church](https://mcp.ai.church) MCP integration.

## What it does

Reads your Telegram channels using Claude Code's built-in MCP tools and delivers structured digests:

| Digest | Time | Content |
|--------|------|---------|
| 🌅 Morning | 07:00 | Top news · Events (next 14 days) · Saved Messages audit |
| ☀️ Afternoon | 15:00 | Job postings · Hawala/currency rates · Theatre tickets |
| 🌙 Evening | 21:00 | News updates · Opportunity alerts · Unfulfilled promises |

## How it works

This is a **Claude Skill** — trigger it by typing in Claude:
```
telegram-buddy: morning-digest
telegram-buddy: afternoon-digest
telegram-buddy: evening-digest
```

Claude reads your Telegram via MCP, builds a structured digest, and outputs it directly in the UI. No Telegram bot required.

## Setup

```bash
bash ~/telegram-digest-bot/skills/telegram-buddy/scripts/setup.sh
```

Sets up launchd jobs to run all three digests on schedule.

## Structure

```
buddy/
  config.yaml      # channels, timezone, schedule
  profile.yaml     # auto-built interest profile (30-day TTL)
  state.yaml       # last run timestamps

skills/telegram-buddy/
  SKILL.md         # Claude Skill definition
  references/      # digest formats, config schema, MCP API docs
  scripts/         # setup.sh
```

## Requirements

- [Claude Code](https://claude.ai/code) with [mcp.ai.church](https://mcp.ai.church) MCP configured
- macOS (launchd scheduling)
