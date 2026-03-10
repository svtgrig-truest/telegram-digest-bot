# MCP API Reference – telegram-buddy

This document defines the Telegram Buddy MCP (Model Context Protocol) API for runtime execution. Claude reads this when executing the skill to make authenticated API calls to the Telegram data service.

## Overview

The telegram-buddy skill connects to a Telegram MCP service that exposes Telegram chat and message data. All communication follows the JSON-RPC 2.0 standard over HTTPS.

**Base URL:** `https://mcp.ai.church/mcp`
**Method:** POST
**Content-Type:** application/json

---

## Authentication

### Token Management

Authentication uses a Bearer token stored in a secure local file:

- **Token location:** `~/.telegram-buddy/.token`
- **File permissions:** Must be `chmod 600` (read/write owner only)
- **Usage:** Include in every request as `Authorization: Bearer <token>`

#### Reading the Token

```bash
TOKEN=$(cat ~/.telegram-buddy/.token)
```

If the file does not exist or is unreadable, treat as an authentication error and prompt the user to re-authenticate.

### Token Expiration & Re-authentication

When a request returns `401 Unauthorized`:

1. **Output error block to user:**
   ```
   ⚠️ telegram-buddy: Bearer token expired.
   Re-authenticate at https://mcp.ai.church, then save new token:
   echo "NEW_TOKEN" > ~/.telegram-buddy/.token && chmod 600 ~/.telegram-buddy/.token
   ```

2. **Stop digest execution** — do not retry the MCP call
3. **User must manually re-authenticate** via Google OAuth 2.0 at the URL above

#### OAuth 2.0 Flow (User-Initiated)

The Telegram MCP service uses Google OAuth 2.0 for authentication:

- User visits: `https://mcp.ai.church`
- Logs in with Google account
- Authorizes Telegram access
- Receives new Bearer token
- Pastes token into local file: `~/.telegram-buddy/.token`

---

## Tool: list_chats

Discover all Telegram chats (DMs, groups, channels) that the authenticated user has access to.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "list_chats",
    "arguments": {
      "limit": 50
    }
  }
}
```

### Parameters

| Parameter | Type   | Range  | Default | Notes |
|-----------|--------|--------|---------|-------|
| limit     | number | 1–100  | 50      | Maximum chats to return; ordered by most recent activity |

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": [
    {
      "id": -1001234567890,
      "title": "Breaking News",
      "type": "channel",
      "unread_count": 5,
      "last_message_timestamp": 1710078600
    },
    {
      "id": 987654321,
      "title": "Alice",
      "type": "user",
      "unread_count": 0,
      "last_message_timestamp": 1710067200
    },
    {
      "id": -1009876543210,
      "title": "Team Chat",
      "type": "group",
      "unread_count": 12,
      "last_message_timestamp": 1710081200
    }
  ]
}
```

### Response Fields

| Field                  | Type    | Notes |
|------------------------|---------|-------|
| id                     | number  | Chat identifier; negative for groups/channels |
| title                  | string  | Display name (channel name, group name, or contact name) |
| type                   | string  | One of: `user` (DM), `group`, `supergroup`, `channel` |
| unread_count           | number  | Number of unread messages in chat |
| last_message_timestamp | number  | Unix timestamp of last message |

### Usage Notes

- Use `list_chats` to enumerate all available chats
- Pass specific `chat_id` and `chat_type` values to `get_messages`
- Results ordered by recency; oldest/least-active chats appear last
- Channels are high-volume sources; filter carefully in `get_messages`

---

## Tool: get_messages

Fetch messages from a specific chat. Messages are returned newest-first; no server-side timestamp filtering is available.

### Request

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "get_messages",
    "arguments": {
      "chat_id": -1001234567890,
      "chat_type": "channel",
      "limit": 100
    }
  }
}
```

### Parameters

| Parameter | Type   | Range  | Default | Notes |
|-----------|--------|--------|---------|-------|
| chat_id   | number | —      | —       | From `list_chats` result; negative for groups/channels |
| chat_type | string | —      | —       | One of: `user`, `group`, `supergroup`, `channel` |
| limit     | number | 1–100  | 30      | Number of messages to fetch (newest-first) |

### Response

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": [
    {
      "id": 999,
      "text": "Breaking: New AI model released",
      "from": "Breaking News",
      "from_id": 112358,
      "is_outgoing": false,
      "date": 1710078600
    },
    {
      "id": 998,
      "text": "Get the full story at https://example.com",
      "from": "Breaking News",
      "from_id": 112358,
      "is_outgoing": false,
      "date": 1710078500
    }
  ]
}
```

### Response Fields

| Field        | Type    | Notes |
|--------------|---------|-------|
| id           | number  | Unique message identifier within chat |
| text         | string  | Message content (may be empty for media-only messages) |
| from         | string  | Sender display name |
| from_id      | number  | Sender user/bot ID |
| is_outgoing  | boolean | True if sent by authenticated user; false if received |
| date         | number  | Unix timestamp of message |

### Usage Notes

- **No server-side filtering:** The MCP service does not support timestamp range queries
- **Client-side filtering required:** After receiving messages, filter by `date` field in Claude code
- **Ordering:** Messages returned newest-first; iterate from index 0 backwards in time
- **Empty text:** Media-only messages may have empty `text` field
- **Always use limit=100 for channels:** News channels are high-volume; fetch full window

---

## Filtering Strategies

### News Channels (High-Volume)

**Goal:** Extract key stories from high-frequency channels.

**Approach:**
1. Call `get_messages(chat_id, chat_type="channel", limit=100)`
2. Fetch latest 100 messages
3. Let Claude's judgment pick what matters (keywords, relevance, summary-ability)
4. Do **not** over-filter; preserve context for Claude to decide importance

**Example:**
```
Channel: "Tech News Daily" (2,000+ msgs/day)
→ Fetch last 100
→ Claude extracts 3–5 summaries
→ Include in digest with context tags
```

### Personal/Group Chats (Moderate Volume)

**Goal:** Capture messages within a recent time window (e.g., last 7 days).

**Approach:**
1. Call `get_messages(chat_id, chat_type="user"|"group", limit=100)`
2. After receiving, filter by `date` field: keep only messages where `date > (now - 7 days)`
3. Summarize per-chat or per-thread as appropriate

**Example:**
```
Chat: "Alice" (personal DM)
→ Fetch last 100 messages
→ Filter: date > (now - 604800 seconds)  // 7 days
→ Include in digest with context
```

### Saved Messages

**Goal:** Fetch user-saved content from the special "Saved Messages" chat.

**Details:**
- Saved Messages is a special auto-DM where users bookmark content
- Appears in `list_chats` as `chat_type: "user"` with a special `id`
- Often contains user's own forwards and bookmarks

**Approach:**
1. Identify Saved Messages chat from `list_chats`
2. Call `get_messages(saved_chat_id, chat_type="user", limit=100)`
3. Filter by recent date if digest covers multiple days
4. Include notable saved items in digest output

### Service Messages & Missed Calls

**Goal:** Track missed calls and important service notifications.

**Current Limitation:**
- The MCP service **may not expose Telegram service messages** (call events, group member changes, etc.)
- Missed calls typically appear as service notifications in Telegram UI but may not be in `get_messages` text
- Common search patterns for call-related messages (if exposed):
  - `"📞"` (phone emoji)
  - `"Пропущенный звонок"` (Russian: "Missed call")
  - `"Missed call"` (English)
  - `"Declined call"` or similar

**Workaround:**
- Search message `text` field for call-related keywords after fetching
- If no matches found, flag as **v2 feature** (requires Telegram Bot API enhancement)
- Note in digest: "Service message integration pending"

---

## Error Handling

### 401 Unauthorized

**Cause:** Bearer token expired or invalid.

**User-facing output:**
```
⚠️ telegram-buddy: Bearer token expired.
Re-authenticate at https://mcp.ai.church, then save new token:
echo "NEW_TOKEN" > ~/.telegram-buddy/.token && chmod 600 ~/.telegram-buddy/.token
```

**Action:** Stop digest execution. Do not retry.

### 400 Bad Request

**Cause:** Invalid parameters (e.g., missing `chat_id`, invalid `chat_type`).

**Debugging:**
- Verify `chat_id` and `chat_type` match values from `list_chats`
- Confirm `limit` is within range 1–100
- Check JSON-RPC request format

### 429 Too Many Requests

**Cause:** Rate limit exceeded (if applicable).

**Action:** Implement exponential backoff; wait before retrying. (Rate limit details TBD by service operator.)

### 500 Internal Server Error

**Cause:** Server-side issue.

**Action:** Retry with backoff; if persistent, report to service operator.

---

## JSON-RPC 2.0 Protocol

All requests use JSON-RPC 2.0 format:

```json
{
  "jsonrpc": "2.0",
  "id": <unique_number>,
  "method": "tools/call",
  "params": {
    "name": "<tool_name>",
    "arguments": { /* tool-specific args */ }
  }
}
```

- **jsonrpc:** Always `"2.0"`
- **id:** Unique request ID (e.g., 1, 2, 3…); used to match responses
- **method:** Always `"tools/call"`
- **params.name:** Tool name (e.g., `"list_chats"`, `"get_messages"`)
- **params.arguments:** Tool-specific parameters object

### Response Format

**Success:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { /* result data */ }
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "Invalid Request"
  }
}
```

---

## Implementation Checklist

- [ ] Read token from `~/.telegram-buddy/.token` on skill startup
- [ ] Check file exists; if missing, prompt user to re-authenticate
- [ ] Include `Authorization: Bearer <token>` in all HTTPS requests
- [ ] Handle `401 Unauthorized` with user-facing error message
- [ ] Call `list_chats(limit=50)` to enumerate all chats
- [ ] For each chat of interest, call `get_messages(chat_id, chat_type, limit=100)`
- [ ] Filter messages by date field (client-side) for time-window queries
- [ ] Parse `text`, `from`, `date`, and `is_outgoing` fields for digest output
- [ ] Log all API calls and responses for debugging
- [ ] Test with mock responses before live execution

---

## Version & Updates

- **Version:** 1.0
- **Last Updated:** 2026-03-10
- **Status:** Production-ready for core tools (`list_chats`, `get_messages`)
- **Future (v2):** Service message integration, call logs, reactions, edits
