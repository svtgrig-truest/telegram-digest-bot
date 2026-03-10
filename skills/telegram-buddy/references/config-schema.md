# Telegram Buddy Configuration Schema

This document defines the three YAML state files used by the telegram-buddy skill. These files live in `~/telegram-digest-bot/buddy/` and are read/written by Claude at runtime to deliver personalized Telegram digests.

---

## 1. config.yaml — User Settings (Manually Edited)

The primary configuration file. Users edit this directly to customize skill behavior. All fields have sensible defaults if omitted, so the skill remains functional even with a minimal or empty config.

### Schema

```yaml
timezone: string              # IANA timezone (e.g., "Europe/London", "America/New_York")
email_digest_to: string       # (optional) Email address to send each digest to after generation
close_circle: array[object]   # Contacts whose personal messages are highlighted
  - name: string              # Friendly name for the contact
    chat_id: number           # Telegram chat_id (from list_chats output)
    chat_type: string         # "user", "group", "supergroup", or "channel"
morning_digest: object
  hour: number                # Hour of day (0-23) to run morning digest
  window_hours: number        # Look back this many hours for messages
afternoon_digest: object      # Opportunity digest (jobs, hawala) — runs between morning & evening
  hour: number                # Hour of day (0-23), e.g. 15
  window_hours: number        # Look back since last_morning_run (typically 8)
evening_digest: object
  hour: number                # Hour of day (0-23) to run evening digest
  window_hours: number        # Look back since last_afternoon_run (or last_morning_run)
saved_messages_days: number   # How many days of Saved Messages to audit (optional)
promises_scan_days: number    # How many days of personal chats to scan for promises (optional)

event_sources: array[object]  # Channels scanned for upcoming events (both digest types)
  - chat_id: number
    name: string
    type: string              # "channel", "supergroup", or "user"

opportunity_sources: array[object]  # Channels scanned for the afternoon opportunity digest only
  - chat_id: number
    name: string
    type: string              # "channel", "supergroup", or "user"
```

### Example config.yaml

```yaml
timezone: "Europe/London"
email_digest_to: "you@gmail.com"   # omit to disable email delivery

close_circle:
  - name: "Anna"
    chat_id: 123456789
    chat_type: "user"

morning_digest:
  hour: 7
  window_hours: 12

afternoon_digest:
  hour: 15
  window_hours: 8

evening_digest:
  hour: 21
  window_hours: 12

saved_messages_days: 7
promises_scan_days: 7

event_sources:
  - chat_id: 1317878880
    name: "Афиша | Лондон | Журнал"
    type: channel

opportunity_sources:
  - chat_id: 1657270017
    name: "ruХавала"
    type: supergroup
  - chat_id: 1088399568
    name: "Products Jobs"
    type: supergroup
```

### Field Details

- **timezone**: IANA timezone string. Used to determine digest run times and interpret timestamps in the user's local context. Example: `"Europe/London"`, `"America/Los_Angeles"`, `"Asia/Tokyo"`.

- **close_circle**: Array of contact objects. Messages from these chats receive special highlighting in the evening digest. Each contact must reference a real Telegram chat that the user has access to. The `chat_id` and `chat_type` come directly from the output of `list_chats` MCP calls.
  - **name**: Human-readable label (displayed in digest headers).
  - **chat_id**: Unique Telegram identifier for the chat (integer).
  - **chat_type**: One of `"user"` (personal DM), `"group"`, `"supergroup"`, or `"channel"`.

- **morning_digest**: Configures the morning digest run.
  - **hour**: Hour of day to execute (0-23). Example: `7` = 7:00 AM in user's timezone.
  - **window_hours**: Number of hours to look back. Example: `12` = last 12 hours of messages.

- **evening_digest**: Configures the evening digest run.
  - **hour**: Hour of day to execute (0-23). Example: `21` = 9:00 PM.
  - **window_hours**: Number of hours to span. For most use cases, set to 12 so the window bridges the gap between morning and evening runs.

- **saved_messages_days** (optional): Number of recent days to scan for Saved Messages that may contain action items or insights. Defaults to 7 if missing. Set to 0 to disable.

- **promises_scan_days** (optional): Number of recent days to scan personal chat history for unfulfilled promises, commitments, or TODOs mentioned by the user or close contacts. Defaults to 7 if missing. Set to 0 to disable.

### Defaults

If config.yaml is missing or fields are omitted, these defaults apply:

```yaml
timezone: "UTC"
close_circle: []
morning_digest:
  hour: 8
  window_hours: 12
afternoon_digest:
  hour: 15
  window_hours: 8
evening_digest:
  hour: 20
  window_hours: 12
saved_messages_days: 7
promises_scan_days: 7
event_sources: []
opportunity_sources: []
```

---

## 2. profile.yaml — Interest Profile (Auto-Updated by Skill)

A dynamically generated profile that evolves as Claude processes digest runs. This file tracks entities and topics mentioned in the user's channels, drives opportunity alerts, and enables personalization of digest content.

**This file is NOT manually edited.** It is created and updated by Claude after each digest run based on signal extraction from processed messages.

### Schema

```yaml
last_updated: string          # ISO8601 timestamp of last update
ttl_days: number              # Signals older than this are pruned on each run (typically 30)

entities: object              # Auto-detected entity types (keys are dynamically created)
  [entity_type]: array[object]
    - name: string            # Entity name (e.g., "Claude Code", "Anthropic")
      mentions: number        # Cumulative mention count
      last_seen: string       # ISO8601 date of most recent mention
      context: string         # Brief context about why it's relevant (optional)

topics: array[object]         # Named themes extracted from message content
  - name: string              # Topic name (e.g., "AI agents", "expat finance UK")
    mentions: number          # Cumulative mention count
    last_seen: string         # ISO8601 date of most recent mention
```

### Example profile.yaml

```yaml
last_updated: "2026-03-10T07:15:00Z"
ttl_days: 30

entities:
  ai_tools:
    - name: "Claude Code"
      mentions: 12
      last_seen: "2026-03-09"
      context: "productivity, coding assistant"
    - name: "Cursor"
      mentions: 5
      last_seen: "2026-03-07"
      context: "IDE, considering switch to Claude Code"
  companies:
    - name: "Anthropic"
      mentions: 8
      last_seen: "2026-03-09"
    - name: "OpenAI"
      mentions: 3
      last_seen: "2026-03-06"
  events:
    - name: "AI Summit London"
      mentions: 3
      last_seen: "2026-03-08"
      context: "conference, April 2026"
  frameworks:
    - name: "Next.js"
      mentions: 7
      last_seen: "2026-03-10"
  job_roles:
    - name: "Senior Prompt Engineer"
      mentions: 2
      last_seen: "2026-03-08"

topics:
  - name: "AI agents"
    mentions: 45
    last_seen: "2026-03-09"
  - name: "expat finance UK"
    mentions: 12
    last_seen: "2026-03-08"
  - name: "Claude Code vs Cursor"
    mentions: 7
    last_seen: "2026-03-09"
  - name: "agent scaffolding"
    mentions: 4
    last_seen: "2026-03-10"
```

### Updating Rules

After each digest run, Claude performs these operations on profile.yaml:

1. **Extract signals** from all messages processed in the digest window
   - Identify entities (tools, companies, people, events, frameworks, job roles, currencies, etc.)
   - Identify recurring topics and themes
   - Entity types are **not fixed** — Claude dynamically creates new entity categories as needed

2. **Merge with existing entries**
   - If entity already exists: increment `mentions` and update `last_seen`
   - If entity is new: add it to the appropriate entity_type array with `mentions: 1`
   - Add or update `context` field if additional insight is discovered

3. **Prune stale entries**
   - Remove any entry where `last_seen` is older than `ttl_days` (default 30 days)
   - This prevents the profile from becoming bloated with obsolete interests

4. **Add new entity types freely**
   - If Claude detects meaningful categories not yet in the profile (e.g., `currencies`, `travel_destinations`, `health_topics`), add them as new keys under `entities`
   - New types should follow snake_case naming

5. **Update last_updated**
   - Set to current ISO8601 UTC timestamp after modifications

### Purpose in Digest Generation

The profile is read during digest generation to:
- **Prioritize content**: Messages mentioning high-mention entities or topics float to the top
- **Alert on opportunities**: If a low-mention entity suddenly appears frequently, flag it as an opportunity (e.g., a new framework gaining traction)
- **Personalize summaries**: Summarize content in language familiar to the user's known interests

---

## 3. state.yaml — Runtime State (Written by Skill, Read-Only)

Tracks the timestamps of the last successful digest runs. This file is **written by Claude after each run** and **read by the skill** to determine digest windows and avoid message duplication.

**Users should not manually edit this file.** It is created and maintained automatically.

### Schema

```yaml
last_morning_run: string      # ISO8601 UTC timestamp of last successful morning digest
last_afternoon_run: string    # ISO8601 UTC timestamp of last successful afternoon digest
last_evening_run: string      # ISO8601 UTC timestamp of last successful evening digest
version: string               # Schema version (currently "1.0")
```

### Example state.yaml

```yaml
last_morning_run: "2026-03-10T07:15:32Z"
last_afternoon_run: "2026-03-10T15:02:44Z"
last_evening_run: "2026-03-09T21:03:11Z"
version: "1.0"
```

### Runtime Behavior

- **Morning run**: After executing the morning digest, Claude writes the completion timestamp to `last_morning_run`
- **Afternoon run**: Uses `last_morning_run` as the window start. After completion, writes timestamp to `last_afternoon_run`
- **Evening run**: Uses `last_afternoon_run` as the window start (falls back to `last_morning_run` if afternoon was skipped). After completion, writes timestamp to `last_evening_run`
- **Window calculation**:
  - Morning digest window: `[now - morning_digest.window_hours, now]`
  - Afternoon digest window: `[last_morning_run, now]`
  - Evening digest window: `[last_afternoon_run or last_morning_run, now]`

### Why This Matters

By anchoring the evening window to `last_morning_run` rather than a fixed 12-hour lookback:
- Messages are never duplicated across runs even if schedules slip
- No message gaps if a run is skipped or delayed
- The system remains resilient to timing variations

---

## Cold Start Behavior

When the skill starts on a fresh system or user account, one or more state files may be missing. The skill handles each scenario gracefully:

### config.yaml Missing or Empty

**Behavior**: Skill proceeds with all defaults and generates a full digest with standard settings (no close_circle highlighting, UTC timezone, default digest hours).

**Action**: No config.yaml is created. User must manually create it if they want custom settings.

**Result**: Digest is functional but generic.

### profile.yaml Missing

**Behavior**:
- Run full digest with no personalization (all messages treated equally, no entity highlighting)
- After the run, Claude creates profile.yaml from signals extracted during this first digest
- The new profile.yaml becomes the baseline for future personalization

**Action**: profile.yaml is automatically created with `last_updated` set to current timestamp.

**Result**: First digest has no personalization, but future digests benefit from the extracted profile.

### state.yaml Missing

**Behavior**:
- Treat as first run
- Morning digest uses default 12-hour lookback window (not anchored to a previous run)
- Evening digest uses the same 12-hour window or a fixed lookback
- After each run, state.yaml is created/updated with the completion timestamps

**Action**: state.yaml is created after the first morning run, then updated after each subsequent run.

**Result**: First digest may include older messages (up to 12 hours back), but future runs use proper continuity anchoring.

### All Files Missing (Fresh Install)

**Sequence**:
1. Skill runs morning digest with defaults and 12-hour lookback
2. Creates state.yaml with `last_morning_run` timestamp
3. Extracts signals and creates profile.yaml
4. Evening digest reads state.yaml, uses `last_morning_run` as anchor, runs, updates state.yaml
5. User can now create/edit config.yaml to customize

**Result**: Skill is fully operational within one morning-evening cycle. User can customize by editing config.yaml at any time.

---

## Summary

| File | Purpose | Manual Edit | Auto-Created |
|------|---------|------------|--------------|
| **config.yaml** | User preferences (timezone, contacts, digest times) | Yes | No |
| **profile.yaml** | Interest tracking and personalization data | No | Yes, after first run |
| **state.yaml** | Run timestamps for window continuity | No | Yes, after first run |

All three files are resilient to absence, allowing the skill to function gracefully even on cold start.
