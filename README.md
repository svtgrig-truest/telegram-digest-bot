# telegram-digest-bot

Intelligent daily digest for Telegram via [mcp.ai.church](https://mcp.ai.church) MCP integration. Reads your Telegram channels using Claude Code and delivers structured digests — no bot token required.

| Digest | Time | Content |
|--------|------|---------|
| 🌅 Morning | 07:00 | Top news · Events (next 14 days) · Saved Messages audit |
| ☀️ Afternoon | 15:00 | Job postings · Hawala/currency rates · Theatre tickets |
| 🌙 Evening | 21:00 | News updates · Opportunity alerts · Unfulfilled promises |

---

## Prerequisites

1. **Claude Code** — [download](https://claude.ai/code), macOS required (uses launchd for scheduling)

2. **mcp.ai.church** — Telegram read-only MCP server. Add it once:
   ```bash
   claude mcp add --transport http --scope user ai-church https://mcp.ai.church/mcp
   ```
   Then authenticate: open [mcp.ai.church](https://mcp.ai.church) → sign in with Google → link your Telegram account

---

## Quick Install

```bash
# 1. Clone
git clone https://github.com/svtgrig-truest/telegram-digest-bot.git ~/telegram-digest-bot

# 2. Run setup (installs skill, creates launchd jobs)
bash ~/telegram-digest-bot/skills/telegram-buddy/scripts/setup.sh

# 3. Test
claude -p "telegram-buddy: morning-digest"
```

Setup does:
- Installs the `telegram-buddy` skill into `~/.claude/skills/`
- Creates `~/telegram-digest-bot/buddy/` with default config
- Registers three launchd jobs (07:00, 15:00, 21:00)

---

## Add Your Channels

The default config has **no channels** — you need to add your own. First, discover your Telegram channel IDs:

1. Open Claude and ask:
   ```
   Use the ai-church MCP to list my Telegram chats
   ```
2. Claude calls `list_chats` and shows your channels with their `id` values

3. Edit `~/telegram-digest-bot/buddy/config.yaml`:

```yaml
# Channels scanned for events (morning + evening digest)
event_sources:
  - chat_id: 1234567890        # ← replace with real ID from list_chats
    name: "My News Channel"
    type: channel              # channel / supergroup / user

# Channels scanned for jobs, hawala, tickets (afternoon digest)
opportunity_sources:
  - chat_id: 9876543210
    name: "Jobs Channel"
    type: supergroup
```

> **Tip:** If channels are empty, the skill auto-shows your available channels on first run and prompts you to add them.

---

## Trigger Manually

```bash
claude -p "telegram-buddy: morning-digest"
claude -p "telegram-buddy: afternoon-digest"
claude -p "telegram-buddy: evening-digest"
```

---

## Troubleshooting

**Scheduled jobs not running?**
```bash
launchctl list | grep telegram-buddy        # should show 3 jobs with exit code 0
tail -f ~/telegram-digest-bot/buddy/logs/morning-error.log
```

**MCP auth expired?**
Re-authenticate at [mcp.ai.church](https://mcp.ai.church) and restart Claude Code.

**Adjust digest times?**
Edit `~/Library/LaunchAgents/com.telegram-buddy.*.plist` — change `<integer>7</integer>` to desired hour, then:
```bash
launchctl unload ~/Library/LaunchAgents/com.telegram-buddy.morning.plist
launchctl load   ~/Library/LaunchAgents/com.telegram-buddy.morning.plist
```

**Wrong timezone?**
Jobs use macOS system timezone. Either change macOS timezone to match your `config.yaml`, or adjust plist Hour values accordingly.

---

## Project Structure

```
buddy/
  config.yaml      # your channels, timezone, schedule (edit this)
  profile.yaml     # auto-built interest profile (30-day TTL)
  state.yaml       # last run timestamps

skills/telegram-buddy/
  SKILL.md         # Claude Skill definition
  references/      # digest formats, config schema, MCP API docs
  scripts/
    setup.sh       # one-time setup
```

---

## Requirements

- [Claude Code](https://claude.ai/code) with [mcp.ai.church](https://mcp.ai.church) MCP configured
- macOS (launchd scheduling)
- Telegram account linked via mcp.ai.church OAuth
