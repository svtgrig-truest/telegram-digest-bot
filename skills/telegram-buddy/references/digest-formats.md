# Digest Format Reference

This document defines the Markdown output templates for Telegram Buddy digest generation. These formats are consumed by Claude at runtime to structure digest output for the user.

---

## Morning Digest

The morning digest covers: news, events, saved messages audit.

```
# 🌅 Morning Digest — {date} ({channel_count} channels scanned)

## 📰 Top Stories

### {Story headline — in language of original content}
*{3 sources} • {time range}*

{2-3 sentence summary of the story. If multiple sources: "Reuters and BBC agree on X. The Guardian adds Y."}

**Sources:** [{Source 1}]({url}) · [{Source 2}]({url})

---
### {Story 2 headline}
...

*(Show 5–7 top stories. Group related ones. Omit if fewer than 2 sources mention it.)*

---

## 📅 Events This Week

| Event | Date | Where | Source |
|-------|------|--------|--------|
| {Event name} | {Date} | {City/Online} | [{Channel name}]({telegram_message_link}) |

*(Show if date is in next 14 days. Skip if no events found — omit section entirely.)*
*(Include registration link inline if available: e.g. "**{Event}** — [Register]({reg_url}) · [Source]({tg_link})")*

---

## 🔖 Saved Messages Audit — Last 7 Days

**{N} items saved since {date}**

### {Topic cluster 1}
- **[{Title or description}]({url if available})** — saved {N} days ago
  *{1 sentence about what this is}*
- **{Item 2}** — saved {N} days ago

### {Topic cluster 2}
...

*(Group by topic. If only 1 item in a cluster, don't create sub-heading. Max 15 items total.)*

---
*Generated {timestamp} · Next: Afternoon Digest at 15:00 · Evening Digest at 21:00*
```

---

## Afternoon Digest

The afternoon digest covers: jobs & roles, currency / hawala rates, opportunity alerts.

```
# ☀️ Afternoon Digest — {date} (Opportunities)

## 💼 Jobs & Roles

*(Top 5–8 most relevant postings, ranked against profile.yaml interests)*

- **{Role title}** at {Company} · {stack/domain tags}
  {1-sentence job description}
  [{Source channel}]({telegram_message_link}) · {date posted}

---

## 🔁 Currency / Hawala

*(Exchange rates, service announcements, limits updates from ruХавала etc.)*

- **{Currency pair}**: {rate or service update}
  [{Source channel}]({telegram_message_link}) · {time}

---

## 🎫 Tickets & Events (Spare / For Sale)

*(Tickets being given away or sold — from Как Мне Театр в Лондоне etc.)*

- **{Show / Event name}** — {date}, {venue}
  {price or free} · [{Source}]({telegram_message_link}) · {posted time}

---

## 🛠️ Other Opportunities

*(Tools, beta launches, referral programs — only if matched against profile)*

- **{Item}** — {why relevant} · [{Source}]({telegram_message_link})

---
*Generated {timestamp} · Next: Evening Digest at 21:00*
```

---

## Evening Digest

The evening digest covers: news updates, opportunity alerts, unfulfilled promises, (optionally) close circle highlights.

```
# 🌙 Evening Digest — {date}

## 📰 Updates Since Morning

{2-4 bullet points of significant developments since morning digest. Skip if nothing notable.}

---

## 💡 Opportunity Alerts

*(Only show if profile.yaml has signals. Skip section entirely if no matches found.)*

### 💼 Jobs & Roles
- **{Role title}** at {Company} · {Source chat} · {date}
  {1-sentence description} → [link if available]

### 🔁 Currency / Hawala
- **{Currency pair}** {rate details} · {Source chat} · {time}
  {Context: who, what direction}

### 🎫 Events & Tickets
- **{Event}** — tickets available · {source} · {date}

### 🛠️ Tools & Opportunities
- **{Tool name}** — {why relevant based on profile} · {source}

---

## ⚠️ Unfulfilled Promises

*(Only show if commitments detected. Skip section if none.)*

**{N} open commitments found:**

| Who | What | When | Chat |
|-----|------|------|------|
| You → {Name} | "{commitment text}" | {N} days ago | {chat name} |
| {Name} → You | "{commitment text}" | {N} days ago | {chat name} |

*(LLM-detected from personal chat history. May have false positives — use judgment.)*

---

## 👥 Close Circle

*(Only show if close_circle contacts have new messages in last 12h.)*

- **{Name}**: {1-sentence summary of what they said/asked}

---
*Generated {timestamp} · Next: Morning Digest at 07:00*
```

---

## Language Rules

- **Content language**: Use the language of the original content for headlines and summaries
- **Mixed language digests**: If a section mixes languages (e.g. Russian + English channels), use the dominant language for section headers
- **System labels**: Always in English (🌅 Morning Digest, 📰 Top Stories, etc.)
- **Date format**: Locale-appropriate
  - English: `DD Mon YYYY` (e.g., 10 Mar 2026)
  - Russian: `DD месяц YYYY` (e.g., 10 мар 2026)

---

## Empty State Rules

- **Empty section**: If a section has no content → omit the section entirely (no "nothing found" messages)
- **Empty digest**: If the entire digest is empty, output:
  ```
  # 🌅 Morning Digest — {date}

  *No new content in the last {N} hours.*
  ```

---

## Implementation Notes

### Top Stories Selection Criteria
- Require minimum 2 sources mentioning the same story
- Show 5–7 top stories per digest
- Group related stories together
- Summarize agreement/disagreement between sources ("Reuters and BBC agree on X. The Guardian adds Y.")

### Telegram Message Deep Links

Always link to the source message rather than just naming the channel:

- **Public channel** (has username): `https://t.me/{username}/{message_id}`
- **Private channel / supergroup** (no username): `https://t.me/c/{clean_id}/{message_id}`
  where `clean_id = str(abs(chat_id))[3:]` — strips the `-100` prefix Telegram adds to channel IDs
  Example: `chat_id = -1001317878880` → `clean_id = "1317878880"` → `https://t.me/c/1317878880/42`
- **Fallback**: if message_id is unavailable, link to the channel directly

Apply to: all event source items, all opportunity alert items (jobs, hawala, tools).

### Events Section
- Show only if event date is in next 14 days
- Include: Event name, date, location (City/Online), Telegram message deep link as source
- If a registration/external URL is also in the message text, show it alongside the source link
- Omit section entirely if no upcoming events

### Saved Messages Audit
- Cover last 7 days only
- Group by topic cluster (max 15 items total)
- Include: title/description, save age (days ago), 1-sentence context
- For single-item clusters, don't create a sub-heading

### Opportunity Alerts
- Only display if user profile contains matching signals
- Skip section entirely if no opportunities match
- Categories: Jobs & Roles, Currency/Hawala, Events & Tickets, Tools & Opportunities
- Include source chat and date/time for each alert

### Unfulfilled Promises
- LLM-detected from personal chat history
- Only show if commitments found
- Caveat: "May have false positives — use judgment"
- Omit section if none detected

### Close Circle
- Only display if contacts in close_circle have new messages in last 12 hours
- Show 1-sentence summary per contact
- Omit section if no recent messages from close circle

---

*Last updated: 2026-03-10*
