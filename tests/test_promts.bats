#!/usr/bin/env bats

# ------------------------------------------------------------
# BATS tests for lib/prompts.sh
# ------------------------------------------------------------
# The tests load the whole library so that the colour/log
# helpers (logging.sh, config.sh, etc.) are available.
# ------------------------------------------------------------

# Source the module under test
setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/prompts.sh"
}

teardown() {
    # Unset all functions that were exported by the library so that
    # each test starts with a clean environment.
    unset -f prompt_input prompt_password prompt_confirm prompt_menu
    unset -f log_* _log _get_timestamp
    # (the library itself does not define globals that need cleaning)
}

# -----------------------------------------------------------------
# prompt_input – basic text prompt with and without a default value
# -----------------------------------------------------------------
@test "prompt_input returns typed value" {
    run bash -c '
        # discard the prompt that goes to stdout
        printf "hello\n" | prompt_input "Enter something" 2>/dev/null
    '
    [ "$status" -eq 0 ]
    # keep only the last line (the actual answer)
    output=$(printf "%s\n" "$output" | tail -n1)
    [ "$output" = "hello" ]
}

# ------------------------------------------------------------------
#  prompt_input - Prompt returns the default when the user just hits Enter
# ------------------------------------------------------------------
@test "prompt_input returns default when user hits Enter" {
    
    source "${BATS_TEST_DIRNAME}/../modules/prompts.sh"

    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        prompt_input "Enter something" "default-value" < <(printf "\n")
    '

    # Debug output
    # echo "DEBUG-OUT:$output"
    # echo "DEBUG-ERR:$stderr"

    [ "$status" -eq 0 ]
    # just because the bats messes up with stdout/stderr capturing
    # we check both output and stderr for the prompt message and answer
    # you can easily verify this by uncommenting the debug lines above
    [[ "$output" = "Enter something default-value" ]]
    # [[ "$stderr" = "Enter something " ]]
}


# -----------------------------------------------------------------
# prompt_password – silent read, returns the exact string
# -----------------------------------------------------------------
@test "prompt_password returns the supplied password" {
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "mySecret\n" | prompt_password "Password"
    '

    # Debug output
    # echo "DEBUG-OUT:$output"
    # echo "DEBUG-ERR:$stderr"

    # exit code ok
    [ "$status" -eq 0 ]

    # password is in stdout
    [ "$output" = "mySecret" ]

    # prompt may be in stdout or stderr
    [[ "$stderr" = "" || "$stderr" = "Password " ]]
}

# -----------------------------------------------------------------
# prompt_confirm – yes/no confirmation, respects default
# -----------------------------------------------------------------
@test "prompt_confirm returns true for Y/y input" {
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "y\n" | prompt_confirm "Proceed?" "n"
    '

    [ "$status" -eq 0 ]   # 0 = success → user answered Yes
}

@test "prompt_confirm returns false for N/n input" {
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "n\n" | prompt_confirm "Proceed?" "y"
    '

    [ "$status" -ne 0 ]   # non‑zero = No
}

@test "prompt_confirm uses default when empty input" {
    # Default is "y" → should succeed
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "\n" | prompt_confirm "Proceed?" "y"
    '

    [ "$status" -eq 0 ]

    # Default is "n" → should fail
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "\n" | prompt_confirm "Proceed?" "n"
    '

    [ "$status" -ne 0 ]
}

# -----------------------------------------------------------------
# prompt_menu – displays a list of options and returns the chosen
# -----------------------------------------------------------------


@test "prompt_menu works" {
    # Simulate a user typing "2" (the second option)
    # Build a simple menu that prints three lines, then reads the choice.
    # The function itself prints the prompt, so we only need to feed the
    # selection number.
    output=$(prompt_menu "Pick a fruit:" "apple" "banana" "cherry" 2>/dev/null <<<"2")
    [ "$output" = "banana" ]
}

@test "prompt_menu re‑asks when invalid selection is given" {
    # Feed an invalid number first, then a valid one.
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "5\n3\n" | prompt_menu "Pick a number:" "one" "two" "three" 2>/dev/null
    '
    # the function succeeded
    [ "$status" -eq 0 ]
    # and the final (valid) selection is printed
    [ "$output" = "three" ]
}

@test "prompt_menu returns empty string when user aborts (EOF)" {
    # If the pipe ends without any data, the function will return an empty
    # string and a non‑zero status.
    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/prompts.sh"
        printf "" | prompt_menu "Pick?" "a" "b" 2>/dev/null
    '

    [ "$status" -ne 0 ]
    [ -z "${output}" ]
}