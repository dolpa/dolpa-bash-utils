#!/usr/bin/env bats
# ==============================================================================
# test_ai.bats – Unit tests for the ai.sh module
# ==============================================================================
#
# All tests use mock `curl` and `ollama` binaries placed first in $PATH so that
# no real network traffic or AI backends are required.
#
# Mock behaviour:
#   curl http://localhost:11434/           → exit 0  (daemon reachable)
#   curl http://localhost:11434/api/tags   → {"models":[{"name":"llama3:latest"},…]}
#   curl http://localhost:11434/api/generate → {"response":"mocked ollama answer",…}
#   curl http://localhost:11434/api/chat   → {"message":{"content":"mocked chat reply"},…}
#   curl https://api.openai.com/…          → {"choices":[{"message":{"content":"openai reply"}}]}
#   curl https://api.anthropic.com/…       → {"content":[{"text":"anthropic reply"}]}
#   curl <anything else>                   → exit 7
#   ollama list                            → two rows: llama3:latest, mistral:latest
#   ollama pull <model>                    → exit 0
#   ollama rm   <model>                    → exit 0
# ==============================================================================

setup() {
    export NO_COLOR=1
    export ORIG_PATH="$PATH"

    # Directories for mock binaries and safe toolchain links.
    export MOCK_BIN_DIR
    MOCK_BIN_DIR="$(mktemp -d)"
    export TOOLS_BIN_DIR
    TOOLS_BIN_DIR="$(mktemp -d)"

    # ------------------------------------------------------------------
    # Link essential utilities so mocked PATH remains functional.
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
    # Link jq when available so both code paths are exercised if present.
    _link_tool jq

    export PATH="${MOCK_BIN_DIR}:${TOOLS_BIN_DIR}"

    # ------------------------------------------------------------------
    # Mock curl – interprets the final positional URL argument.
    # ------------------------------------------------------------------
    cat > "${MOCK_BIN_DIR}/curl" <<'CURL_EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do
    case "$arg" in
        http://*|https://*) url="$arg" ;;
    esac
done

case "$url" in
    "http://localhost:11434/")
        exit 0
        ;;
    "http://localhost:11434/api/tags")
        printf '{"models":[{"name":"llama3:latest"},{"name":"mistral:latest"}]}'
        exit 0
        ;;
    "http://localhost:11434/api/generate")
        printf '{"model":"llama3","response":"mocked ollama answer","done":true}'
        exit 0
        ;;
    "http://localhost:11434/api/chat")
        printf '{"model":"llama3","message":{"role":"assistant","content":"mocked chat reply"},"done":true}'
        exit 0
        ;;
    "https://api.openai.com/v1/chat/completions")
        printf '{"id":"chatcmpl-test","choices":[{"message":{"role":"assistant","content":"openai mocked reply"}}]}'
        exit 0
        ;;
    "https://api.anthropic.com/v1/messages")
        printf '{"id":"msg_test","content":[{"type":"text","text":"anthropic mocked reply"}]}'
        exit 0
        ;;
    *)
        exit 7
        ;;
esac
CURL_EOF
    chmod +x "${MOCK_BIN_DIR}/curl"

    # ------------------------------------------------------------------
    # Mock ollama CLI.
    # ------------------------------------------------------------------
    cat > "${MOCK_BIN_DIR}/ollama" <<'OLLAMA_EOF'
#!/usr/bin/env bash
cmd="${1:-}"
shift || true

case "$cmd" in
    list)
        printf 'NAME                    ID              SIZE    MODIFIED\n'
        printf 'llama3:latest           abc123def456    4.7 GB  2 weeks ago\n'
        printf 'mistral:latest          def456abc123    4.1 GB  1 month ago\n'
        exit 0
        ;;
    pull)
        printf 'pulling manifest\npulling layers\nsuccess\n'
        exit "${MOCK_OLLAMA_PULL_EXIT:-0}"
        ;;
    rm)
        printf 'deleted '"'"'%s'"'"'\n' "${1:-model}"
        exit 0
        ;;
    *)
        printf 'Usage: ollama [command]\n' >&2
        exit 1
        ;;
esac
OLLAMA_EOF
    chmod +x "${MOCK_BIN_DIR}/ollama"

    # ------------------------------------------------------------------
    # Load modules under test.
    # ------------------------------------------------------------------
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/ai.sh"

    # Reset Ollama host to the default the mock curl handles.
    export BASH_UTILS_AI_OLLAMA_HOST="http://localhost:11434"

    # Ensure API key env vars are unset between tests.
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
}

teardown() {
    export PATH="$ORIG_PATH"
    rm -rf "${MOCK_BIN_DIR}" "${TOOLS_BIN_DIR}"
    unset MOCK_BIN_DIR TOOLS_BIN_DIR ORIG_PATH
    unset BASH_UTILS_AI_OLLAMA_HOST OPENAI_API_KEY ANTHROPIC_API_KEY
    unset MOCK_OLLAMA_PULL_EXIT
}

# ==============================================================================
# Module loading
# ==============================================================================

@test "ai module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/ai.sh"
    [ "$status" -eq 0 ]
}

@test "ai module sets BASH_UTILS_AI_LOADED" {
    [ "${BASH_UTILS_AI_LOADED}" = "true" ]
}

@test "ai module prevents multiple sourcing" {
    # Sourcing again must be a no-op (guard fires).
    run source "${BATS_TEST_DIRNAME}/../modules/ai.sh"
    [ "$status" -eq 0 ]
}

@test "all public ollama functions are defined" {
    declare -f ollama_is_running    >/dev/null
    declare -f ollama_list_models   >/dev/null
    declare -f ollama_pull_if_missing >/dev/null
    declare -f ollama_update_all    >/dev/null
    declare -f ollama_delete        >/dev/null
    declare -f ollama_prompt        >/dev/null
    declare -f ollama_chat          >/dev/null
}

@test "all public ai_ utility functions are defined" {
    declare -f ai_openai_chat       >/dev/null
    declare -f ai_anthropic_chat    >/dev/null
    declare -f ai_detect_backend    >/dev/null
    declare -f ai_summarize_file    >/dev/null
}

# ==============================================================================
# ollama_is_running
# ==============================================================================

@test "ollama_is_running returns 0 when Ollama daemon is reachable" {
    run ollama_is_running
    [ "$status" -eq 0 ]
}

@test "ollama_is_running returns 1 when Ollama is unreachable" {
    # Point at a host the mock curl does not recognise (falls through to exit 7).
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    run ollama_is_running
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ollama_list_models
# ==============================================================================

@test "ollama_list_models returns model names via CLI" {
    run ollama_list_models
    [ "$status" -eq 0 ]
    [[ "$output" == *"llama3:latest"* ]]
    [[ "$output" == *"mistral:latest"* ]]
}

@test "ollama_list_models returns one model per line" {
    run ollama_list_models
    [ "$status" -eq 0 ]
    # There should be exactly two lines of output.
    local line_count
    line_count="$(printf '%s\n' "$output" | grep -c '.')"
    [ "$line_count" -eq 2 ]
}

@test "ollama_list_models falls back to REST API when CLI is absent" {
    rm -f "${MOCK_BIN_DIR}/ollama"
    run ollama_list_models
    [ "$status" -eq 0 ]
    [[ "$output" == *"llama3:latest"* ]]
}

@test "ollama_list_models fails when CLI absent and daemon unreachable" {
    rm -f "${MOCK_BIN_DIR}/ollama"
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    run ollama_list_models
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ollama_pull_if_missing
# ==============================================================================

@test "ollama_pull_if_missing skips pull when model is already installed" {
    # llama3 is in the mock ollama list output.
    run ollama_pull_if_missing "llama3"
    [ "$status" -eq 0 ]
    # The pull command must NOT have been invoked (output contains no "pulling").
    [[ "$output" != *"pulling"* ]]
}

@test "ollama_pull_if_missing pulls when model is not installed" {
    # nonexistent-model is not in the mock list.
    run ollama_pull_if_missing "nonexistent-model"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pulling"* ]]
}

@test "ollama_pull_if_missing requires a model argument" {
    run ollama_pull_if_missing
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ollama_update_all
# ==============================================================================

@test "ollama_update_all pulls every installed model" {
    run ollama_update_all
    [ "$status" -eq 0 ]
}

@test "ollama_update_all returns 0 when no models are installed" {
    # Replace ollama mock with one that returns an empty list.
    cat > "${MOCK_BIN_DIR}/ollama" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    list) printf 'NAME    ID    SIZE    MODIFIED\n' ; exit 0 ;;
    *)    exit 0 ;;
esac
EOF
    chmod +x "${MOCK_BIN_DIR}/ollama"

    run ollama_update_all
    [ "$status" -eq 0 ]
    [[ "$output" == *"no models"* ]]
}

# ==============================================================================
# ollama_delete
# ==============================================================================

@test "ollama_delete calls ollama rm with the given model" {
    run ollama_delete "llama3:latest"
    [ "$status" -eq 0 ]
    [[ "$output" == *"deleted"* ]] || [[ "$output" == *"llama3"* ]]
}

@test "ollama_delete fails when ollama CLI is not present" {
    rm -f "${MOCK_BIN_DIR}/ollama"
    run ollama_delete "llama3:latest"
    [ "$status" -ne 0 ]
}

@test "ollama_delete requires a model argument" {
    run ollama_delete
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ollama_prompt
# ==============================================================================

@test "ollama_prompt returns the response text" {
    run ollama_prompt "llama3" "What is bash?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mocked ollama answer"* ]]
}

@test "ollama_prompt requires a model argument" {
    run ollama_prompt
    [ "$status" -ne 0 ]
}

@test "ollama_prompt requires a prompt argument" {
    run ollama_prompt "llama3"
    [ "$status" -ne 0 ]
}

@test "ollama_prompt fails when Ollama is unreachable" {
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    run ollama_prompt "llama3" "hello"
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ollama_chat
# ==============================================================================

@test "ollama_chat returns the message content" {
    run ollama_chat "llama3" "Hello!"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mocked chat reply"* ]]
}

@test "ollama_chat requires model and message arguments" {
    run ollama_chat
    [ "$status" -ne 0 ]
}

@test "ollama_chat fails when Ollama is unreachable" {
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    run ollama_chat "llama3" "hello"
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ai_openai_chat
# ==============================================================================

@test "ai_openai_chat fails when OPENAI_API_KEY is not set" {
    unset OPENAI_API_KEY
    run ai_openai_chat "Hello"
    [ "$status" -ne 0 ]
    [[ "$output" == *"OPENAI_API_KEY"* ]]
}

@test "ai_openai_chat returns content when API key is set" {
    export OPENAI_API_KEY="sk-test-key"
    run ai_openai_chat "Hello"
    [ "$status" -eq 0 ]
    [[ "$output" == *"openai mocked reply"* ]]
}

@test "ai_openai_chat accepts a custom model as second argument" {
    export OPENAI_API_KEY="sk-test-key"
    run ai_openai_chat "Hello" "gpt-4o"
    [ "$status" -eq 0 ]
}

@test "ai_openai_chat requires a prompt argument" {
    export OPENAI_API_KEY="sk-test-key"
    run ai_openai_chat
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ai_anthropic_chat
# ==============================================================================

@test "ai_anthropic_chat fails when ANTHROPIC_API_KEY is not set" {
    unset ANTHROPIC_API_KEY
    run ai_anthropic_chat "Hello"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ANTHROPIC_API_KEY"* ]]
}

@test "ai_anthropic_chat returns content when API key is set" {
    export ANTHROPIC_API_KEY="sk-ant-test-key"
    run ai_anthropic_chat "Hello"
    [ "$status" -eq 0 ]
    [[ "$output" == *"anthropic mocked reply"* ]]
}

@test "ai_anthropic_chat accepts a custom model as second argument" {
    export ANTHROPIC_API_KEY="sk-ant-test-key"
    run ai_anthropic_chat "Hello" "claude-3-opus-20240229"
    [ "$status" -eq 0 ]
}

@test "ai_anthropic_chat requires a prompt argument" {
    export ANTHROPIC_API_KEY="sk-ant-test-key"
    run ai_anthropic_chat
    [ "$status" -ne 0 ]
}

# ==============================================================================
# ai_detect_backend
# ==============================================================================

@test "ai_detect_backend returns ollama when daemon is running" {
    run ai_detect_backend
    [ "$status" -eq 0 ]
    [ "$output" = "ollama" ]
}

@test "ai_detect_backend returns openai when OPENAI_API_KEY set and ollama down" {
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    export OPENAI_API_KEY="sk-test"
    run ai_detect_backend
    [ "$status" -eq 0 ]
    [ "$output" = "openai" ]
}

@test "ai_detect_backend returns anthropic when only anthropic key is available" {
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    unset OPENAI_API_KEY
    export ANTHROPIC_API_KEY="sk-ant-test"
    run ai_detect_backend
    [ "$status" -eq 0 ]
    [ "$output" = "anthropic" ]
}

@test "ai_detect_backend returns none when no backend is available" {
    export BASH_UTILS_AI_OLLAMA_HOST="http://127.0.0.1:9999"
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
    run ai_detect_backend
    [ "$status" -ne 0 ]
    [ "$output" = "none" ]
}

# ==============================================================================
# ai_summarize_file
# ==============================================================================

@test "ai_summarize_file fails when file does not exist" {
    run ai_summarize_file "/tmp/does_not_exist_$$"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "ai_summarize_file requires a file argument" {
    run ai_summarize_file
    [ "$status" -ne 0 ]
}

@test "ai_summarize_file uses ollama when backend is ollama" {
    local tmp_file
    tmp_file="$(mktemp)"
    printf 'This is a test file with some content.\n' > "$tmp_file"

    run ai_summarize_file "$tmp_file" "ollama"
    rm -f "$tmp_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mocked ollama answer"* ]]
}

@test "ai_summarize_file uses openai when backend is openai" {
    export OPENAI_API_KEY="sk-test"
    local tmp_file
    tmp_file="$(mktemp)"
    printf 'This is a test file.\n' > "$tmp_file"

    run ai_summarize_file "$tmp_file" "openai"
    rm -f "$tmp_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"openai mocked reply"* ]]
}

@test "ai_summarize_file uses anthropic when backend is anthropic" {
    export ANTHROPIC_API_KEY="sk-ant-test"
    local tmp_file
    tmp_file="$(mktemp)"
    printf 'This is a test file.\n' > "$tmp_file"

    run ai_summarize_file "$tmp_file" "anthropic"
    rm -f "$tmp_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"anthropic mocked reply"* ]]
}

@test "ai_summarize_file fails with an unknown backend name" {
    local tmp_file
    tmp_file="$(mktemp)"
    printf 'content\n' > "$tmp_file"

    run ai_summarize_file "$tmp_file" "grok"
    rm -f "$tmp_file"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown backend"* ]]
}

@test "ai_summarize_file auto-detects ollama as backend" {
    local tmp_file
    tmp_file="$(mktemp)"
    printf 'Auto-detect test content.\n' > "$tmp_file"

    # No backend specified; ollama_is_running succeeds with the mock.
    run ai_summarize_file "$tmp_file"
    rm -f "$tmp_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mocked ollama answer"* ]]
}
