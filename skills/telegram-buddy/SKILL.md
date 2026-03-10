---
name: telegram-buddy
description: >
  Intelligent Telegram digest skill that reads the user's Telegram via mcp.ai.church MCP
  and delivers structured personal digests. Builds a persistent interest profile from
  message behavior to personalize output. Triggers on: "telegram-buddy", "morning digest",
  "evening digest", "saved audit", "telegram news", "opportunity alerts",
  "telegram-buddy: morning-digest", "telegram-buddy: evening-digest".
  Two digest types: morning (07:00, news + saved + events) and evening (21:00, updates +
  opportunities + unfulfilled promises). State files in ~/telegram-digest-bot/buddy/.
  Uses Claude Code's built-in MCP tools (list_chats, get_messages) — no manual token setup required.
---

# Telegram Buddy

## Quick Reference

| File | Purpose |
|------|---------|
| `~/telegram-digest-bot/buddy/config.yaml` | User settings |
| `~/telegram-digest-bot/buddy/profile.yaml` | Interest profile (auto-updated) |
| `~/telegram-digest-bot/buddy/state.yaml` | Last run timestamps |

Reference files (read as needed):
- `references/mcp-api.md` — MCP tool signatures, parameters, response format
- `references/config-schema.md` — YAML file schemas and cold start behavior
- `references/digest-formats.md` — Output templates for morning/evening digest

## Startup Sequence (every run)

1. Read `~/telegram-digest-bot/buddy/config.yaml` — use defaults if missing (see `references/config-schema.md`)
2. Read `~/telegram-digest-bot/buddy/profile.yaml` — create new if missing (cold start)
3. Read `~/telegram-digest-bot/buddy/state.yaml` — use 12h default window if missing
4. Determine digest type from prompt: `morning-digest` or `evening-digest`

## Morning Digest Workflow

1. Call `list_chats` (limit 50) — read `references/mcp-api.md` for call format
2. Filter: keep `type=channel` and `type=supergroup` (news sources); find "Saved Messages" chat (`type=user`, title="Saved Messages" or "Избранное")
3. For each news chat: call `get_messages` (limit 100)
4. For Saved Messages: call `get_messages` (limit 100), filter to last `saved_messages_days` days by `date` field
5. Analyze all messages — read `references/digest-formats.md` for output format:
   - News: top 5-7 stories, deduplicated across sources
   - Events: extract upcoming dates/venues/links (next 14 days)
   - Saved: group by topic cluster
6. Update `profile.yaml` — see Interest Profile Update Rules below
7. Write `last_morning_run` (ISO8601) to `state.yaml`
8. Output formatted morning digest — read `references/digest-formats.md` for template

## Evening Digest Workflow

1. Same startup + `list_chats` + `get_messages` (same as morning)
2. Time window: since `last_morning_run` in `state.yaml` (not fixed 12h)
3. News sources: same as morning pipeline, shorter window
4. Personal chats: fetch `get_messages` from `close_circle` contacts (from `config.yaml`)
5. Opportunity alerts: match messages against `profile.yaml` entities/topics — jobs, exchanges, events, tools
6. Unfulfilled promises: scan personal chats (last `promises_scan_days` days)
   - Use LLM judgment to detect commitments with no resolution
   - Multilingual; avoid false positives
   - Show: who / what / when / which chat
7. Missed calls: scan for service messages with call-related text (📞, "Missed call", "Пропущенный звонок")
   - If not found in MCP output, note: "Missed call detection not available via MCP (v2)"
8. Update `profile.yaml` and write `last_evening_run` to `state.yaml`
9. Output formatted evening digest — read `references/digest-formats.md` for template

## Interest Profile Update Rules (both digest types)

After analyzing messages, update `~/telegram-digest-bot/buddy/profile.yaml`:
- Extract entity types dynamically — no fixed list; infer relevant categories from content
- Merge: if entity exists, increment `mentions`, update `last_seen`
- Add: new entity types freely if they appear consistently
- Prune: remove entries where `last_seen` is older than 30 days
- Update `last_updated` timestamp

## Language Rules

- Output language: adaptive — match dominant language of source messages
- System labels (section headings starting with emoji): always English
- Dates: locale-appropriate format

## v2 Features (not implemented — Telegram Bot required)

The following require Telegram Bot API write access and are deferred to v2:
- Sending digest notifications back to Telegram
- Real-time breaking alerts
- Inline "Add to To-Do" buttons on digest items
- Unsubscribing from channels via digest
- Quick-dial after missed call

## Setup

First-time setup:
```bash
bash ~/telegram-digest-bot/skills/telegram-buddy/scripts/setup.sh
```
