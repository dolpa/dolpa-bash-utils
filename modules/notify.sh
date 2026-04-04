#!/usr/bin/env bash
# ==============================================================================
# notify.sh – Notification Utilities
# ==============================================================================
#
# Provides helpers for sending notifications through multiple channels:
#   • Desktop   – native OS desktop pop-ups (notify-send / osascript)
#   • Slack     – Incoming Webhook  (https://api.slack.com/messaging/webhooks)
#   • Teams     – Office 365 Connector webhook
#   • Telegram  – Bot API  (https://core.telegram.org/bots/api)
#   • Email     – system mail command
#   • Webhook   – any HTTP endpoint accepting a JSON body
#   • Log       – always-available fallback; emit a structured log entry
#
# Tool requirements
# -----------------
#   curl         – required for Slack, Teams, Telegram, and generic webhook
#   notify-send  – required for desktop notifications on Linux
#   osascript    – required for desktop notifications on macOS
#   mail         – required for email notifications
#
# Quick examples
# --------------
#   notify_desktop  "Build done"  "All tests passed"
#   notify_slack    "Deploy finished on $HOST"
#   notify_teams    "Pipeline failed on $BRANCH"
#   notify_telegram "Backup completed"
#   notify_email    "Nightly report" "$(cat report.txt)"
#   notify_webhook  "https://hook.example.com/event" '{"event":"deploy"}'
#   notify_log      info "Deployment complete"
#
# Environment variables
# ---------------------
#   BASH_UTILS_NOTIFY_SLACK_WEBHOOK        Default Slack incoming webhook URL
#   BASH_UTILS_NOTIFY_TEAMS_WEBHOOK        Default MS Teams connector URL
#   BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN   Telegram bot token
#   BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID     Telegram target chat / channel ID
#   BASH_UTILS_NOTIFY_EMAIL_TO             Default email recipient address
#   BASH_UTILS_NOTIFY_EMAIL_FROM           Sender address (optional)
#   BASH_UTILS_NOTIFY_TIMEOUT              curl timeout in seconds (default: 10)
#   BASH_UTILS_NOTIFY_FALLBACK_LOG         'true' to log when primary tool absent (default: true)
# ==============================================================================

# ------------------------------------------------------------------------------
# Guard – idempotent sourcing
# ------------------------------------------------------------------------------
if [[ "${BASH_UTILS_NOTIFY_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_NOTIFY_LOADED="true"

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./config.sh
source "${_BASH_UTILS_MODULE_DIR}/config.sh"
# shellcheck source=./logging.sh
source "${_BASH_UTILS_MODULE_DIR}/logging.sh"

# ------------------------------------------------------------------------------
# Configuration defaults (caller may override before sourcing or at runtime)
# ------------------------------------------------------------------------------
: "${BASH_UTILS_NOTIFY_TIMEOUT:=10}"
: "${BASH_UTILS_NOTIFY_FALLBACK_LOG:=true}"
: "${BASH_UTILS_NOTIFY_SLACK_WEBHOOK:=}"
: "${BASH_UTILS_NOTIFY_TEAMS_WEBHOOK:=}"
: "${BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN:=}"
: "${BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID:=}"
: "${BASH_UTILS_NOTIFY_EMAIL_TO:=}"
: "${BASH_UTILS_NOTIFY_EMAIL_FROM:=}"

# ------------------------------------------------------------------------------
# Tool detection – evaluated once at load time; stored as plain variables so
# tests can override them without subshell gymnastics.
# ------------------------------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
    _NOTIFY_HAS_CURL="true"
else
    _NOTIFY_HAS_CURL="false"
fi

if command -v notify-send >/dev/null 2>&1; then
    _NOTIFY_HAS_NOTIFY_SEND="true"
else
    _NOTIFY_HAS_NOTIFY_SEND="false"
fi

if command -v osascript >/dev/null 2>&1; then
    _NOTIFY_HAS_OSASCRIPT="true"
else
    _NOTIFY_HAS_OSASCRIPT="false"
fi

if command -v mail >/dev/null 2>&1; then
    _NOTIFY_HAS_MAIL="true"
else
    _NOTIFY_HAS_MAIL="false"
fi

# ==============================================================================
# Private helpers
# ==============================================================================

# _notify_escape_json STRING
#   Escape a plain string so it is safe to embed inside a JSON string value.
_notify_escape_json() {
    local s="$1"
    s="${s//\\/\\\\}"       # backslash must come first
    s="${s//\"/\\\"}"       # double-quote
    s="${s//$'\n'/\\n}"     # newline
    s="${s//$'\r'/\\r}"     # carriage return
    s="${s//$'\t'/\\t}"     # tab
    printf '%s' "$s"
}

# _notify_curl_post URL JSON_PAYLOAD
#   POST a JSON payload to URL; discards the response body.
_notify_curl_post() {
    local url="$1"
    local payload="$2"
    curl -fsSL \
         --max-time "${BASH_UTILS_NOTIFY_TIMEOUT}" \
         -X POST \
         -H "Content-Type: application/json" \
         -d "$payload" \
         "$url" \
         >/dev/null 2>&1
}

# _notify_fallback CHANNEL MESSAGE
#   When BASH_UTILS_NOTIFY_FALLBACK_LOG is 'true', emit a log_info entry so the
#   notification is never silently dropped.
_notify_fallback() {
    local channel="$1"
    local message="$2"
    if [[ "${BASH_UTILS_NOTIFY_FALLBACK_LOG}" == "true" ]]; then
        log_info "[notify:${channel}] ${message}"
    fi
}

# ==============================================================================
# Public API
# ==============================================================================

# ------------------------------------------------------------------------------
# notify_desktop TITLE MESSAGE [ICON]
#   Send a native desktop pop-up notification.
#
#   Linux : uses notify-send (libnotify).
#   macOS : uses osascript.
#   Falls back to logging when neither tool is present.
#
#   ICON (optional, Linux only) – symbolic icon name, e.g. 'dialog-information'
# ------------------------------------------------------------------------------
notify_desktop() {
    local title="${1:?notify_desktop: missing TITLE argument}"
    local message="${2:?notify_desktop: missing MESSAGE argument}"
    local icon="${3:-dialog-information}"

    if [[ "${_NOTIFY_HAS_NOTIFY_SEND}" == "true" ]]; then
        notify-send -i "$icon" "$title" "$message"
    elif [[ "${_NOTIFY_HAS_OSASCRIPT}" == "true" ]]; then
        osascript -e "display notification \"${message}\" with title \"${title}\""
    else
        log_warn "notify_desktop: no desktop notification tool available (notify-send / osascript)"
        _notify_fallback "desktop" "${title}: ${message}"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# notify_slack MESSAGE [WEBHOOK_URL]
#   Send a plain-text message to a Slack channel via an Incoming Webhook.
#
#   WEBHOOK_URL defaults to $BASH_UTILS_NOTIFY_SLACK_WEBHOOK.
# ------------------------------------------------------------------------------
notify_slack() {
    local message="${1:?notify_slack: missing MESSAGE argument}"
    local webhook="${2:-${BASH_UTILS_NOTIFY_SLACK_WEBHOOK}}"

    if [[ -z "$webhook" ]]; then
        log_error "notify_slack: no webhook URL provided; set BASH_UTILS_NOTIFY_SLACK_WEBHOOK or pass as 2nd argument"
        return 1
    fi

    if [[ "${_NOTIFY_HAS_CURL}" != "true" ]]; then
        log_error "notify_slack: 'curl' is required but not found on PATH"
        _notify_fallback "slack" "$message"
        return 1
    fi

    local escaped
    escaped="$(_notify_escape_json "$message")"
    _notify_curl_post "$webhook" "{\"text\":\"${escaped}\"}"
}

# ------------------------------------------------------------------------------
# notify_teams MESSAGE [WEBHOOK_URL]
#   Send a plain-text message to a Microsoft Teams channel via an Office 365
#   Incoming Connector webhook (MessageCard format).
#
#   WEBHOOK_URL defaults to $BASH_UTILS_NOTIFY_TEAMS_WEBHOOK.
# ------------------------------------------------------------------------------
notify_teams() {
    local message="${1:?notify_teams: missing MESSAGE argument}"
    local webhook="${2:-${BASH_UTILS_NOTIFY_TEAMS_WEBHOOK}}"

    if [[ -z "$webhook" ]]; then
        log_error "notify_teams: no webhook URL provided; set BASH_UTILS_NOTIFY_TEAMS_WEBHOOK or pass as 2nd argument"
        return 1
    fi

    if [[ "${_NOTIFY_HAS_CURL}" != "true" ]]; then
        log_error "notify_teams: 'curl' is required but not found on PATH"
        _notify_fallback "teams" "$message"
        return 1
    fi

    local escaped
    escaped="$(_notify_escape_json "$message")"
    local payload
    payload="{\"@type\":\"MessageCard\",\"@context\":\"https://schema.org/extensions\",\"text\":\"${escaped}\"}"
    _notify_curl_post "$webhook" "$payload"
}

# ------------------------------------------------------------------------------
# notify_telegram MESSAGE [BOT_TOKEN] [CHAT_ID]
#   Send a message via the Telegram Bot API.
#
#   BOT_TOKEN defaults to $BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN.
#   CHAT_ID   defaults to $BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID.
# ------------------------------------------------------------------------------
notify_telegram() {
    local message="${1:?notify_telegram: missing MESSAGE argument}"
    local token="${2:-${BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN}}"
    local chat_id="${3:-${BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID}}"

    if [[ -z "$token" ]]; then
        log_error "notify_telegram: no bot token; set BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN or pass as 2nd argument"
        return 1
    fi

    if [[ -z "$chat_id" ]]; then
        log_error "notify_telegram: no chat ID; set BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID or pass as 3rd argument"
        return 1
    fi

    if [[ "${_NOTIFY_HAS_CURL}" != "true" ]]; then
        log_error "notify_telegram: 'curl' is required but not found on PATH"
        _notify_fallback "telegram" "$message"
        return 1
    fi

    local escaped
    escaped="$(_notify_escape_json "$message")"
    local url="https://api.telegram.org/bot${token}/sendMessage"
    local payload
    payload="{\"chat_id\":\"${chat_id}\",\"text\":\"${escaped}\"}"
    _notify_curl_post "$url" "$payload"
}

# ------------------------------------------------------------------------------
# notify_email SUBJECT BODY [TO]
#   Send a plain-text email using the system 'mail' command.
#
#   TO defaults to $BASH_UTILS_NOTIFY_EMAIL_TO.
# ------------------------------------------------------------------------------
notify_email() {
    local subject="${1:?notify_email: missing SUBJECT argument}"
    local body="${2:?notify_email: missing BODY argument}"
    local to="${3:-${BASH_UTILS_NOTIFY_EMAIL_TO}}"

    if [[ -z "$to" ]]; then
        log_error "notify_email: no recipient; set BASH_UTILS_NOTIFY_EMAIL_TO or pass as 3rd argument"
        return 1
    fi

    if [[ "${_NOTIFY_HAS_MAIL}" != "true" ]]; then
        log_error "notify_email: 'mail' command not found on PATH"
        _notify_fallback "email" "${subject}: ${body}"
        return 1
    fi

    if [[ -n "${BASH_UTILS_NOTIFY_EMAIL_FROM}" ]]; then
        printf '%s' "$body" | mail -s "$subject" -r "${BASH_UTILS_NOTIFY_EMAIL_FROM}" "$to"
    else
        printf '%s' "$body" | mail -s "$subject" "$to"
    fi
}

# ------------------------------------------------------------------------------
# notify_webhook URL PAYLOAD [METHOD]
#   POST (or METHOD) an arbitrary JSON payload to any HTTP endpoint.
#
#   METHOD defaults to POST.
# ------------------------------------------------------------------------------
notify_webhook() {
    local url="${1:?notify_webhook: missing URL argument}"
    local payload="${2:?notify_webhook: missing PAYLOAD argument}"
    local method="${3:-POST}"

    if [[ "${_NOTIFY_HAS_CURL}" != "true" ]]; then
        log_error "notify_webhook: 'curl' is required but not found on PATH"
        return 1
    fi

    curl -fsSL \
         --max-time "${BASH_UTILS_NOTIFY_TIMEOUT}" \
         -X "$method" \
         -H "Content-Type: application/json" \
         -d "$payload" \
         "$url" \
         >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# notify_log LEVEL MESSAGE
#   Emit a notification as a structured log entry.  Always available regardless
#   of installed tools – acts as the guaranteed delivery channel.
#
#   LEVEL – info | success | warning | error | debug   (default: info)
# ------------------------------------------------------------------------------
notify_log() {
    local level="${1:-info}"
    local message="${2:?notify_log: missing MESSAGE argument}"

    case "${level,,}" in
        info)         log_info    "$message" ;;
        success)      log_success "$message" ;;
        warning|warn) log_warning "$message" ;;
        error)        log_error   "$message" ;;
        debug)        log_debug   "$message" ;;
        *)
            log_error "notify_log: unknown level '${level}'; expected: info|success|warning|error|debug"
            return 1
            ;;
    esac
}

export -f notify_desktop notify_slack notify_teams notify_telegram \
          notify_email notify_webhook notify_log
