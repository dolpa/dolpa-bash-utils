#!/usr/bin/env bash
# ==============================================================================
# json.sh – JSON and YAML Utilities
# ==============================================================================
#
# Provides helpers for reading, writing, and transforming JSON (and, optionally,
# YAML) data inside Bash scripts.
#
# Primary tool: jq  (required for most json_* functions)
#   • If jq is absent the module still loads and emits a warning; only
#     json_pretty, json_compact, and json_validate fall back to python3.
#
# Optional tool: yq  (required for yaml_* functions)
#   • If yq is absent all yaml_* functions return an error at call time.
#
# Quick examples
# --------------
#   json_validate  '{"a":1}'                   # returns 0
#   json_get       '{"name":"Alice"}' '.name'  # prints: Alice
#   json_set       data.json '.version' '2.0'
#   json_delete    data.json '.deprecated'
#   json_merge     base.json overlay.json       # merged JSON to stdout
#   json_keys      '{"a":1,"b":2}'             # prints: a\nb
#   json_length    '[1,2,3]'                   # prints: 3
#   json_has       '{"x":null}' '.x'           # returns 1 (null ≅ absent)
#   json_pretty    '{"a":1}'                   # pretty-prints
#   json_compact   '{"a": 1}'                  # minifies
#   json_query     data.json '.items[].name'
#   json_from_args name=Alice age=30 active=true   # {"name":"Alice","age":30,"active":true}
#   yaml_to_json   config.yaml
#   json_to_yaml   data.json
#   yaml_validate  config.yaml
#   yaml_get       config.yaml '.database.host'
#   yaml_set       config.yaml '.database.port' '5432'
#
# Environment variables
# ---------------------
#   BASH_UTILS_JSON_INDENT   Pretty-print indent (spaces). Default: 2
# ==============================================================================

# ------------------------------------------------------------------------------
# Guard – idempotent sourcing
# ------------------------------------------------------------------------------
if [[ "${BASH_UTILS_JSON_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_JSON_LOADED="true"

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./config.sh
source "${_BASH_UTILS_MODULE_DIR}/config.sh"
# shellcheck source=./logging.sh
source "${_BASH_UTILS_MODULE_DIR}/logging.sh"

# ------------------------------------------------------------------------------
# User-overridable configuration
# ------------------------------------------------------------------------------
: "${BASH_UTILS_JSON_INDENT:=2}"

# ------------------------------------------------------------------------------
# Tool detection – run once at load time and stored in read-only flags.
# ------------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    _JSON_HAS_JQ="true"
else
    _JSON_HAS_JQ="false"
    log_warn "json.sh – 'jq' not found; most json_* functions will be unavailable"
fi

if command -v yq >/dev/null 2>&1; then
    _JSON_HAS_YQ="true"
else
    _JSON_HAS_YQ="false"
fi

if command -v python3 >/dev/null 2>&1; then
    _JSON_HAS_PYTHON3="true"
else
    _JSON_HAS_PYTHON3="false"
fi

# ==============================================================================
# Internal helpers
# ==============================================================================

# ------------------------------------------------------------------------------
# _json_input INPUT
#   If INPUT is a readable file, print its contents; otherwise print INPUT as-is.
# ------------------------------------------------------------------------------
_json_input() {
    local input="${1:?_json_input: missing argument}"
    if [[ -f "$input" ]]; then
        cat "$input"
    else
        printf '%s' "$input"
    fi
}

# ------------------------------------------------------------------------------
# _json_require_jq [FUNCTION_NAME]
#   Return 1 with a clear log message when jq is not available.
# ------------------------------------------------------------------------------
_json_require_jq() {
    if [[ "${_JSON_HAS_JQ}" != "true" ]]; then
        log_error "${1:-This function} requires jq, which was not found on PATH"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# _json_require_yq [FUNCTION_NAME]
#   Return 1 with a clear log message when yq is not available.
# ------------------------------------------------------------------------------
_json_require_yq() {
    if [[ "${_JSON_HAS_YQ}" != "true" ]]; then
        log_error "${1:-This function} requires yq, which was not found on PATH"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# _json_atomic_write FILE CONTENT
#   Write CONTENT to FILE atomically via a temporary file + rename so that a
#   failed mid-write does not corrupt the original.
# ------------------------------------------------------------------------------
_json_atomic_write() {
    local file="${1:?_json_atomic_write: missing file}"
    local content="${2:?_json_atomic_write: missing content}"
    local tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    printf '%s\n' "$content" > "$tmp" && mv "$tmp" "$file"
}

# ------------------------------------------------------------------------------
# _json_type_value VALUE
#   Emit VALUE as the most appropriate JSON type:
#     integer / float  → bare number   (e.g. 42, 3.14)
#     true / false     → JSON boolean
#     null             → JSON null
#     anything else    → double-quoted, backslash/quote-escaped string
# ------------------------------------------------------------------------------
_json_type_value() {
    local val="$1"
    if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        printf '%s' "$val"
    elif [[ "$val" == "true" || "$val" == "false" || "$val" == "null" ]]; then
        printf '%s' "$val"
    else
        val="${val//\\/\\\\}"
        val="${val//\"/\\\"}"
        printf '"%s"' "$val"
    fi
}

# ==============================================================================
# PUBLIC API – JSON
# ==============================================================================

# ------------------------------------------------------------------------------
# json_validate INPUT
#   Return 0 when INPUT is valid JSON, non-zero otherwise.
#   INPUT may be a file path or a raw JSON string.
#   Uses jq when available; falls back to python3.
# ------------------------------------------------------------------------------
json_validate() {
    local input="${1:?json_validate: missing input (file or JSON string)}"
    local json
    json="$(_json_input "$input")"

    if [[ "${_JSON_HAS_JQ}" == "true" ]]; then
        printf '%s' "$json" | jq -e . >/dev/null 2>&1
    elif [[ "${_JSON_HAS_PYTHON3}" == "true" ]]; then
        printf '%s' "$json" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
    else
        log_error "json_validate: neither jq nor python3 is available"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# json_get INPUT PATH
#   Extract and print the value at the jq PATH from INPUT.
#   Raw string output is used (numbers and strings print without JSON quoting).
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_get() {
    local input="${1:?json_get: missing input (file or JSON string)}"
    local path="${2:?json_get: missing jq path (e.g. .key or .a.b)}"
    _json_require_jq "json_get" || return 1

    _json_input "$input" | jq -r "$path"
}

# ------------------------------------------------------------------------------
# json_set FILE PATH VALUE [--raw]
#   Update FILE in-place, setting the node at PATH to VALUE.
#   By default VALUE is treated as a plain string.
#   Pass --raw as the fourth argument to insert VALUE as a typed JSON literal
#   (number, boolean, null, object, or array).
# ------------------------------------------------------------------------------
json_set() {
    local file="${1:?json_set: missing file path}"
    local path="${2:?json_set: missing jq path}"
    local value="${3:?json_set: missing value}"
    local raw="${4:-}"
    _json_require_jq "json_set" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "json_set: file not found: ${file}"
        return 1
    fi

    local updated
    if [[ "$raw" == "--raw" ]]; then
        updated="$(jq --argjson _v "$value" "${path} = \$_v" "$file")" || return 1
    else
        updated="$(jq --arg _v "$value" "${path} = \$_v" "$file")" || return 1
    fi

    _json_atomic_write "$file" "$updated"
}

# ------------------------------------------------------------------------------
# json_delete FILE PATH
#   Remove the key / element at PATH from FILE in-place.
# ------------------------------------------------------------------------------
json_delete() {
    local file="${1:?json_delete: missing file path}"
    local path="${2:?json_delete: missing jq path}"
    _json_require_jq "json_delete" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "json_delete: file not found: ${file}"
        return 1
    fi

    local updated
    updated="$(jq "del(${path})" "$file")" || return 1
    _json_atomic_write "$file" "$updated"
}

# ------------------------------------------------------------------------------
# json_merge FILE1 FILE2
#   Print the result of a deep-merge of FILE2 into FILE1 to stdout.
#   FILE2 fields overwrite (or add to) matching FILE1 fields at every level.
#   Both arguments must be file paths containing valid JSON objects.
# ------------------------------------------------------------------------------
json_merge() {
    local file1="${1:?json_merge: missing first file}"
    local file2="${2:?json_merge: missing second file}"
    _json_require_jq "json_merge" || return 1

    for f in "$file1" "$file2"; do
        if [[ ! -f "$f" ]]; then
            log_error "json_merge: file not found: ${f}"
            return 1
        fi
    done

    jq -s '.[0] * .[1]' "$file1" "$file2"
}

# ------------------------------------------------------------------------------
# json_keys INPUT [PATH]
#   Print the keys of the JSON object at PATH (default: root) one per line.
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_keys() {
    local input="${1:?json_keys: missing input (file or JSON string)}"
    local path="${2:-.}"
    _json_require_jq "json_keys" || return 1

    _json_input "$input" | jq -r "${path} | keys[]"
}

# ------------------------------------------------------------------------------
# json_length INPUT [PATH]
#   Print the number of elements in the array or object at PATH (default: root).
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_length() {
    local input="${1:?json_length: missing input (file or JSON string)}"
    local path="${2:-.}"
    _json_require_jq "json_length" || return 1

    _json_input "$input" | jq -r "${path} | length"
}

# ------------------------------------------------------------------------------
# json_has INPUT PATH
#   Return 0 when PATH exists in INPUT and its value is not null; 1 otherwise.
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_has() {
    local input="${1:?json_has: missing input (file or JSON string)}"
    local path="${2:?json_has: missing jq path}"
    _json_require_jq "json_has" || return 1

    # jq -e exits non-zero when the result is false or null.
    _json_input "$input" | jq -e "${path} != null" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# json_pretty INPUT
#   Pretty-print INPUT with BASH_UTILS_JSON_INDENT spaces of indentation.
#   Falls back to python3 when jq is not available.
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_pretty() {
    local input="${1:?json_pretty: missing input (file or JSON string)}"
    local json
    json="$(_json_input "$input")"

    if [[ "${_JSON_HAS_JQ}" == "true" ]]; then
        printf '%s' "$json" | jq --indent "${BASH_UTILS_JSON_INDENT}" '.'
    elif [[ "${_JSON_HAS_PYTHON3}" == "true" ]]; then
        printf '%s' "$json" \
            | python3 -c \
                "import json,sys; print(json.dumps(json.load(sys.stdin), indent=${BASH_UTILS_JSON_INDENT}))"
    else
        log_error "json_pretty: neither jq nor python3 is available"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# json_compact INPUT
#   Emit INPUT as a single-line minified JSON string.
#   Falls back to python3 when jq is not available.
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_compact() {
    local input="${1:?json_compact: missing input (file or JSON string)}"
    local json
    json="$(_json_input "$input")"

    if [[ "${_JSON_HAS_JQ}" == "true" ]]; then
        printf '%s' "$json" | jq -c '.'
    elif [[ "${_JSON_HAS_PYTHON3}" == "true" ]]; then
        printf '%s' "$json" \
            | python3 -c \
                "import json,sys; print(json.dumps(json.load(sys.stdin), separators=(',',':')))"
    else
        log_error "json_compact: neither jq nor python3 is available"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# json_query INPUT FILTER
#   Run an arbitrary jq FILTER against INPUT and print the raw output.
#   INPUT may be a file path or a raw JSON string.
# ------------------------------------------------------------------------------
json_query() {
    local input="${1:?json_query: missing input (file or JSON string)}"
    local filter="${2:?json_query: missing jq filter}"
    _json_require_jq "json_query" || return 1

    _json_input "$input" | jq -r "$filter"
}

# ------------------------------------------------------------------------------
# json_from_args KEY=VALUE [KEY=VALUE …]
#   Build a flat JSON object from KEY=VALUE pairs.
#   Values are auto-typed:
#     integers / floats      → JSON number
#     true | false           → JSON boolean
#     null                   → JSON null
#     everything else        → JSON string (backslash + quote escaped)
#   Example:
#     json_from_args name=Alice age=30 active=true
#     → {"name":"Alice","age":30,"active":true}
# ------------------------------------------------------------------------------
json_from_args() {
    if [[ $# -eq 0 ]]; then
        log_error "json_from_args: at least one KEY=VALUE argument is required"
        return 1
    fi

    local result='{'
    local first=1
    local kv key value

    for kv in "$@"; do
        if [[ "$kv" != *=* ]]; then
            log_error "json_from_args: argument is not a KEY=VALUE pair: '${kv}'"
            return 1
        fi
        key="${kv%%=*}"
        value="${kv#*=}"

        if [[ -z "$key" ]]; then
            log_error "json_from_args: empty key in argument: '${kv}'"
            return 1
        fi

        if (( first == 0 )); then
            result+=','
        fi
        result+="\"${key}\":$(_json_type_value "$value")"
        first=0
    done

    result+='}'
    printf '%s\n' "$result"
}

# ==============================================================================
# PUBLIC API – YAML
# ==============================================================================

# ------------------------------------------------------------------------------
# yaml_to_json FILE
#   Convert a YAML file to JSON and print to stdout.
#   Requires yq (https://github.com/mikefarah/yq) v4+.
# ------------------------------------------------------------------------------
yaml_to_json() {
    local file="${1:?yaml_to_json: missing file path}"
    _json_require_yq "yaml_to_json" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "yaml_to_json: file not found: ${file}"
        return 1
    fi

    yq -o=json '.' "$file"
}

# ------------------------------------------------------------------------------
# json_to_yaml FILE
#   Convert a JSON file to YAML and print to stdout.
#   Requires yq v4+.
# ------------------------------------------------------------------------------
json_to_yaml() {
    local file="${1:?json_to_yaml: missing file path}"
    _json_require_yq "json_to_yaml" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "json_to_yaml: file not found: ${file}"
        return 1
    fi

    yq -P '.' "$file"
}

# ------------------------------------------------------------------------------
# yaml_validate FILE
#   Return 0 when FILE contains valid YAML, non-zero otherwise.
#   Requires yq v4+.
# ------------------------------------------------------------------------------
yaml_validate() {
    local file="${1:?yaml_validate: missing file path}"
    _json_require_yq "yaml_validate" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "yaml_validate: file not found: ${file}"
        return 1
    fi

    yq '.' "$file" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# yaml_get FILE PATH
#   Extract and print the value at the yq PATH from FILE.
#   Requires yq v4+.
# ------------------------------------------------------------------------------
yaml_get() {
    local file="${1:?yaml_get: missing file path}"
    local path="${2:?yaml_get: missing yq path (e.g. .key or .a.b)}"
    _json_require_yq "yaml_get" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "yaml_get: file not found: ${file}"
        return 1
    fi

    yq -r "$path" "$file"
}

# ------------------------------------------------------------------------------
# yaml_set FILE PATH VALUE
#   Update FILE in-place, setting the node at PATH to VALUE (as a string).
#   Requires yq v4+.
# ------------------------------------------------------------------------------
yaml_set() {
    local file="${1:?yaml_set: missing file path}"
    local path="${2:?yaml_set: missing yq path}"
    local value="${3:?yaml_set: missing value}"
    _json_require_yq "yaml_set" || return 1

    if [[ ! -f "$file" ]]; then
        log_error "yaml_set: file not found: ${file}"
        return 1
    fi

    yq -i "${path} = \"${value}\"" "$file"
}

export -f json_validate json_get json_set json_delete json_merge \
          json_keys json_length json_has json_pretty json_compact \
          json_query json_from_args \
          yaml_to_json json_to_yaml yaml_validate yaml_get yaml_set
