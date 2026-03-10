# MCP Tool Reference – telegram-buddy

This document defines how to invoke Telegram MCP tools at runtime. The tools are provided
by the `ai-church` MCP server configured in `~/.claude/.mcp.json` and are available as
native Claude Code tool calls — no HTTP requests or Bearer tokens required.

---

## Authentication

No manual token handling. Authentication is managed by Claude Code's built-in OAuth session
for the `ai-church` MCP server. If the session is expired, Claude Code will prompt for
re-authentication automatically.

**If tools are unavailable** (not listed in the active session):
```
⚠️ telegram-buddy: Telegram MCP tools not available.
Ensure the ai-church server is connected:
  claude mcp list
If missing, add it:
  claude mcp add --transport http --scope user ai-church https://mcp.ai.church/mcp
Then re-authenticate at https://mcp.ai.church and restart.
```

---

## Tool: list_chats

Returns all Telegram chats the user has access to.

### Parameters

| Parameter | Type   | Required | Description                    |
|-----------|--------|----------|--------------------------------|
| `limit`   | number | No       | Max chats to return (use 50)   |

### Example Call

```
Use the list_chats tool with limit: 50
```

### Response Fields (per chat)

| Field          | Type   | Description                                                  |
|----------------|--------|--------------------------------------------------------------|
| `id`           | number | Unique Telegram chat identifier                              |
| `title`        | string | Chat display name (e.g. "BBC News", "Saved Messages")        |
| `type`         | string | `user`, `group`, `supergroup`, or `channel`                  |
| `unread_count` | number | Number of unread messages                                    |

### Filtering Strategy

After calling `list_chats`, filter the result set:

- **News sources**: keep `type = "channel"` and `type = "supergroup"`
- **Saved Messages**: find `type = "user"` with `title = "Saved Messages"` or `"Избранное"`
- **Close circle**: match `id` against `close_circle[].chat_id` in `config.yaml`

---

## Tool: get_messages

Returns recent messages from a specific chat.

### Parameters

| Parameter   | Type   | Required | Description                                  |
|-------------|--------|----------|----------------------------------------------|
| `chat_id`   | number | Yes      | Chat identifier (from `list_chats` response) |
| `chat_type` | string | Yes      | `"user"`, `"group"`, `"supergroup"`, or `"channel"` |
| `limit`     | number | No       | Max messages to return (use 100)             |
| `offset_id` | number | No       | Return messages older than this ID (pagination) |

### Example Call

```
Use the get_messages tool with chat_id: <id>, chat_type: "channel", limit: 100
```

### Response Fields (per message)

| Field         | Type    | Description                                             |
|---------------|---------|---------------------------------------------------------|
| `id`          | number  | Unique message ID within the chat                       |
| `text`        | string  | Message text content (may be empty for media-only)      |
| `from`        | string  | Sender display name                                     |
| `from_id`     | number  | Sender's Telegram user ID                               |
| `is_outgoing` | boolean | `true` if sent by the authenticated user                |
| `date`        | number  | Unix timestamp (seconds since epoch)                    |

### Time Filtering (client-side)

The MCP API does not support server-side date filters. Always fetch limit 100, then
filter by `date` field:

```
# Morning digest window (last 12 hours)
cutoff = now() - window_hours * 3600
messages = [m for m in raw_messages if m.date >= cutoff]

# Saved Messages
cutoff = now() - saved_messages_days * 86400
saved = [m for m in raw_messages if m.date >= cutoff]
```

### Pagination

If 100 messages don't cover the full time window, use the smallest `id` from the current
batch as `offset_id` in the next call. For typical digest windows a single fetch suffices.

---

## Calling Pattern (Morning Digest)

```
1. list_chats (limit: 50)
2. For each channel/supergroup → get_messages (limit: 100)
3. get_messages for Saved Messages chat
```

## Calling Pattern (Evening Digest)

```
1. list_chats (limit: 50)
2. For each channel/supergroup → get_messages (limit: 100)
3. For each close_circle contact → get_messages (limit: 100)
```

---

## Error Handling

| Scenario | Action |
|----------|--------|
| Tool not found in session | Output setup instructions (see Authentication above) |
| Empty response | Skip that chat — no new messages |
| Missing `text` on a message | Skip — media-only message |
| Rate limit / timeout | Retry once; note in digest and continue |

---

*Last updated: 2026-03-10*
