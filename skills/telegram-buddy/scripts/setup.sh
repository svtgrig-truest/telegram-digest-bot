#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

info()    { echo -e "${GREEN}$*${RESET}"; }
warn()    { echo -e "${YELLOW}WARNING: $*${RESET}"; }
error()   { echo -e "${RED}ERROR: $*${RESET}"; exit 1; }

# ─── Step 1: Create directories ───────────────────────────────────────────────
info "Step 1: Creating directories..."
mkdir -p ~/telegram-digest-bot/buddy/logs
info "  Directories ready."

# ─── Step 2: Initialize config.yaml ──────────────────────────────────────────
CONFIG_FILE="$HOME/telegram-digest-bot/buddy/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
  info "Step 2: Config exists, skipping."
else
  info "Step 2: Writing default config.yaml..."
  cat > "$CONFIG_FILE" <<'EOF'
timezone: "Europe/London"
close_circle: []
morning_digest:
  hour: 7
  window_hours: 12
evening_digest:
  hour: 21
  window_hours: 12
saved_messages_days: 7
promises_scan_days: 7
EOF
  info "  Config written to $CONFIG_FILE"
fi

# ─── Step 3: Detect claude binary path ───────────────────────────────────────
info "Step 3: Detecting claude binary..."
CLAUDE_BIN=$(which claude 2>/dev/null || true)
if [ -z "$CLAUDE_BIN" ]; then
  for p in /opt/homebrew/bin/claude /usr/local/bin/claude ~/.local/bin/claude; do
    if [ -x "$p" ]; then
      CLAUDE_BIN="$p"
      break
    fi
  done
fi
if [ -z "$CLAUDE_BIN" ]; then
  error "claude binary not found. Install Claude Code first."
fi
info "  Found claude at: $CLAUDE_BIN"

# ─── Step 4: Detect ANTHROPIC_API_KEY ────────────────────────────────────────
info "Step 4: Checking ANTHROPIC_API_KEY..."
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  warn "ANTHROPIC_API_KEY not set. Launchd jobs will fail."
  warn "Add to ~/.zprofile: export ANTHROPIC_API_KEY='your-key'"
  API_KEY_VALUE=""
else
  info "  ANTHROPIC_API_KEY is set."
  API_KEY_VALUE="$ANTHROPIC_API_KEY"
fi

# ─── Step 5: Detect HOME and directories ─────────────────────────────────────
PLIST_HOME="$HOME"
WORK_DIR="$HOME/telegram-digest-bot"
LOG_DIR="$WORK_DIR/buddy/logs"

# ─── Step 6: Generate morning launchd plist ───────────────────────────────────
info "Step 6: Writing morning launchd plist..."
MORNING_PLIST="$HOME/Library/LaunchAgents/com.telegram-buddy.morning.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$MORNING_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.telegram-buddy.morning</string>
    <key>ProgramArguments</key>
    <array>
        <string>${CLAUDE_BIN}</string>
        <string>-p</string>
        <string>telegram-buddy: morning-digest</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${PLIST_HOME}</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>ANTHROPIC_API_KEY</key>
        <string>${API_KEY_VALUE}</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>${WORK_DIR}</string>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/morning.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/morning-error.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
info "  Written: $MORNING_PLIST"

# ─── Step 7: Generate evening launchd plist ───────────────────────────────────
info "Step 7: Writing evening launchd plist..."
EVENING_PLIST="$HOME/Library/LaunchAgents/com.telegram-buddy.evening.plist"
cat > "$EVENING_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.telegram-buddy.evening</string>
    <key>ProgramArguments</key>
    <array>
        <string>${CLAUDE_BIN}</string>
        <string>-p</string>
        <string>telegram-buddy: evening-digest</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>21</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${PLIST_HOME}</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>ANTHROPIC_API_KEY</key>
        <string>${API_KEY_VALUE}</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>${WORK_DIR}</string>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/evening.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/evening-error.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
info "  Written: $EVENING_PLIST"

# ─── Step 8: Generate afternoon launchd plist ─────────────────────────────────
info "Step 8: Writing afternoon launchd plist..."
AFTERNOON_PLIST="$HOME/Library/LaunchAgents/com.telegram-buddy.afternoon.plist"
cat > "$AFTERNOON_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.telegram-buddy.afternoon</string>
    <key>ProgramArguments</key>
    <array>
        <string>${CLAUDE_BIN}</string>
        <string>-p</string>
        <string>telegram-buddy: afternoon-digest</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>15</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${PLIST_HOME}</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>ANTHROPIC_API_KEY</key>
        <string>${API_KEY_VALUE}</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>${WORK_DIR}</string>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/afternoon.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/afternoon-error.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF
info "  Written: $AFTERNOON_PLIST"

# ─── Step 9: Load launchd plists ──────────────────────────────────────────────
info "Step 9: Loading launchd jobs..."
launchctl unload "$MORNING_PLIST" 2>/dev/null || true
launchctl load "$MORNING_PLIST"
launchctl unload "$AFTERNOON_PLIST" 2>/dev/null || true
launchctl load "$AFTERNOON_PLIST"
launchctl unload "$EVENING_PLIST" 2>/dev/null || true
launchctl load "$EVENING_PLIST"
info "  Jobs loaded."

# ─── Step 10: Print success summary ───────────────────────────────────────────
echo ""
echo -e "${GREEN}✅ telegram-buddy setup complete!${RESET}"
echo ""
echo "Directories:"
echo "  ~/telegram-digest-bot/buddy/       (state files)"
echo "  ~/telegram-digest-bot/buddy/logs/  (log files)"
echo ""
echo "Scheduled jobs:"
echo -e "  \033[33m🌅 Morning digest:   07:00 daily — news, events, saved${RESET}"
echo -e "  \033[36m💼 Afternoon digest: 15:00 daily — jobs, hawala, opportunities${RESET}"
echo -e "  \033[34m🌙 Evening digest:   21:00 daily — updates, promises, missed calls${RESET}"
echo ""
echo -e "${YELLOW}⚠️  Note: Jobs run in system timezone. If your Mac is not set to Europe/London,${RESET}"
echo -e "${YELLOW}    adjust Hour values in ~/Library/LaunchAgents/com.telegram-buddy.*.plist${RESET}"
echo ""
echo "Test now:"
echo "  claude -p \"telegram-buddy: morning-digest\""
echo "  claude -p \"telegram-buddy: afternoon-digest\""
echo ""
echo "Logs:"
echo "  tail -f ~/telegram-digest-bot/buddy/logs/morning.log"
echo "  tail -f ~/telegram-digest-bot/buddy/logs/afternoon.log"
echo "  tail -f ~/telegram-digest-bot/buddy/logs/evening.log"
