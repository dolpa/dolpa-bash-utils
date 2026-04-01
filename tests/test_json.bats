#!/usr/bin/env bats
# ==============================================================================
# test_json.bats – Unit tests for the json.sh module
# ==============================================================================
#
# JSON tests use real jq (installed in the Docker image).
# YAML tests use a mock yq placed first in $PATH so no real yq install is needed.
#
# Mock yq behaviour:
#   yq -o=json '.' <valid YAML file>  → {"key":"value"}
#   yq -P '.'      <valid JSON file>  → key: value
#   yq '.'         <valid YAML file>  → exit 0   (validate)
#   yq -r '.host'  <YAML file>        → localhost
#   yq -i '...'    <YAML file>        → rewrites file with NEW_HOST=newval
#   yq '.'         <invalid.yaml>     → exit 1
# ==============================================================================

setup() {
    export NO_COLOR=1
    export ORIG_PATH="$PATH"

    # Temporary directories
    export MOCK_BIN_DIR
    MOCK_BIN_DIR="$(mktemp -d)"
    export TEST_TMP
    TEST_TMP="$(mktemp -d)"

    # ------------------------------------------------------------------
    # Mock yq – handles only the subset of operations used in tests.
    # ------------------------------------------------------------------
    cat > "${MOCK_BIN_DIR}/yq" <<'YQ_EOF'
#!/usr/bin/env bash
# Minimal yq mock for test_json.bats

# Parse flags
output_json=0
pretty=0
inplace=0
raw=0
filter=""
file=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o=json|--output-format=json) output_json=1 ; shift ;;
        -P|--prettyPrint)             pretty=1       ; shift ;;
        -i|--inplace)                 inplace=1      ; shift ;;
        -r|--raw-output)              raw=1          ; shift ;;
        --)  shift ; break ;;
        -*)  shift ;;   # ignore unknown flags
        *)
            if [[ -z "$filter" ]]; then
                filter="$1"
            else
                file="$1"
            fi
            shift
            ;;
    esac
done

# If no file was parsed, last positional already went to filter; use stdin path
if [[ -z "$file" ]]; then
    file="$filter"
    filter="."
fi

# Validate / base operation
if [[ ! -f "$file" ]]; then
    echo "Error: file not found: $file" >&2
    exit 1
fi

# Detect invalid YAML marker written by the test
if grep -q "INVALID_YAML_MARKER" "$file" 2>/dev/null; then
    echo "Error: bad indentation" >&2
    exit 1
fi

# yaml_to_json: -o=json flag
if (( output_json )); then
    printf '{"host":"localhost","port":5432}\n'
    exit 0
fi

# json_to_yaml: -P flag
if (( pretty )); then
    printf 'host: localhost\nport: 5432\n'
    exit 0
fi

# yaml_get: -r with a specific filter
if (( raw )); then
    case "$filter" in
        .host)    printf 'localhost\n' ; exit 0 ;;
        .port)    printf '5432\n'      ; exit 0 ;;
        .missing) printf 'null\n'     ; exit 0 ;;
        *)        printf 'mockval\n'  ; exit 0 ;;
    esac
fi

# yaml_set: -i flag – write a marker so the test can verify in-place write
if (( inplace )); then
    # The filter looks like '.key = "value"' – extract value
    new_val="$(printf '%s' "$filter" | sed 's/.*= "\(.*\)"/\1/')"
    printf 'host: %s\n' "$new_val" > "$file"
    exit 0
fi

# yaml_validate (.): just succeed for valid content
exit 0
YQ_EOF
    chmod +x "${MOCK_BIN_DIR}/yq"

    # Place mock dir first so it shadows any real yq.
    export PATH="${MOCK_BIN_DIR}:${ORIG_PATH}"

    # Load modules under test.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/json.sh"

    # ------------------------------------------------------------------
    # Fixture files used across multiple tests.
    # ------------------------------------------------------------------
    export JSON_SIMPLE="${TEST_TMP}/simple.json"
    export JSON_NESTED="${TEST_TMP}/nested.json"
    export JSON_ARRAY="${TEST_TMP}/array.json"
    export YAML_VALID="${TEST_TMP}/valid.yaml"
    export YAML_INVALID="${TEST_TMP}/invalid.yaml"

    printf '{"name":"Alice","age":30,"active":true}\n'   > "$JSON_SIMPLE"
    printf '{"db":{"host":"localhost","port":5432}}\n'    > "$JSON_NESTED"
    printf '[1,2,3,4,5]\n'                                > "$JSON_ARRAY"
    printf 'host: localhost\nport: 5432\n'               > "$YAML_VALID"
    printf 'INVALID_YAML_MARKER\n  bad: [indentation\n'  > "$YAML_INVALID"
}

teardown() {
    export PATH="$ORIG_PATH"
    rm -rf "${MOCK_BIN_DIR}" "${TEST_TMP}"
    unset MOCK_BIN_DIR TEST_TMP ORIG_PATH
    unset JSON_SIMPLE JSON_NESTED JSON_ARRAY YAML_VALID YAML_INVALID
}

# ==============================================================================
# Module loading
# ==============================================================================

@test "json module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/json.sh"
    [ "$status" -eq 0 ]
}

@test "json module sets BASH_UTILS_JSON_LOADED" {
    [ "${BASH_UTILS_JSON_LOADED}" = "true" ]
}

@test "json module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/json.sh"
    [ "$status" -eq 0 ]
}

@test "all json_ functions are defined" {
    declare -f json_validate   >/dev/null
    declare -f json_get        >/dev/null
    declare -f json_set        >/dev/null
    declare -f json_delete     >/dev/null
    declare -f json_merge      >/dev/null
    declare -f json_keys       >/dev/null
    declare -f json_length     >/dev/null
    declare -f json_has        >/dev/null
    declare -f json_pretty     >/dev/null
    declare -f json_compact    >/dev/null
    declare -f json_query      >/dev/null
    declare -f json_from_args  >/dev/null
}

@test "all yaml_ functions are defined" {
    declare -f yaml_to_json   >/dev/null
    declare -f json_to_yaml   >/dev/null
    declare -f yaml_validate  >/dev/null
    declare -f yaml_get       >/dev/null
    declare -f yaml_set       >/dev/null
}

# ==============================================================================
# json_validate
# ==============================================================================

@test "json_validate returns 0 for a valid JSON string" {
    run json_validate '{"a":1}'
    [ "$status" -eq 0 ]
}

@test "json_validate returns non-zero for an invalid JSON string" {
    run json_validate '{not valid}'
    [ "$status" -ne 0 ]
}

@test "json_validate accepts a file path" {
    run json_validate "$JSON_SIMPLE"
    [ "$status" -eq 0 ]
}

@test "json_validate returns non-zero for a missing file treated as invalid JSON" {
    run json_validate '/tmp/does_not_exist_$$'
    [ "$status" -ne 0 ]
}

@test "json_validate returns 0 for a JSON array" {
    run json_validate '[1,2,3]'
    [ "$status" -eq 0 ]
}

@test "json_validate returns 0 for an empty object" {
    run json_validate '{}'
    [ "$status" -eq 0 ]
}

# ==============================================================================
# json_get
# ==============================================================================

@test "json_get extracts a top-level string value" {
    run json_get "$JSON_SIMPLE" '.name'
    [ "$status" -eq 0 ]
    [ "$output" = "Alice" ]
}

@test "json_get extracts a top-level number value" {
    run json_get "$JSON_SIMPLE" '.age'
    [ "$status" -eq 0 ]
    [ "$output" = "30" ]
}

@test "json_get extracts a nested value" {
    run json_get "$JSON_NESTED" '.db.host'
    [ "$status" -eq 0 ]
    [ "$output" = "localhost" ]
}

@test "json_get returns null for a missing key" {
    run json_get "$JSON_SIMPLE" '.missing'
    [ "$status" -eq 0 ]
    [ "$output" = "null" ]
}

@test "json_get works on a raw JSON string" {
    run json_get '{"greeting":"hello"}' '.greeting'
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "json_get extracts an array element by index" {
    run json_get '[10,20,30]' '.[1]'
    [ "$status" -eq 0 ]
    [ "$output" = "20" ]
}

@test "json_get requires both arguments" {
    run json_get
    [ "$status" -ne 0 ]
}

# ==============================================================================
# json_set
# ==============================================================================

@test "json_set updates an existing string value in-place" {
    cp "$JSON_SIMPLE" "${TEST_TMP}/set_test.json"
    run json_set "${TEST_TMP}/set_test.json" '.name' 'Bob'
    [ "$status" -eq 0 ]
    result="$(json_get "${TEST_TMP}/set_test.json" '.name')"
    [ "$result" = "Bob" ]
}

@test "json_set adds a new key when the key does not exist" {
    cp "$JSON_SIMPLE" "${TEST_TMP}/set_new.json"
    run json_set "${TEST_TMP}/set_new.json" '.email' 'alice@example.com'
    [ "$status" -eq 0 ]
    result="$(json_get "${TEST_TMP}/set_new.json" '.email')"
    [ "$result" = "alice@example.com" ]
}

@test "json_set updates a nested key" {
    cp "$JSON_NESTED" "${TEST_TMP}/set_nested.json"
    run json_set "${TEST_TMP}/set_nested.json" '.db.host' 'remotedb'
    [ "$status" -eq 0 ]
    result="$(json_get "${TEST_TMP}/set_nested.json" '.db.host')"
    [ "$result" = "remotedb" ]
}

@test "json_set --raw inserts a number value" {
    cp "$JSON_SIMPLE" "${TEST_TMP}/set_raw.json"
    run json_set "${TEST_TMP}/set_raw.json" '.age' '99' '--raw'
    [ "$status" -eq 0 ]
    result="$(json_get "${TEST_TMP}/set_raw.json" '.age')"
    [ "$result" = "99" ]
}

@test "json_set --raw inserts a boolean value" {
    cp "$JSON_SIMPLE" "${TEST_TMP}/set_bool.json"
    run json_set "${TEST_TMP}/set_bool.json" '.active' 'false' '--raw'
    [ "$status" -eq 0 ]
    result="$(json_get "${TEST_TMP}/set_bool.json" '.active')"
    [ "$result" = "false" ]
}

@test "json_set fails when the file does not exist" {
    run json_set '/tmp/no_such_$$' '.key' 'val'
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ==============================================================================
# json_delete
# ==============================================================================

@test "json_delete removes an existing key" {
    cp "$JSON_SIMPLE" "${TEST_TMP}/del_test.json"
    run json_delete "${TEST_TMP}/del_test.json" '.age'
    [ "$status" -eq 0 ]
    result="$(json_get "${TEST_TMP}/del_test.json" '.age')"
    [ "$result" = "null" ]
}

@test "json_delete deleting a nested key leaves siblings intact" {
    cp "$JSON_NESTED" "${TEST_TMP}/del_nested.json"
    json_delete "${TEST_TMP}/del_nested.json" '.db.host'
    host="$(json_get "${TEST_TMP}/del_nested.json" '.db.host')"
    port="$(json_get "${TEST_TMP}/del_nested.json" '.db.port')"
    [ "$host" = "null" ]
    [ "$port" = "5432" ]
}

@test "json_delete fails when the file does not exist" {
    run json_delete '/tmp/no_such_$$' '.key'
    [ "$status" -ne 0 ]
}

# ==============================================================================
# json_merge
# ==============================================================================

@test "json_merge OUTPUT contains all keys from both files" {
    printf '{"a":1,"b":2}\n' > "${TEST_TMP}/m1.json"
    printf '{"c":3}\n'       > "${TEST_TMP}/m2.json"
    run json_merge "${TEST_TMP}/m1.json" "${TEST_TMP}/m2.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"a"'* ]]
    [[ "$output" == *'"c"'* ]]
}

@test "json_merge overlay wins on conflicting keys" {
    printf '{"version":"1.0"}\n' > "${TEST_TMP}/base.json"
    printf '{"version":"2.0"}\n' > "${TEST_TMP}/overlay.json"
    run json_merge "${TEST_TMP}/base.json" "${TEST_TMP}/overlay.json"
    [ "$status" -eq 0 ]
    val="$(printf '%s' "$output" | jq -r '.version')"
    [ "$val" = "2.0" ]
}

@test "json_merge performs a deep merge on nested objects" {
    printf '{"db":{"host":"old","port":5432}}\n' > "${TEST_TMP}/deep1.json"
    printf '{"db":{"host":"new"}}\n'              > "${TEST_TMP}/deep2.json"
    run json_merge "${TEST_TMP}/deep1.json" "${TEST_TMP}/deep2.json"
    [ "$status" -eq 0 ]
    host="$(printf '%s' "$output" | jq -r '.db.host')"
    port="$(printf '%s' "$output" | jq -r '.db.port')"
    [ "$host" = "new" ]
    [ "$port" = "5432" ]
}

@test "json_merge fails when a file does not exist" {
    run json_merge "$JSON_SIMPLE" '/tmp/no_such_$$'
    [ "$status" -ne 0 ]
}

# ==============================================================================
# json_keys
# ==============================================================================

@test "json_keys lists all top-level keys" {
    run json_keys "$JSON_SIMPLE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"name"* ]]
    [[ "$output" == *"age"* ]]
    [[ "$output" == *"active"* ]]
}

@test "json_keys with a PATH lists keys of a nested object" {
    run json_keys "$JSON_NESTED" '.db'
    [ "$status" -eq 0 ]
    [[ "$output" == *"host"* ]]
    [[ "$output" == *"port"* ]]
}

@test "json_keys works on a raw JSON string" {
    run json_keys '{"x":1,"y":2}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"x"* ]]
    [[ "$output" == *"y"* ]]
}

# ==============================================================================
# json_length
# ==============================================================================

@test "json_length returns the number of elements in an array" {
    run json_length "$JSON_ARRAY"
    [ "$status" -eq 0 ]
    [ "$output" = "5" ]
}

@test "json_length returns the number of keys in an object" {
    run json_length "$JSON_SIMPLE"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "json_length with a PATH counts elements in a nested array" {
    printf '{"tags":["a","b","c"]}\n' > "${TEST_TMP}/tags.json"
    run json_length "${TEST_TMP}/tags.json" '.tags'
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "json_length works on a raw JSON string" {
    run json_length '{"a":1}'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

# ==============================================================================
# json_has
# ==============================================================================

@test "json_has returns 0 for an existing key" {
    run json_has "$JSON_SIMPLE" '.name'
    [ "$status" -eq 0 ]
}

@test "json_has returns non-zero for a missing key" {
    run json_has "$JSON_SIMPLE" '.missing'
    [ "$status" -ne 0 ]
}

@test "json_has returns non-zero for a null value" {
    run json_has '{"x":null}' '.x'
    [ "$status" -ne 0 ]
}

@test "json_has returns 0 for a nested key" {
    run json_has "$JSON_NESTED" '.db.host'
    [ "$status" -eq 0 ]
}

# ==============================================================================
# json_pretty / json_compact
# ==============================================================================

@test "json_pretty produces multi-line output" {
    run json_pretty '{"a":1,"b":2}'
    [ "$status" -eq 0 ]
    # Multi-line: output should span more than one line
    local line_count
    line_count="$(printf '%s\n' "$output" | grep -c '.')"
    [ "$line_count" -gt 1 ]
}

@test "json_compact produces single-line output" {
    run json_compact '{"a": 1,  "b": 2 }'
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
}

@test "json_compact output is valid JSON" {
    run json_compact "$JSON_SIMPLE"
    [ "$status" -eq 0 ]
    run json_validate "$output"
    [ "$status" -eq 0 ]
}

@test "json_pretty and json_compact are inverse operations" {
    compact="$(json_compact "$JSON_SIMPLE")"
    pretty="$(json_pretty "$compact")"
    compact2="$(json_compact "$pretty")"
    [ "$compact" = "$compact2" ]
}

# ==============================================================================
# json_query
# ==============================================================================

@test "json_query runs an arbitrary jq filter" {
    run json_query '[1,2,3,4,5]' '.[] | select(. > 3)'
    [ "$status" -eq 0 ]
    [[ "$output" == *"4"* ]]
    [[ "$output" == *"5"* ]]
}

@test "json_query extracts all values from an array of objects" {
    run json_query '[{"n":"Alice"},{"n":"Bob"}]' '.[].n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Alice"* ]]
    [[ "$output" == *"Bob"* ]]
}

@test "json_query requires both arguments" {
    run json_query '{"a":1}'
    [ "$status" -ne 0 ]
}

# ==============================================================================
# json_from_args
# ==============================================================================

@test "json_from_args builds a simple string-valued object" {
    run json_from_args name=Alice city=Paris
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.name')" = "Alice" ]
    [ "$(printf '%s' "$output" | jq -r '.city')" = "Paris" ]
}

@test "json_from_args auto-types integer values as numbers" {
    run json_from_args age=30
    [ "$status" -eq 0 ]
    # jq returns 30 (not "30") for a number
    val="$(printf '%s' "$output" | jq -r '.age')"
    [ "$val" = "30" ]
    # Verify it's not a string by checking the jq type
    typ="$(printf '%s' "$output" | jq -r '.age | type')"
    [ "$typ" = "number" ]
}

@test "json_from_args auto-types boolean true" {
    run json_from_args active=true
    [ "$status" -eq 0 ]
    typ="$(printf '%s' "$output" | jq -r '.active | type')"
    [ "$typ" = "boolean" ]
}

@test "json_from_args auto-types null" {
    run json_from_args deleted=null
    [ "$status" -eq 0 ]
    val="$(printf '%s' "$output" | jq -r '.deleted')"
    [ "$val" = "null" ]
}

@test "json_from_args produces valid JSON" {
    run json_from_args name=Alice age=30 active=true
    [ "$status" -eq 0 ]
    run json_validate "$output"
    [ "$status" -eq 0 ]
}

@test "json_from_args fails when no arguments are given" {
    run json_from_args
    [ "$status" -ne 0 ]
}

@test "json_from_args fails for an argument without an equals sign" {
    run json_from_args notakeyvalue
    [ "$status" -ne 0 ]
}

@test "json_from_args handles a string value containing spaces" {
    run json_from_args "greeting=hello world"
    [ "$status" -eq 0 ]
    val="$(printf '%s' "$output" | jq -r '.greeting')"
    [ "$val" = "hello world" ]
}

# ==============================================================================
# yaml_to_json
# ==============================================================================

@test "yaml_to_json converts a valid YAML file to JSON" {
    run yaml_to_json "$YAML_VALID"
    [ "$status" -eq 0 ]
    run json_validate "$output"
    [ "$status" -eq 0 ]
}

@test "yaml_to_json output contains expected keys" {
    run yaml_to_json "$YAML_VALID"
    [ "$status" -eq 0 ]
    [[ "$output" == *"host"* ]]
}

@test "yaml_to_json fails when the file does not exist" {
    run yaml_to_json "/tmp/no_such_$$"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ==============================================================================
# json_to_yaml
# ==============================================================================

@test "json_to_yaml converts a valid JSON file to YAML" {
    run json_to_yaml "$JSON_SIMPLE"
    [ "$status" -eq 0 ]
    # Mock yq -P outputs valid YAML-like text
    [ -n "$output" ]
}

@test "json_to_yaml fails when the file does not exist" {
    run json_to_yaml "/tmp/no_such_$$"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# ==============================================================================
# yaml_validate
# ==============================================================================

@test "yaml_validate returns 0 for a valid YAML file" {
    run yaml_validate "$YAML_VALID"
    [ "$status" -eq 0 ]
}

@test "yaml_validate returns non-zero for an invalid YAML file" {
    run yaml_validate "$YAML_INVALID"
    [ "$status" -ne 0 ]
}

@test "yaml_validate fails when the file does not exist" {
    run yaml_validate "/tmp/no_such_$$"
    [ "$status" -ne 0 ]
}

# ==============================================================================
# yaml_get
# ==============================================================================

@test "yaml_get extracts a top-level string value" {
    run yaml_get "$YAML_VALID" '.host'
    [ "$status" -eq 0 ]
    [ "$output" = "localhost" ]
}

@test "yaml_get extracts a top-level number value" {
    run yaml_get "$YAML_VALID" '.port'
    [ "$status" -eq 0 ]
    [ "$output" = "5432" ]
}

@test "yaml_get fails when the file does not exist" {
    run yaml_get "/tmp/no_such_$$" '.key'
    [ "$status" -ne 0 ]
}

# ==============================================================================
# yaml_set
# ==============================================================================

@test "yaml_set updates a value in-place" {
    cp "$YAML_VALID" "${TEST_TMP}/set_yaml.yaml"
    run yaml_set "${TEST_TMP}/set_yaml.yaml" '.host' 'remotehost'
    [ "$status" -eq 0 ]
    # Mock yq writes 'host: remotehost' to file
    [[ "$(cat "${TEST_TMP}/set_yaml.yaml")" == *"remotehost"* ]]
}

@test "yaml_set fails when the file does not exist" {
    run yaml_set "/tmp/no_such_$$" '.key' 'val'
    [ "$status" -ne 0 ]
}

# ==============================================================================
# jq-missing behaviour
# ==============================================================================

@test "json_get fails gracefully when jq is unavailable" {
    # Temporarily override the tool-presence flag checked by _json_require_jq.
    local saved="${_JSON_HAS_JQ}"
    _JSON_HAS_JQ="false"
    run json_get '{"a":1}' '.a'
    _JSON_HAS_JQ="$saved"
    [ "$status" -ne 0 ]
    [[ "$output" == *"jq"* ]]
}

@test "json_set fails gracefully when jq is unavailable" {
    cp "$JSON_SIMPLE" "${TEST_TMP}/jq_missing.json"
    local saved="${_JSON_HAS_JQ}"
    _JSON_HAS_JQ="false"
    run json_set "${TEST_TMP}/jq_missing.json" '.name' 'Bob'
    _JSON_HAS_JQ="$saved"
    [ "$status" -ne 0 ]
}

# ==============================================================================
# yq-missing behaviour
# ==============================================================================

@test "yaml_to_json fails gracefully when yq is unavailable" {
    local saved="${_JSON_HAS_YQ}"
    _JSON_HAS_YQ="false"
    run yaml_to_json "$YAML_VALID"
    _JSON_HAS_YQ="$saved"
    [ "$status" -ne 0 ]
    [[ "$output" == *"yq"* ]]
}

@test "yaml_validate fails gracefully when yq is unavailable" {
    local saved="${_JSON_HAS_YQ}"
    _JSON_HAS_YQ="false"
    run yaml_validate "$YAML_VALID"
    _JSON_HAS_YQ="$saved"
    [ "$status" -ne 0 ]
}
