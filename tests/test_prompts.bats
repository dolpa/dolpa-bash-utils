#!/usr/bin/env bats

# Test prompts.sh module

setup() {
    # Load required modules in dependency order
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh" 
    source "${BATS_TEST_DIRNAME}/../modules/prompts.sh"
}

teardown() {
    # Clean up any environment variables set during tests
    # Note: Cannot unset readonly variables
    unset -f prompt_input prompt_password prompt_confirm prompt_confirm_yes prompt_menu prompt_pause prompt_number 2>/dev/null || true
}

@test "prompts module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/prompts.sh"
    [ "$status" -eq 0 ]
}

@test "prompts module sets BASH_UTILS_PROMPTS_LOADED" {
    [ "$BASH_UTILS_PROMPTS_LOADED" = "true" ]
}

@test "prompts module prevents multiple sourcing" {
    # Source again, should return immediately
    run source "${BATS_TEST_DIRNAME}/../modules/prompts.sh"
    [ "$status" -eq 0 ]
}

#===============================================================================
# PROMPT_INPUT TESTS
#===============================================================================

@test "prompt_input returns typed value" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "test_input" | prompt_input "Enter value: "
    '
    [ "$status" -eq 0 ]
    [ "$output" = "test_input" ]
}

@test "prompt_input returns default when empty input" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "" | prompt_input "Enter value: " "default_value"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "default_value" ]
}

@test "prompt_input trims whitespace from input" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "  test_input  " | prompt_input "Enter value: "
    '
    [ "$status" -eq 0 ]
    [ "$output" = "test_input" ]
}

#===============================================================================
# PROMPT_PASSWORD TESTS
#===============================================================================

@test "prompt_password returns password in non-interactive mode" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "secret123" | prompt_password "Enter password: "
    '
    [ "$status" -eq 0 ]
    [ "$output" = "secret123" ]
}

#===============================================================================
# PROMPT_CONFIRM TESTS
#===============================================================================

@test "prompt_confirm returns 0 for yes" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "y" | prompt_confirm "Continue?"
    '
    [ "$status" -eq 0 ]
}

@test "prompt_confirm returns 1 for no" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "n" | prompt_confirm "Continue?"
    '
    [ "$status" -eq 1 ]
}

@test "prompt_confirm returns 1 for empty input (default no)" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "" | prompt_confirm "Continue?"
    '
    [ "$status" -eq 1 ]
}

@test "prompt_confirm_yes returns 0 for yes" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "y" | prompt_confirm_yes "Continue?"
    '
    [ "$status" -eq 0 ]
}

@test "prompt_confirm_yes returns 0 for empty input (default yes)" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "" | prompt_confirm_yes "Continue?"
    '
    [ "$status" -eq 0 ]
}

#===============================================================================
# PROMPT_MENU TESTS
#===============================================================================

@test "prompt_menu returns selected option" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "1" | prompt_menu "Select:" "Option A" "Option B" "Option C"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "Option A" ]
}

@test "prompt_menu returns error for quit" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "q" | prompt_menu "Select:" "Option A" "Option B"
    '
    [ "$status" -eq 1 ]
}

#===============================================================================
# PROMPT_NUMBER TESTS
#===============================================================================

@test "prompt_number returns valid number" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        echo "42" | prompt_number "Enter number: "
    '
    [ "$status" -eq 0 ]
    [ "$output" = "42" ]
}

@test "prompt_number validates minimum value" {
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh" 
        source "'${BATS_TEST_DIRNAME}'/../modules/prompts.sh"
        printf "5\\n10\\n" | prompt_number "Enter number: " 8 20
    '
    [ "$status" -eq 0 ]
    [ "$output" = "10" ]
}

#===============================================================================
# FUNCTION EXISTENCE TESTS
#===============================================================================

@test "all prompt functions are defined" {
    type prompt_input &>/dev/null
    type prompt_password &>/dev/null
    type prompt_confirm &>/dev/null
    type prompt_confirm_yes &>/dev/null
    type prompt_menu &>/dev/null
    type prompt_pause &>/dev/null
    type prompt_number &>/dev/null
}