---
name: telegram-buddy
description: >
  Intelligent Telegram digest skill that reads the user's Telegram via mcp.ai.church MCP
  and delivers structured personal digests. Builds a persistent interest profile from
  message behavior to personalize output. Triggers on: "telegram-buddy", "morning digest",
  "afternoon digest", "evening digest", "saved audit", "telegram news", "opportunity alerts",
  "jobs digest", "hawala digest", "telegram-buddy: morning-digest",
  "telegram-buddy: afternoon-digest", "telegram-buddy: evening-digest".
  Three digest types: morning (07:00, news + saved + events), afternoon (15:00, jobs +
  hawala + opportunity alerts), evening (21:00, updates + promises + missed calls).
  State files in ~/telegram-digest-bot/buddy/.
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
- `references/digest-formats.md` — Output templates for morning/afternoon/evening digest

## Startup Sequence (every run)

1. Read `~/telegram-digest-bot/buddy/config.yaml` — use defaults if missing (see `references/config-schema.md`)
2. Read `~/telegram-digest-bot/buddy/profile.yaml` — create new if missing (cold start)
3. Read `~/telegram-digest-bot/buddy/state.yaml` — use 12h default window if missing
4. Determine digest type from prompt: `morning-digest`, `afternoon-digest`, or `evening-digest`

## Morning Digest Workflow

1. Call `list_chats` (limit 50) — read `references/mcp-api.md` for call format
2. Filter: keep `type=channel` and `type=supergroup` (news sources); find "Saved Messages" chat (`type=user`, title="Saved Messages" or "Избранное")
3. For each news chat: call `get_messages` (limit 100)
4. For Saved Messages: call `get_messages` (limit 100), filter to last `saved_messages_days` days by `date` field
5. Scan `event_sources` from `config.yaml` (call `get_messages` limit 100 for each):
   - Fetch window: same as the digest window (since `last_morning_run`, or 12h on cold start)
   - Display filter: show only events whose date falls within the next 14 days from today
   - Do NOT use a fixed 14-day fetch window on every run — only fetch new messages since last run
6. Analyze all messages — read `references/digest-formats.md` for output format:
   - News: top 5-7 stories, deduplicated across sources
   - Events: from step 5, display up to 14-day horizon; link each event to its source message (see digest-formats.md § Telegram Message Deep Links)
   - Saved: group by topic cluster
7. Update `profile.yaml` — see Interest Profile Update Rules below
8. Write `last_morning_run` (ISO8601) to `state.yaml`
9. Send email — see Email Delivery section below
10. Output formatted morning digest — read `references/digest-formats.md` for template

## Afternoon Digest Workflow

Focused entirely on opportunities: jobs, currency/hawala, and timely alerts.

1. Read `opportunity_sources` from `config.yaml`
2. Fetch window: since `last_morning_run` in `state.yaml` (or 8h on cold start)
3. For each source: call `get_messages` (limit 100) within the fetch window
4. **Jobs & Roles** section:
   - Filter for actual job postings (not meta-chat)
   - Match against `profile.yaml` interests/entities to rank relevance
   - Show: role, company, stack/domain, Telegram message deep link — top 5-8 most relevant
5. **Currency / Hawala** section:
   - Extract exchange rate posts, service announcements, limits changes
   - Show: rates (GBP/RUB, EUR/RUB, USD/RUB if present), key service updates, Telegram message deep link
   - Deep link construction: see `references/digest-formats.md` § Telegram Message Deep Links
6. Update `profile.yaml` (opportunity signals — roles seen, skills mentioned)
7. Write `last_afternoon_run` (ISO8601) to `state.yaml`
8. Send email — see Email Delivery section below
9. Output formatted afternoon digest — read `references/digest-formats.md` for template

## Evening Digest Workflow

1. Same startup + `list_chats` + `get_messages` (same as morning)
2. Time window: since `last_afternoon_run` (or `last_morning_run` if afternoon not run) in `state.yaml`
3. News sources: same as morning pipeline, shorter window
4. Personal chats: fetch `get_messages` from `close_circle` contacts (from `config.yaml`)
5. Opportunity alerts: quick rescan of `opportunity_sources` for anything since afternoon run
6. Unfulfilled promises: scan personal chats (last `promises_scan_days` days)
   - Use LLM judgment to detect commitments with no resolution
   - Multilingual; avoid false positives
   - Show: who / what / when / which chat
7. Missed calls: scan for service messages with call-related text (📞, "Missed call", "Пропущенный звонок")
   - If not found in MCP output, note: "Missed call detection not available via MCP (v2)"
8. Update `profile.yaml` and write `last_evening_run` to `state.yaml`
9. Send email — see Email Delivery section below
10. Output formatted evening digest — read `references/digest-formats.md` for template

## Cold-Start / No Channels Configured

If `event_sources` is empty (morning/evening) or `opportunity_sources` is empty (afternoon):

1. Call `list_chats` (limit 100) to discover the user's Telegram channels
2. Group results by type: channels, supergroups, saved messages, personal chats
3. Output a formatted table: `chat_id`, `name`, `type`, `unread_count`
4. Print instructions:
   ```
   Add channels to ~/telegram-digest-bot/buddy/config.yaml to get a full digest:
   event_sources:
     - chat_id: <id>
       name: "<name>"
       type: <type>
   ```
5. Still run the digest using only Saved Messages (morning/evening) — skip opportunity sections (afternoon) if no sources configured

## Email Delivery

If `email_digest_to` is set in `config.yaml`, send the digest by email after generating content:

1. Compose subject:
   - Morning: `🌅 Morning Digest — {DD Mon YYYY}`
   - Afternoon: `☀️ Afternoon Digest — {DD Mon YYYY}`
   - Evening: `🌙 Evening Digest — {DD Mon YYYY}`

2. Create Gmail draft using the `gmail_create_draft` tool:
   - `to`: value of `email_digest_to` from config
   - `subject`: as above
   - `body`: full digest text (plain text, same as stdout output)
   - `contentType`: `text/plain`
   - Note the returned `draftId`

3. Send the draft via Bash:
   ```bash
   GWS_BIN=$(find ~/.nvm -name "gws" -type f 2>/dev/null | head -1)
   "$GWS_BIN" gmail users drafts send --params '{"userId": "me"}' --json '{"id": "DRAFT_ID"}'
   ```
   Replace `DRAFT_ID` with the `draftId` from step 2.

4. If send fails: log the error to stderr and continue — do NOT abort the digest output.

If `email_digest_to` is absent or empty: skip this section entirely.

## Interest Profile Update Rules (all digest types)

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
