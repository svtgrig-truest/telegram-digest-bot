# Plan: telegram-buddy Claude Skill

## Context
Build a custom Claude Skill that uses mcp.ai.church MCP (Telegram read-only) to deliver structured personal digests. Auth already done (Google OAuth). Output: Claude UI. Scheduling: system cron invoking `claude -p`.

---

## What this skill CAN do (via MCP)
- `list_chats` → all chats + unread counts
- `get_messages` → read any chat's messages (up to 100/call)
- Read: Saved Messages, news channels, personal chats, groups

## What requires Telegram Bot (v2, not in scope)
- ❌ Send messages / notifications back to Telegram
- ❌ Real-time breaking alerts (push)
- ❌ Inline "Add to To-Do" buttons
- ❌ Unsubscribe from channels
- ❌ Quick-dial after missed call
- ⚠️ Missed calls — attempt detection via service messages; flag if MCP doesn't expose them

---

## MVP Features (v1)
1. **Morning/Evening Digest** — top news + events from last 12h, adaptive language
2. **Saved Messages Audit** — all saved from last 7 days, grouped by topic
3. **Interest Profile** — auto-built from channel messages, stored in profile.yaml
4. **Opportunity Alerts** — jobs, hawala, tickets detected from profile's inferred interests
5. **Unfulfilled Promises Tracker** — scan personal chats for commitments (from/to user) with no resolution signal; surface in evening digest

---

## Skill Directory Structure

```
~/telegram-digest-bot/skills/telegram-buddy/
├── SKILL.md
├── references/
│   ├── mcp-api.md          # mcp.ai.church OAuth flow, tool schemas, endpoints
│   ├── digest-formats.md   # output templates per digest type
│   └── config-schema.md    # full schema: config.yaml + profile.yaml + state.yaml
└── scripts/
    └── setup.sh            # one-time: create config dirs, install crontab entries
```

### State files (~/telegram-digest-bot/buddy/)
```
config.yaml   # user settings (priority channels, close circle, timezone)
profile.yaml  # auto-updated interest profile (topics, entities, keywords)
state.yaml    # last run timestamps per digest type
```

---

## SKILL.md Frontmatter
```yaml
name: telegram-buddy
description: >
  Intelligent Telegram digest skill. Reads the user's Telegram via mcp.ai.church MCP
  (tools: list_chats, get_messages) and delivers structured digests: morning news,
  evening summary, saved items audit, opportunity alerts. Builds a persistent interest
  profile from message behavior. Triggers on: "telegram-buddy", "morning digest",
  "evening digest", "saved audit", "telegram news", "opportunity alerts".
  State in ~/telegram-digest-bot/buddy/. Requires Bearer token for mcp.ai.church.
```

---

## Digest Workflow

### Morning (07:00) — MVP
1. Read token + config.yaml + profile.yaml (if exists) + state.yaml
2. `list_chats` (limit 50) → get all chats
3. Filter: channels + supergroups → news sources
4. For each: `get_messages` (limit 100) — top-100 messages; Claude picks what matters
5. Saved Messages chat: `get_messages` (limit 100) → last 7 days
6. AI output:
   - **News**: top 5-7 stories, deduped ("3 sources agree on X; diverge on Y")
   - **Events**: date, venue, link
   - **Saved**: grouped by topic, with "you saved this N days ago"
7. Update profile.yaml: extract entity types dynamically (Claude infers what's relevant from content — no fixed list); 30-day TTL on signals
8. Write `last_morning_run` to state.yaml
9. Cold start: if no profile.yaml → create it after step 7; digest still runs in full

### Evening (21:00) — MVP
- Same pipeline, window = since `last_morning_run`
- Add: **Opportunity alerts** — match messages against profile.yaml inferred interests (jobs, exchanges, events, tools)
- Add: **Unfulfilled Promises** — LLM-based scan of personal chats (last 7 days); detect commitments with no follow-up; multilingual; surface: who / what / when
- Add: **Missed calls** — look for service messages containing call-related signals; flag if MCP doesn't expose them (v2)

---

## Token Storage
- File: `~/.telegram-buddy/.token` (chmod 600)
- Skill reads token at startup; if missing/expired → outputs error message to Claude UI with re-auth instructions, exits gracefully
- setup.sh prompts user to paste token post-OAuth and writes it

## Scheduling — launchd (macOS)
`setup.sh` creates two plists in `~/Library/LaunchAgents/`:
- `com.telegram-buddy.morning.plist` — 07:00 daily
- `com.telegram-buddy.evening.plist` — 21:00 daily
- Each plist: sets `PATH`, `ANTHROPIC_API_KEY`, reads token from `~/.telegram-buddy/.token`
- Runs: `claude -p "telegram-buddy: morning-digest"` with logging to `~/telegram-digest-bot/buddy/logs/`
- Timezone: Europe/London (in plist `StartCalendarInterval`)

---

## Implementation Steps (MVP only)

1. **Init** — `init_skill.py telegram-buddy --path ~/telegram-digest-bot/skills/`
2. **mcp-api.md** — OAuth flow, Bearer token from `~/.telegram-buddy/.token`, `list_chats` + `get_messages` schemas
3. **config-schema.md** — config.yaml (close_circle, timezone) + profile.yaml (topics/entities, 30d TTL) + state.yaml
4. **digest-formats.md** — Markdown output templates: morning / evening sections
5. **setup.sh** — create `~/.telegram-buddy/`, write `.token`, create `buddy/` dirs + logs, generate two launchd plists, `launchctl load` them
6. **SKILL.md** — description + workflow (morning/evening) + MCP auth + profile logic + v2 callouts
7. **Package** — `package_skill.py`

---

## Unresolved Questions
None — all confirmed. v2 scope (bot features) is documented in SKILL.md references.

---

## Verification
1. Run `setup.sh` → buddy/ dirs created, crontab installed
2. Manually trigger: `claude -p "telegram-buddy: morning-digest"`
3. Skill calls `list_chats` → gets chats
4. Skill calls `get_messages` on top 5 channels → gets messages
5. Output: structured digest in Claude UI with correct sections
6. profile.yaml updated with extracted topics
