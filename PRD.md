# Product Requirements Document
## Telegram Digest Bot
**An intelligent daily digest for Telegram via MCP integration**

| Field | Value |
|---|---|
| Version | 0.1 — Draft |
| Status | In Review |
| Product type | Telegram bot / Claude Skill via custom MCP |
| Target users | Power Telegram users dealing with high-volume content streams |

---

## 1. Product Overview

Telegram Digest Bot connects to the user's account via MCP and automatically compiles a structured summary of all activity over a chosen time window. The product pursues four goals:

- Free the user from manually opening every channel, chat, and group.
- Help the user extract maximum value from subscribed content and overcome FOMO.
- Improve the quality of the user's communication with their contacts.
- Help the user discover relevant information beyond their existing subscriptions *(version 2)*.

> **North Star**: The user should never feel they are drowning in unprocessable information. They should feel that their entire Telegram space is working for them.

---

## 2. Short-Context Triggers

*Processed within the current day or within a few hours.*

### 2.1 Unanswered Inbound

#### 2.1.1 Missed Calls

- Detect any missed call from any contact.
- Remind the user to call back within 1 hour.
- Reminder format: contact name, time of call, quick-dial button.

#### 2.1.2 Personal Messages from Close Contacts

- Surface messages from contacts marked as "close circle" (user-configurable).
- Notify the user with `@` within 2 hours if the message remains unread.
- Show a message preview.

---

### 2.2 News Channels — Digest

Aggregation of posts from subscribed news channels over the selected period.

- Three digest modes: **morning**, **evening**, **breaking** (keyword / urgent-flag triggered).
- Aggregated top 5–7 stories for the period, each with a bunch of source links.

---

### 2.3 Unfulfilled Promises & Requests

Tracking commitments mentioned in conversations (both from and to the user) that have no confirmation of completion.

- If there are no updates after X hours — remind the user.
- Offer to add the item to the to-do list.

---

### 2.4 Upcoming Events

Events mentioned in channels and chats: concerts, conferences, webinars, meetups.

- Format: title, date, short description, link to tickets / registration.
- Before inclusion in the digest — auto-check: are tickets still available and has the registration deadline passed?
- User can add the event to their to-do list.
- Sorted by proximity of date.

---

### 2.5 Personalised Updates (Recommendation Layer)

> This module is built on behavioural analysis: what the user reads, likes, comments on, forwards, and saves to Favourites.

#### 2.5.1 Interest Profile *(built from long-term context)*

Analyse topics and entities from messages the user:

- opened or read to the end
- commented on or reacted to
- saved to Favourites
- forwarded

Use the profile to track relevant channels and groups.

#### 2.5.2 Topic-Based Digest

- Brief summary of similar messages for the period (morning / evening).
- Grouped by topic, diversified by source.

#### 2.5.3 Videos & Podcasts

- Extended summary based on the transcript — enough for the user to decide whether it is worth watching.
- Duration, source, key takeaways.
- "Add to to-do / watch later" option.

#### 2.5.4 Active Discussion Recommendations

- Identify threads and discussions with high activity on topics from the user's profile.
- Suggest joining with a brief context summary.

#### 2.5.5 Opportunity Alerts

> Real-time notifications — sent immediately, outside the regular digest schedule. Bot should discover new types of such opportunities.

- Currency exchange offers in Hawala-style chats (e.g. "GBP/RUB above X to bank Y").
- Job postings: matched to keywords and companies from the user's interest profile.
- Concert and theatre tickets: alert when they go on sale.
- Ping the user immediately when a match against configured criteria is found.

#### 2.5.6 Long Reads

- No summarisation — just a listing with a 1–2 sentence description and a link.
- The user decides whether to read now or save for later.

---

## 3. Long-Context Triggers

*Processed on a weekly, monthly, or quarterly horizon.*

### 3.1 Unopened Favourites — Weekly Snapshot

- Once a week (e.g. Friday evening or Saturday morning) — generate a ranked list of saved but unreviewed items. For saved videos, apply the transcript-summary logic from section 2.5.3.
- Ranking: topic relevance + social validation signals (likes, views, etc. accumulated since saving).
- Presented as a "weekend list": compact, with **Add to To-Do** button per item.

---

### 3.2 Flashcards from Language Channels

- Collect words, phrases, and constructions from language-learning channels over the week.
- Card format: word / phrase — translation — image — example from the original post. *(Integration with NotebookLM under consideration.)*
- Delivery: once a week as a mini-review session.

---

### 3.3 Communication Patterns — Weekly Report

- Who the user communicates with more or less frequently than usual.
- Who initiated conversations (vs. the user).
- Detection of potential manipulation patterns in conversations.

> ⚠️ **TBD** — scope and implementation details to be defined.

---

### 3.4 Missed Birthdays

- Detect past birthday greetings sent by the user (fact-extraction approach, not user-entered dates — replicating the Facebook mechanic organically).
- Remind the user at the exact date so the birthday is not missed this year.

---

### 3.5 Channels to Archive — Quarterly Audit

- Once a quarter — analyse activity for each channel: posting frequency, read-through rate, user reactions.
- Produce a list of archiving / unsubscribe candidates with a brief rationale, including notes on content duplication and secondary / derivative sources.
- The user reviews and confirms each item; the bot then executes the unsubscribe action.

---

## 4. To-Do Integration

Multiple modules generate tasks. A single, unified mechanism handles all additions:

- Inline **"+ Add to To-Do"** button on every digest card.
- Deduplication: if a similar task already exists, warn the user before adding.

---

## 5. Schedule & Delivery

| Cadence | Time | Content |
|---|---|---|
| Morning digest | 07:00–09:00 | News, events, updates, videos |
| Evening digest | 19:00–21:00 | Day summary, unread messages, recommendations |
| Breaking alert | On trigger | Breaking news, opportunity alerts, missed calls |
| Weekly report | Fri–Sat | Favourites, flashcards, communication patterns |
| Quarterly audit | Quarterly | Channels to archive / unsubscribe |

> Timing and frequency are configured by the user during initial bot setup.
