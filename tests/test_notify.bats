#!/usr/bin/env bats
# ==============================================================================
# test_notify.bats – Unit tests for the notify.sh module
# ==============================================================================
#
# All tests use mock binaries (curl, notify-send, mail) placed first in $PATH
# so no real network traffic, desktop daemon, or MTA is required.
#
# Mock behaviour:
#   curl   – records the URL, method, and payload to files in $MOCK_CALLS_DIR;
#            exits 0 by default (override with MOCK_CURL_EXIT=1).
#   notify-send – records title/message/icon to $MOCK_CALLS_DIR; exits 0.
#   mail   – reads stdin for body; records subject, to, from; exits 0.
#
# Tool-absent tests override the _NOTIFY_HAS_* flags directly (same technique
# used in test_json.bats for _JSON_HAS_JQ / _JSON_HAS_YQ).
# ==============================================================================

setup() {
    export NO_COLOR=1
    export ORIG_PATH="$PATH"

    # Temporary directories
    export MOCK_BIN_DIR
    MOCK_BIN_DIR="$(mktemp -d)"
    export TOOLS_BIN_DIR
    TOOLS_BIN_DIR="$(mktemp -d)"
    export MOCK_CALLS_DIR
    MOCK_CALLS_DIR="$(mktemp -d)"

    # ------------------------------------------------------------------
    # Link essential utilities so the mocked PATH stays functional.
    # ------------------------------------------------------------------
    _link_tool() {
        local tool="$1"
        local p
        p="$(command -v "$tool" 2>/dev/null || true)"
        [[ -n "$p" ]] || return 0
        ln -sf "$p" "${TOOLS_BIN_DIR}/${tool}"
    }
    _link_tool bash
    _link_tool env
    _link_tool date
    _link_tool grep
    _link_tool sed
    _link_tool awk
    _link_tool cat
    _link_tool tr
    _link_tool head
    _link_tool tail
    _link_tool sort
    _link_tool mktemp
    _link_tool rm
    _link_tool chmod
    _link_tool ln
    _link_tool dirname
    _link_tool printf
    _link_tool uname
    _link_tool tput
    _link_tool stty
    _link_tool cut
    _link_tool sleep
    _link_tool touch
    _link_tool mkdir

    export PATH="${MOCK_BIN_DIR}:${TOOLS_BIN_DIR}"

    # ------------------------------------------------------------------
    # Mock curl
    #   Records URL, method, and -d payload to $MOCK_CALLS_DIR.
    #   Returns MOCK_CURL_EXIT (default 0).
    # ------------------------------------------------------------------
    cat > "${MOCK_BIN_DIR}/curl" << 'CURL_EOF'
#!/usr/bin/env bash
method="POST"
payload=""
url=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -X)          shift; method="$1" ;;
        -d)          shift; payload="$1" ;;
        http://*|https://*)  url="$1" ;;
        --max-time)  shift ;;   # consume value, ignore
    esac
    shift
done

if [[ -n "${MOCK_CALLS_DIR:-}" ]]; then
    printf '%s' "$url"     > "${MOCK_CALLS_DIR}/curl_url"
    printf '%s' "$method"  > "${MOCK_CALLS_DIR}/curl_method"
    printf '%s' "$payload" > "${MOCK_CALLS_DIR}/curl_payload"
fi

exit "${MOCK_CURL_EXIT:-0}"
CURL_EOF
    chmod +x "${MOCK_BIN_DIR}/curl"

    # ------------------------------------------------------------------
    # Mock notify-send
    #   Records icon, title, and message to $MOCK_CALLS_DIR.
    #   Returns MOCK_NS_EXIT (default 0).
    # ------------------------------------------------------------------
    cat > "${MOCK_BIN_DIR}/notify-send" << 'NS_EOF'
#!/usr/bin/env bash
icon=""
title=""
message=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) shift; icon="$1" ;;
        *)
            if [[ -z "$title" ]]; then
                title="$1"
            else
                message="$1"
            fi
            ;;
    esac
    shift
done

if [[ -n "${MOCK_CALLS_DIR:-}" ]]; then
    printf '%s' "$icon"    > "${MOCK_CALLS_DIR}/ns_icon"
    printf '%s' "$title"   > "${MOCK_CALLS_DIR}/ns_title"
    printf '%s' "$message" > "${MOCK_CALLS_DIR}/ns_message"
fi

exit "${MOCK_NS_EXIT:-0}"
NS_EOF
    chmod +x "${MOCK_BIN_DIR}/notify-send"

    # ------------------------------------------------------------------
    # Mock mail
    #   Reads stdin for the body; records subject, to, and from.
    #   Returns MOCK_MAIL_EXIT (default 0).
    # ------------------------------------------------------------------
    cat > "${MOCK_BIN_DIR}/mail" << 'MAIL_EOF'
#!/usr/bin/env bash
subject=""
from=""
to=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s) shift; subject="$1" ;;
        -r) shift; from="$1" ;;
        *)  to="$1" ;;
    esac
    shift
done

body="$(cat)"

if [[ -n "${MOCK_CALLS_DIR:-}" ]]; then
    printf '%s' "$subject" > "${MOCK_CALLS_DIR}/mail_subject"
    printf '%s' "$to"      > "${MOCK_CALLS_DIR}/mail_to"
    printf '%s' "$from"    > "${MOCK_CALLS_DIR}/mail_from"
    printf '%s' "$body"    > "${MOCK_CALLS_DIR}/mail_body"
fi

exit "${MOCK_MAIL_EXIT:-0}"
MAIL_EOF
    chmod +x "${MOCK_BIN_DIR}/mail"

    # Reset notification config to known defaults for each test
    export BASH_UTILS_NOTIFY_SLACK_WEBHOOK=""
    export BASH_UTILS_NOTIFY_TEAMS_WEBHOOK=""
    export BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN=""
    export BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID=""
    export BASH_UTILS_NOTIFY_EMAIL_TO=""
    export BASH_UTILS_NOTIFY_EMAIL_FROM=""
    export BASH_UTILS_NOTIFY_FALLBACK_LOG="true"
    export BASH_UTILS_NOTIFY_TIMEOUT="5"

    # Load modules under test
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/notify.sh"
}

teardown() {
    export PATH="$ORIG_PATH"
    rm -rf "${MOCK_BIN_DIR:-}" "${TOOLS_BIN_DIR:-}" "${MOCK_CALLS_DIR:-}"
}

# ==============================================================================
# Module loading
# ==============================================================================

@test "notify module loads without errors" {
    run bash -c "
        export NO_COLOR=1
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
    "
    [[ "$status" -eq 0 ]]
}

@test "notify module sets BASH_UTILS_NOTIFY_LOADED" {
    [[ "${BASH_UTILS_NOTIFY_LOADED}" == "true" ]]
}

@test "notify module prevents multiple sourcing" {
    # Sourcing again should be a no-op and return 0
    run source "${BATS_TEST_DIRNAME}/../modules/notify.sh"
    [[ "$status" -eq 0 ]]
}

@test "all public notify_ functions are defined" {
    declare -f notify_desktop  > /dev/null
    declare -f notify_slack    > /dev/null
    declare -f notify_teams    > /dev/null
    declare -f notify_telegram > /dev/null
    declare -f notify_email    > /dev/null
    declare -f notify_webhook  > /dev/null
    declare -f notify_log      > /dev/null
}

# ==============================================================================
# _notify_escape_json
# ==============================================================================

@test "_notify_escape_json escapes double quotes" {
    result="$(_notify_escape_json 'say "hello"')"
    [[ "$result" == 'say \"hello\"' ]]
}

@test "_notify_escape_json escapes backslashes" {
    result="$(_notify_escape_json 'path\to\file')"
    [[ "$result" == 'path\\to\\file' ]]
}

@test "_notify_escape_json escapes newlines" {
    result="$(_notify_escape_json $'line1\nline2')"
    [[ "$result" == 'line1\nline2' ]]
}

@test "_notify_escape_json passes through plain strings unchanged" {
    result="$(_notify_escape_json "deploy finished on prod-01")"
    [[ "$result" == "deploy finished on prod-01" ]]
}

# ==============================================================================
# notify_desktop
# ==============================================================================

@test "notify_desktop calls notify-send when available" {
    _NOTIFY_HAS_NOTIFY_SEND="true"
    _NOTIFY_HAS_OSASCRIPT="false"
    run notify_desktop "Build done" "All tests passed"
    [[ "$status" -eq 0 ]]
}

@test "notify_desktop passes title and message to notify-send" {
    _NOTIFY_HAS_NOTIFY_SEND="true"
    _NOTIFY_HAS_OSASCRIPT="false"
    notify_desktop "MyTitle" "MyMessage"
    [[ "$(cat "${MOCK_CALLS_DIR}/ns_title")"   == "MyTitle"   ]]
    [[ "$(cat "${MOCK_CALLS_DIR}/ns_message")" == "MyMessage" ]]
}

@test "notify_desktop passes custom icon to notify-send" {
    _NOTIFY_HAS_NOTIFY_SEND="true"
    _NOTIFY_HAS_OSASCRIPT="false"
    notify_desktop "Title" "Msg" "dialog-warning"
    [[ "$(cat "${MOCK_CALLS_DIR}/ns_icon")" == "dialog-warning" ]]
}

@test "notify_desktop uses osascript when notify-send is absent" {
    # Create a minimal osascript mock
    cat > "${MOCK_BIN_DIR}/osascript" << 'OSA_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${MOCK_CALLS_DIR}/osascript_args"
exit 0
OSA_EOF
    chmod +x "${MOCK_BIN_DIR}/osascript"
    _NOTIFY_HAS_NOTIFY_SEND="false"
    _NOTIFY_HAS_OSASCRIPT="true"
    run notify_desktop "MacTitle" "MacMessage"
    [[ "$status" -eq 0 ]]
}

@test "notify_desktop fails gracefully when no tool is available" {
    _NOTIFY_HAS_NOTIFY_SEND="false"
    _NOTIFY_HAS_OSASCRIPT="false"
    run notify_desktop "Title" "Message"
    [[ "$status" -ne 0 ]]
}

@test "notify_desktop logs fallback when no tool and fallback is enabled" {
    _NOTIFY_HAS_NOTIFY_SEND="false"
    _NOTIFY_HAS_OSASCRIPT="false"
    BASH_UTILS_NOTIFY_FALLBACK_LOG="true"
    run notify_desktop "Title" "Message"
    [[ "$output" == *"desktop"* ]]
}

@test "notify_desktop requires TITLE argument" {
    run notify_desktop
    [[ "$status" -ne 0 ]]
}

@test "notify_desktop requires MESSAGE argument" {
    run notify_desktop "Title"
    [[ "$status" -ne 0 ]]
}

# ==============================================================================
# notify_slack
# ==============================================================================

@test "notify_slack fails when no webhook URL is set" {
    BASH_UTILS_NOTIFY_SLACK_WEBHOOK=""
    run notify_slack "Hello Slack"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"webhook"* ]]
}

@test "notify_slack accepts webhook URL as second argument" {
    run notify_slack "Hello Slack" "http://hooks.example.com/slack"
    [[ "$status" -eq 0 ]]
}

@test "notify_slack uses BASH_UTILS_NOTIFY_SLACK_WEBHOOK env var" {
    BASH_UTILS_NOTIFY_SLACK_WEBHOOK="http://hooks.example.com/slack-env"
    run notify_slack "Hello from env"
    [[ "$status" -eq 0 ]]
}

@test "notify_slack posts to the supplied webhook URL" {
    notify_slack "test message" "http://hooks.example.com/verify"
    [[ "$(cat "${MOCK_CALLS_DIR}/curl_url")" == "http://hooks.example.com/verify" ]]
}

@test "notify_slack payload contains the message text" {
    notify_slack "deployment ok" "http://hooks.example.com/slack"
    payload="$(cat "${MOCK_CALLS_DIR}/curl_payload")"
    [[ "$payload" == *"deployment ok"* ]]
}

@test "notify_slack fails when curl is unavailable" {
    run bash -c "
        export NO_COLOR=1
        export PATH='${TOOLS_BIN_DIR}'
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
        _NOTIFY_HAS_CURL='false'
        notify_slack 'msg' 'http://hooks.example.com/x'
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"curl"* ]]
}

@test "notify_slack requires MESSAGE argument" {
    run notify_slack
    [[ "$status" -ne 0 ]]
}

# ==============================================================================
# notify_teams
# ==============================================================================

@test "notify_teams fails when no webhook URL is set" {
    BASH_UTILS_NOTIFY_TEAMS_WEBHOOK=""
    run notify_teams "Hello Teams"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"webhook"* ]]
}

@test "notify_teams accepts webhook URL as second argument" {
    run notify_teams "Hello Teams" "http://outlook.office.com/webhook/test"
    [[ "$status" -eq 0 ]]
}

@test "notify_teams uses BASH_UTILS_NOTIFY_TEAMS_WEBHOOK env var" {
    BASH_UTILS_NOTIFY_TEAMS_WEBHOOK="http://outlook.office.com/webhook/env"
    run notify_teams "Hello from env"
    [[ "$status" -eq 0 ]]
}

@test "notify_teams payload is a MessageCard" {
    notify_teams "pipeline failed" "http://outlook.office.com/webhook/test"
    payload="$(cat "${MOCK_CALLS_DIR}/curl_payload")"
    [[ "$payload" == *"MessageCard"* ]]
    [[ "$payload" == *"pipeline failed"* ]]
}

@test "notify_teams fails when curl is unavailable" {
    run bash -c "
        export NO_COLOR=1
        export PATH='${TOOLS_BIN_DIR}'
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
        _NOTIFY_HAS_CURL='false'
        notify_teams 'msg' 'http://outlook.office.com/webhook/x'
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"curl"* ]]
}

@test "notify_teams requires MESSAGE argument" {
    run notify_teams
    [[ "$status" -ne 0 ]]
}

# ==============================================================================
# notify_telegram
# ==============================================================================

@test "notify_telegram fails when no bot token is set" {
    BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN=""
    run notify_telegram "Hello Telegram" "" "12345"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"token"* ]]
}

@test "notify_telegram fails when no chat ID is set" {
    BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN="bot123"
    BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID=""
    run notify_telegram "Hello Telegram" "bot123" ""
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"chat"* ]]
}

@test "notify_telegram succeeds with token and chat ID as arguments" {
    run notify_telegram "Hello Telegram" "mytoken" "99999"
    [[ "$status" -eq 0 ]]
}

@test "notify_telegram uses env vars for token and chat ID" {
    BASH_UTILS_NOTIFY_TELEGRAM_BOT_TOKEN="envtoken"
    BASH_UTILS_NOTIFY_TELEGRAM_CHAT_ID="envchat"
    run notify_telegram "Hello from env"
    [[ "$status" -eq 0 ]]
}

@test "notify_telegram posts to the correct Telegram API URL" {
    notify_telegram "msg" "mytoken" "99999"
    url="$(cat "${MOCK_CALLS_DIR}/curl_url")"
    [[ "$url" == *"api.telegram.org"* ]]
    [[ "$url" == *"mytoken"* ]]
    [[ "$url" == *"sendMessage"* ]]
}

@test "notify_telegram payload contains chat_id and message" {
    notify_telegram "bot alert" "mytoken" "88888"
    payload="$(cat "${MOCK_CALLS_DIR}/curl_payload")"
    [[ "$payload" == *"88888"* ]]
    [[ "$payload" == *"bot alert"* ]]
}

@test "notify_telegram fails when curl is unavailable" {
    run bash -c "
        export NO_COLOR=1
        export PATH='${TOOLS_BIN_DIR}'
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
        _NOTIFY_HAS_CURL='false'
        notify_telegram 'msg' 'tok' '999'
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"curl"* ]]
}

@test "notify_telegram requires MESSAGE argument" {
    run notify_telegram
    [[ "$status" -ne 0 ]]
}

# ==============================================================================
# notify_email
# ==============================================================================

@test "notify_email fails when no recipient is set" {
    BASH_UTILS_NOTIFY_EMAIL_TO=""
    run notify_email "Subject" "Body"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"recipient"* ]]
}

@test "notify_email accepts recipient as third argument" {
    run notify_email "Subject" "Body" "user@example.com"
    [[ "$status" -eq 0 ]]
}

@test "notify_email uses BASH_UTILS_NOTIFY_EMAIL_TO env var" {
    BASH_UTILS_NOTIFY_EMAIL_TO="admin@example.com"
    run notify_email "Subject" "Body"
    [[ "$status" -eq 0 ]]
}

@test "notify_email sends correct subject and recipient" {
    notify_email "Nightly Report" "All good" "ops@example.com"
    [[ "$(cat "${MOCK_CALLS_DIR}/mail_subject")" == "Nightly Report" ]]
    [[ "$(cat "${MOCK_CALLS_DIR}/mail_to")"      == "ops@example.com" ]]
}

@test "notify_email sends body via stdin" {
    notify_email "Test Subject" "Hello body text" "user@example.com"
    [[ "$(cat "${MOCK_CALLS_DIR}/mail_body")" == "Hello body text" ]]
}

@test "notify_email includes From header when BASH_UTILS_NOTIFY_EMAIL_FROM is set" {
    BASH_UTILS_NOTIFY_EMAIL_FROM="noreply@example.com"
    notify_email "Subject" "Body" "user@example.com"
    [[ "$(cat "${MOCK_CALLS_DIR}/mail_from")" == "noreply@example.com" ]]
}

@test "notify_email fails when mail is unavailable" {
    run bash -c "
        export NO_COLOR=1
        export PATH='${TOOLS_BIN_DIR}'
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
        _NOTIFY_HAS_MAIL='false'
        notify_email 'Subj' 'Body' 'user@example.com'
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"mail"* ]]
}

@test "notify_email requires SUBJECT argument" {
    run notify_email
    [[ "$status" -ne 0 ]]
}

@test "notify_email requires BODY argument" {
    run notify_email "Subject only"
    [[ "$status" -ne 0 ]]
}

# ==============================================================================
# notify_webhook
# ==============================================================================

@test "notify_webhook posts to the given URL" {
    run notify_webhook "http://hooks.example.com/generic" '{"event":"deploy"}'
    [[ "$status" -eq 0 ]]
}

@test "notify_webhook records correct URL" {
    notify_webhook "http://hooks.example.com/check" '{"k":"v"}'
    [[ "$(cat "${MOCK_CALLS_DIR}/curl_url")" == "http://hooks.example.com/check" ]]
}

@test "notify_webhook defaults to POST method" {
    notify_webhook "http://hooks.example.com/x" '{"k":"v"}'
    [[ "$(cat "${MOCK_CALLS_DIR}/curl_method")" == "POST" ]]
}

@test "notify_webhook accepts custom HTTP method" {
    notify_webhook "http://hooks.example.com/x" '{"k":"v"}' "PUT"
    [[ "$(cat "${MOCK_CALLS_DIR}/curl_method")" == "PUT" ]]
}

@test "notify_webhook fails when curl is unavailable" {
    run bash -c "
        export NO_COLOR=1
        export PATH='${TOOLS_BIN_DIR}'
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
        _NOTIFY_HAS_CURL='false'
        notify_webhook 'http://hooks.example.com/x' '{}'
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"curl"* ]]
}

@test "notify_webhook requires URL argument" {
    run notify_webhook
    [[ "$status" -ne 0 ]]
}

@test "notify_webhook requires PAYLOAD argument" {
    run notify_webhook "http://hooks.example.com/x"
    [[ "$status" -ne 0 ]]
}

# ==============================================================================
# notify_log
# ==============================================================================

@test "notify_log emits info message" {
    run notify_log info "info notification"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"info notification"* ]]
}

@test "notify_log emits success message" {
    run notify_log success "deploy succeeded"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"deploy succeeded"* ]]
}

@test "notify_log emits warning message" {
    run notify_log warning "disk space low"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"disk space low"* ]]
}

@test "notify_log emits warning with 'warn' alias" {
    run notify_log warn "using warn alias"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"using warn alias"* ]]
}

@test "notify_log emits error message" {
    run notify_log error "build failed"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"build failed"* ]]
}

@test "notify_log emits debug message when BASH_UTILS_VERBOSE is true" {
    export BASH_UTILS_VERBOSE=true
    export BASH_UTILS_LOG_LEVEL=DEBUG
    run notify_log debug "verbose debug message"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"verbose debug message"* ]]
}

@test "notify_log fails for an unknown level" {
    run notify_log critical "something"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"unknown level"* ]]
}

@test "notify_log requires MESSAGE argument" {
    run notify_log info
    [[ "$status" -ne 0 ]]
}

@test "notify_log defaults to info level when no level given" {
    run notify_log "" "default level message"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"default level message"* ]]
}

# ==============================================================================
# Fallback behaviour
# ==============================================================================

@test "fallback log message contains channel name when notify_slack curl is absent" {
    run bash -c "
        export NO_COLOR=1
        export BASH_UTILS_NOTIFY_FALLBACK_LOG=true
        export PATH='${TOOLS_BIN_DIR}'
        source '${BATS_TEST_DIRNAME}/../modules/config.sh'
        source '${BATS_TEST_DIRNAME}/../modules/logging.sh'
        source '${BATS_TEST_DIRNAME}/../modules/notify.sh'
        _NOTIFY_HAS_CURL='false'
        notify_slack 'fallback test' 'http://hooks.example.com/x'
    "
    [[ "$output" == *"slack"* ]]
}

@test "no fallback log when BASH_UTILS_NOTIFY_FALLBACK_LOG is false" {
    _NOTIFY_HAS_NOTIFY_SEND="false"
    _NOTIFY_HAS_OSASCRIPT="false"
    BASH_UTILS_NOTIFY_FALLBACK_LOG="false"
    run notify_desktop "Title" "Message"
    # status non-zero but output should NOT contain the notify channel tag
    [[ "$output" != *"[notify:desktop]"* ]]
}

@test "special characters in message are JSON-escaped for slack" {
    notify_slack 'say "hello" & goodbye' "http://hooks.example.com/slack"
    payload="$(cat "${MOCK_CALLS_DIR}/curl_payload")"
    # double-quote should be escaped in the JSON payload
    [[ "$payload" == *'\"hello\"'* ]]
}
