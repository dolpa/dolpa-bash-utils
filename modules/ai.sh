#!/usr/bin/env bash
# ==============================================================================
# ai.sh – AI / Local‑LLM Helper Functions
# ==============================================================================
#
# Provides convenience wrappers for:
#   • Ollama  – local model management (list, pull, update, delete, prompt, chat)
#   • OpenAI  – Chat Completions API   (requires OPENAI_API_KEY)
#   • Anthropic – Messages API         (requires ANTHROPIC_API_KEY)
#
# Quick examples
# --------------
#   ollama_is_running                      # returns 0/1
#   ollama_list_models                     # print installed model names
#   ollama_pull_if_missing llama3          # idempotent pull
#   ollama_update_all                      # re-pull every installed model
#   ollama_prompt llama3 "What is cgroups?"
#   ollama_chat   llama3 "Explain namespaces briefly"
#   ai_openai_chat    "Summarise the BSD licence"
#   ai_anthropic_chat "Explain TCP/IP in 2 sentences"
#   ai_detect_backend                      # ollama | openai | anthropic | none
#   ai_summarize_file /var/log/syslog
#
# Environment variables
# ---------------------
#   BASH_UTILS_AI_OLLAMA_HOST             Ollama base URL   (default: http://localhost:11434)
#   BASH_UTILS_AI_TIMEOUT                 curl timeout (s)  (default: 60)
#   BASH_UTILS_AI_OLLAMA_DEFAULT_MODEL    default model     (default: llama3)
#   BASH_UTILS_AI_OPENAI_DEFAULT_MODEL    default model     (default: gpt-4o-mini)
#   BASH_UTILS_AI_ANTHROPIC_DEFAULT_MODEL default model     (default: claude-3-haiku-20240307)
#   OPENAI_API_KEY                        OpenAI secret key
#   ANTHROPIC_API_KEY                     Anthropic secret key
# ==============================================================================

# ------------------------------------------------------------------------------
# Guard – prevent the file from being sourced more than once.
# ------------------------------------------------------------------------------
if [[ "${BASH_UTILS_AI_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_AI_LOADED="true"

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./config.sh
source "${_BASH_UTILS_MODULE_DIR}/config.sh"
# shellcheck source=./logging.sh
source "${_BASH_UTILS_MODULE_DIR}/logging.sh"
# shellcheck source=./retry.sh
source "${_BASH_UTILS_MODULE_DIR}/retry.sh"

# ------------------------------------------------------------------------------
# curl is required for all REST calls – fail early with a clear message.
# ------------------------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
    log_error "ai.sh – 'curl' is required but was not found on PATH"
    return 1
fi

# ------------------------------------------------------------------------------
# User-overridable configuration
# ------------------------------------------------------------------------------
: "${BASH_UTILS_AI_OLLAMA_HOST:=http://localhost:11434}"
: "${BASH_UTILS_AI_TIMEOUT:=60}"
: "${BASH_UTILS_AI_OLLAMA_DEFAULT_MODEL:=llama3}"
: "${BASH_UTILS_AI_OPENAI_DEFAULT_MODEL:=gpt-4o-mini}"
: "${BASH_UTILS_AI_ANTHROPIC_DEFAULT_MODEL:=claude-3-haiku-20240307}"

# ==============================================================================
# Internal helpers
# ==============================================================================

# ------------------------------------------------------------------------------
# _ai_escape_json STRING
#   Escape a string for safe embedding inside a JSON double-quoted value.
#   Handles: backslashes, double-quotes, literal newlines, and tab characters.
# ------------------------------------------------------------------------------
_ai_escape_json() {
    printf '%s' "$1" \
        | sed 's/\\/\\\\/g; s/"/\\"/g' \
        | sed -e ':a' -e 'N' -e '$!ba' \
              -e 's/\n/\\n/g; s/\t/\\t/g'
}

# ------------------------------------------------------------------------------
# _ai_post URL JSON_BODY [EXTRA_CURL_ARGS …]
#   POST JSON_BODY to URL and print the response body to stdout.
#   Additional curl flags (e.g. -H "Authorization: Bearer …") can be appended.
# ------------------------------------------------------------------------------
_ai_post() {
    local url="${1:?_ai_post: missing URL}"
    local json="${2:?_ai_post: missing JSON body}"
    shift 2
    curl -fsSL \
        --max-time "${BASH_UTILS_AI_TIMEOUT}" \
        -X POST \
        -H "Content-Type: application/json" \
        "$@" \
        -d "$json" \
        "$url"
}

# ------------------------------------------------------------------------------
# _ai_json_get JSON JQ_PATH
#   Extract a single scalar value from a JSON string.
#   Uses jq when available; falls back to a grep/sed heuristic for simple
#   top-level string fields.
# ------------------------------------------------------------------------------
_ai_json_get() {
    local json="${1:-}"
    local path="${2:?_ai_json_get: missing jq path}"

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$json" | jq -r "$path" 2>/dev/null
    else
        # Minimal fallback: extracts the first matching "key":"value" pair.
        local key="${path#.}"
        printf '%s' "$json" \
            | grep -o "\"${key}\":[[:space:]]*\"[^\"]*\"" \
            | head -1 \
            | sed 's/.*":[[:space:]]*"//; s/"$//'
    fi
}

# ==============================================================================
# OLLAMA
# ==============================================================================

# ------------------------------------------------------------------------------
# ollama_is_running
#   Returns 0 when the Ollama daemon is reachable at BASH_UTILS_AI_OLLAMA_HOST,
#   1 otherwise.
# ------------------------------------------------------------------------------
ollama_is_running() {
    curl -fsS \
        --max-time "${BASH_UTILS_AI_TIMEOUT}" \
        "${BASH_UTILS_AI_OLLAMA_HOST}/" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# ollama_list_models
#   Print the name of every locally installed model, one per line.
#   Uses the 'ollama' CLI when present; falls back to the REST API otherwise.
# ------------------------------------------------------------------------------
ollama_list_models() {
    if command -v ollama >/dev/null 2>&1; then
        # `ollama list` prints a header then one "NAME  ID  SIZE  MODIFIED" per line.
        ollama list 2>/dev/null | awk 'NR>1 && NF>0 { print $1 }'
    else
        # REST API fallback: GET /api/tags → {"models":[{"name":"llama3:latest"},…]}
        local response
        response="$(curl -fsSL \
            --max-time "${BASH_UTILS_AI_TIMEOUT}" \
            "${BASH_UTILS_AI_OLLAMA_HOST}/api/tags" 2>/dev/null)" || {
            log_error "ollama_list_models: cannot reach Ollama at ${BASH_UTILS_AI_OLLAMA_HOST}"
            return 1
        }
        if command -v jq >/dev/null 2>&1; then
            printf '%s' "$response" | jq -r '.models[].name' 2>/dev/null
        else
            printf '%s' "$response" \
                | grep -o '"name":"[^"]*"' \
                | sed 's/"name":"//; s/"$//'
        fi
    fi
}

# ------------------------------------------------------------------------------
# ollama_pull_if_missing MODEL[:TAG]
#   Download the model only when it is not already installed locally.
#   Returns 0 when the model is available (pre-existing or just pulled).
# ------------------------------------------------------------------------------
ollama_pull_if_missing() {
    local model="${1:?ollama_pull_if_missing: missing model name}"
    local model_base="${model%%:*}"   # strip :tag for the existence check

    local installed
    installed="$(ollama_list_models 2>/dev/null)"

    if printf '%s\n' "$installed" | grep -q "^${model_base}"; then
        log_debug "ollama_pull_if_missing: '${model}' is already installed"
        return 0
    fi

    log_info "ollama_pull_if_missing: pulling '${model}'"
    ollama pull "$model"
}

# ------------------------------------------------------------------------------
# ollama_update_all
#   Re-pull every currently installed model to get the latest version.
#   Uses retry_cmd (3 attempts) to tolerate transient network errors.
#   Returns 0 when all updates succeed, 1 if any model failed.
# ------------------------------------------------------------------------------
ollama_update_all() {
    local models
    models="$(ollama_list_models)" || {
        log_error "ollama_update_all: failed to list installed models"
        return 1
    }

    if [[ -z "$models" ]]; then
        log_info "ollama_update_all: no models installed, nothing to update"
        return 0
    fi

    local failures=0
    while IFS= read -r model; do
        [[ -z "$model" ]] && continue
        log_info "ollama_update_all: updating '${model}'"
        if retry_cmd 3 ollama pull "$model"; then
            log_success "ollama_update_all: '${model}' updated successfully"
        else
            log_error "ollama_update_all: failed to update '${model}' after 3 attempts"
            (( failures++ )) || true
        fi
    done <<< "$models"

    (( failures == 0 ))
}

# ------------------------------------------------------------------------------
# ollama_delete MODEL[:TAG]
#   Remove a locally installed Ollama model.
# ------------------------------------------------------------------------------
ollama_delete() {
    local model="${1:?ollama_delete: missing model name}"

    if ! command -v ollama >/dev/null 2>&1; then
        log_error "ollama_delete: 'ollama' CLI not found"
        return 1
    fi

    log_info "ollama_delete: removing '${model}'"
    ollama rm "$model"
}

# ------------------------------------------------------------------------------
# ollama_prompt MODEL PROMPT
#   Send a single generation request to Ollama and print the response text.
#   Uses the non-streaming /api/generate endpoint.
# ------------------------------------------------------------------------------
ollama_prompt() {
    local model="${1:?ollama_prompt: missing model name}"
    local prompt="${2:?ollama_prompt: missing prompt text}"

    local escaped
    escaped="$(_ai_escape_json "$prompt")"

    local response
    response="$(_ai_post \
        "${BASH_UTILS_AI_OLLAMA_HOST}/api/generate" \
        "{\"model\":\"${model}\",\"prompt\":\"${escaped}\",\"stream\":false}")" || {
        log_error "ollama_prompt: request to Ollama failed (model='${model}')"
        return 1
    }

    _ai_json_get "$response" '.response'
}

# ------------------------------------------------------------------------------
# ollama_chat MODEL MESSAGE
#   Send a single user message to Ollama's chat endpoint and print the reply.
#   Uses the non-streaming /api/chat endpoint.
# ------------------------------------------------------------------------------
ollama_chat() {
    local model="${1:?ollama_chat: missing model name}"
    local message="${2:?ollama_chat: missing message text}"

    local escaped
    escaped="$(_ai_escape_json "$message")"

    local response
    response="$(_ai_post \
        "${BASH_UTILS_AI_OLLAMA_HOST}/api/chat" \
        "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"${escaped}\"}],\"stream\":false}")" || {
        log_error "ollama_chat: request to Ollama failed (model='${model}')"
        return 1
    }

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$response" | jq -r '.message.content' 2>/dev/null
    else
        printf '%s' "$response" \
            | grep -o '"content":"[^"]*"' \
            | head -1 \
            | sed 's/"content":"//; s/"$//'
    fi
}

# ==============================================================================
# OPENAI
# ==============================================================================

# ------------------------------------------------------------------------------
# ai_openai_chat PROMPT [MODEL]
#   Send a chat message to the OpenAI Chat Completions API and print the reply.
#   Reads the API key from the OPENAI_API_KEY environment variable.
# ------------------------------------------------------------------------------
ai_openai_chat() {
    local prompt="${1:?ai_openai_chat: missing prompt}"
    local model="${2:-${BASH_UTILS_AI_OPENAI_DEFAULT_MODEL}}"

    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
        log_error "ai_openai_chat: OPENAI_API_KEY is not set"
        return 1
    fi

    local escaped
    escaped="$(_ai_escape_json "$prompt")"

    local response
    response="$(_ai_post \
        "https://api.openai.com/v1/chat/completions" \
        "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"${escaped}\"}]}" \
        -H "Authorization: Bearer ${OPENAI_API_KEY}")" || {
        log_error "ai_openai_chat: OpenAI API request failed"
        return 1
    }

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$response" | jq -r '.choices[0].message.content' 2>/dev/null
    else
        printf '%s' "$response" \
            | grep -o '"content":"[^"]*"' \
            | head -1 \
            | sed 's/"content":"//; s/"$//'
    fi
}

# ==============================================================================
# ANTHROPIC
# ==============================================================================

# ------------------------------------------------------------------------------
# ai_anthropic_chat PROMPT [MODEL]
#   Send a message to the Anthropic Messages API and print the reply.
#   Reads the API key from the ANTHROPIC_API_KEY environment variable.
# ------------------------------------------------------------------------------
ai_anthropic_chat() {
    local prompt="${1:?ai_anthropic_chat: missing prompt}"
    local model="${2:-${BASH_UTILS_AI_ANTHROPIC_DEFAULT_MODEL}}"

    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        log_error "ai_anthropic_chat: ANTHROPIC_API_KEY is not set"
        return 1
    fi

    local escaped
    escaped="$(_ai_escape_json "$prompt")"

    local response
    response="$(_ai_post \
        "https://api.anthropic.com/v1/messages" \
        "{\"model\":\"${model}\",\"max_tokens\":1024,\"messages\":[{\"role\":\"user\",\"content\":\"${escaped}\"}]}" \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01")" || {
        log_error "ai_anthropic_chat: Anthropic API request failed"
        return 1
    }

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$response" | jq -r '.content[0].text' 2>/dev/null
    else
        printf '%s' "$response" \
            | grep -o '"text":"[^"]*"' \
            | head -1 \
            | sed 's/"text":"//; s/"$//'
    fi
}

# ==============================================================================
# UTILITIES
# ==============================================================================

# ------------------------------------------------------------------------------
# ai_detect_backend
#   Probe which AI backend is available and print its name to stdout.
#   Priority order: ollama → openai → anthropic
#   Output: 'ollama' | 'openai' | 'anthropic' | 'none'
#   Returns 0 when a backend is found, 1 when nothing is available.
# ------------------------------------------------------------------------------
ai_detect_backend() {
    if ollama_is_running 2>/dev/null; then
        printf 'ollama'
        return 0
    fi

    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        printf 'openai'
        return 0
    fi

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        printf 'anthropic'
        return 0
    fi

    printf 'none'
    return 1
}

# ------------------------------------------------------------------------------
# ai_summarize_file FILE [BACKEND]
#   Read FILE and send its contents to an AI backend requesting a concise
#   summary.  BACKEND is one of 'ollama', 'openai', or 'anthropic'; omit it
#   for automatic detection via ai_detect_backend.
# ------------------------------------------------------------------------------
ai_summarize_file() {
    local file="${1:?ai_summarize_file: missing file path}"
    local backend="${2:-}"

    if [[ ! -f "$file" ]]; then
        log_error "ai_summarize_file: file not found: ${file}"
        return 1
    fi

    if [[ -z "$backend" ]]; then
        backend="$(ai_detect_backend)" || {
            log_error "ai_summarize_file: no AI backend is available"
            return 1
        }
    fi

    local content
    content="$(cat "$file")"
    local escaped_content
    escaped_content="$(_ai_escape_json "$content")"
    local prompt="Summarise the following content concisely in 3-5 sentences:\n\n${escaped_content}"

    case "$backend" in
        ollama)    ollama_prompt "${BASH_UTILS_AI_OLLAMA_DEFAULT_MODEL}" "$prompt" ;;
        openai)    ai_openai_chat "$prompt" ;;
        anthropic) ai_anthropic_chat "$prompt" ;;
        *)
            log_error "ai_summarize_file: unknown backend '${backend}' (valid: ollama|openai|anthropic)"
            return 1
            ;;
    esac
}

export -f ollama_is_running ollama_list_models ollama_pull_if_missing \
          ollama_update_all ollama_delete ollama_prompt ollama_chat \
          ai_openai_chat ai_anthropic_chat ai_detect_backend ai_summarize_file
