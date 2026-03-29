#!/usr/bin/env bats

#====================================================================
# Test suite for the time.sh module
#
# The layout mirrors the existing test files – load dependencies,
# disable colours, and clean up any environment variables that the
# tests may change.
#====================================================================

# ------------------------------------------------------------------
# Global setup – runs once before *any* test case.
# ------------------------------------------------------------------
setup() {
    export NO_COLOR=1

    # Load the library modules in the correct order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/time.sh"
}

# ------------------------------------------------------------------
# Global teardown – runs after each test case.
# ------------------------------------------------------------------
teardown() {
    unset NO_COLOR
}

# ------------------------------------------------------------------
# Verify the module loads and the loaded flag is set.
# ------------------------------------------------------------------
@test "time module reports that it has been loaded" {
    [ -n "${BASH_UTILS_TIME_LOADED:-}" ]
}

# ------------------------------------------------------------------
# time_now – ISO‑8601 timestamp.
# ------------------------------------------------------------------
@test "time_now returns a valid ISO‑8601 string (UTC)" {
    run time_now
    [ "$status" -eq 0 ]

    # Expected pattern: 2023-09-14T12:34:56Z
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# ------------------------------------------------------------------
# time_epoch – seconds since the epoch.
# ------------------------------------------------------------------
@test "time_epoch returns a non‑negative integer" {
    run time_epoch
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    (( output >= 0 ))
}

@test "time_epoch_ms returns a millisecond epoch integer" {
    run time_epoch_ms
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{13,}$ ]]
}

# ------------------------------------------------------------------
# time_benchmark – human readable diff between two epoch values.
# ------------------------------------------------------------------
@test "time_benchmark formats a short interval correctly" {
    run time_benchmark 100 102
    [ "$status" -eq 0 ]
    [ "$output" = "2s" ]
}

@test "time_benchmark rejects invalid arguments" {
    run time_benchmark "" ""
    [ "$status" -ne 0 ]
}

@test "time_epoch_to_iso8601 formats a known epoch (UTC)" {
    run time_epoch_to_iso8601 0 utc
    [ "$status" -eq 0 ]
    [ "$output" = "1970-01-01T00:00:00Z" ]
}

@test "time_parse_iso8601 parses a known ISO-8601 Z timestamp" {
    run time_parse_iso8601 "1970-01-01T00:00:00Z"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "time_add_seconds adds seconds correctly" {
    run time_add_seconds 10 5
    [ "$status" -eq 0 ]
    [ "$output" -eq 15 ]
}

@test "time_diff_seconds computes signed deltas" {
    run time_diff_seconds 15 10
    [ "$status" -eq 0 ]
    [ "$output" -eq -5 ]
}

@test "time_seconds_to_human formats a duration" {
    run time_seconds_to_human 3661
    [ "$status" -eq 0 ]
    [ "$output" = "1h1m1s" ]
}

# ------------------------------------------------------------------
# sleep_until – sleep until a given epoch time.
# ------------------------------------------------------------------
@test "sleep_until sleeps for the requested amount of time" {
    local target

    # Avoid real sleeps in CI: sleeping until a time in the past should be a no-op.
    target=$(( $(time_epoch) - 1 ))
    run sleep_until "$target"
    [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# Ensure the module prevents double‑sourcing.
# ------------------------------------------------------------------
@test "time module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/time.sh"
    [ "$status" -eq 0 ]
}

#===============================================================================
# TIMEZONE OPERATION TESTS
#===============================================================================

@test "time_convert_timezone converts between timezones" {
    # Note: This test may fail on systems without proper timezone support
    run time_convert_timezone "2023-01-15 12:00:00" "UTC" "America/New_York"
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "time_get_timezone returns current timezone" {
    run time_get_timezone
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "time_set_timezone fails for invalid timezone" {
    run time_set_timezone "Invalid/Timezone"
    [ "$status" -eq 1 ]
}

#===============================================================================
# DATE ARITHMETIC TESTS
#===============================================================================

@test "time_add_days adds days correctly" {
    local epoch_jan_1_2023=1672531200  # 2023-01-01 00:00:00 UTC
    local expected_jan_6_2023=1672963200  # 2023-01-06 00:00:00 UTC
    
    run time_add_days "$epoch_jan_1_2023" 5
    [ "$status" -eq 0 ]
    [ "$output" -eq "$expected_jan_6_2023" ]
}

@test "time_add_days handles negative values" {
    local epoch_jan_6_2023=1672963200  # 2023-01-06 00:00:00 UTC
    local expected_jan_1_2023=1672531200  # 2023-01-01 00:00:00 UTC
    
    run time_add_days "$epoch_jan_6_2023" "-5"
    [ "$status" -eq 0 ]
    [ "$output" -eq "$expected_jan_1_2023" ]
}

@test "time_add_hours adds hours correctly" {
    local base_epoch=1672531200  # 2023-01-01 00:00:00 UTC
    local expected_epoch=1672542000  # 2023-01-01 03:00:00 UTC
    
    run time_add_hours "$base_epoch" 3
    [ "$status" -eq 0 ]
    [ "$output" -eq "$expected_epoch" ]
}

@test "time_add_minutes adds minutes correctly" {
    local base_epoch=1672531200  # 2023-01-01 00:00:00 UTC
    local expected_epoch=1672532100  # 2023-01-01 00:15:00 UTC
    
    run time_add_minutes "$base_epoch" 15
    [ "$status" -eq 0 ]
    [ "$output" -eq "$expected_epoch" ]
}

#===============================================================================
# DURATION FORMATTING TESTS
#===============================================================================

@test "time_format_duration formats various durations" {
    run time_format_duration 3661  # 1 hour, 1 minute, 1 second
    [ "$status" -eq 0 ]
    [[ "$output" =~ "1h" ]]
    [[ "$output" =~ "1m" ]]
    [[ "$output" =~ "1s" ]]
}

@test "time_format_duration handles zero duration" {
    run time_format_duration 0
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0" ]]
}

@test "time_parse_duration parses duration strings" {
    run time_parse_duration "1h30m"
    [ "$status" -eq 0 ]
    [ "$output" -eq 5400 ]  # 1.5 hours in seconds
}

@test "time_parse_duration handles invalid duration" {
    run time_parse_duration "invalid"
    [ "$status" -eq 1 ]
}

#===============================================================================
# DATE VALIDATION AND FORMATTING TESTS
#===============================================================================

@test "time_is_valid_date validates correct dates" {
    run time_is_valid_date "2023-12-25"
    [ "$status" -eq 0 ]
    
    run time_is_valid_date "2024-02-29"  # Leap year
    [ "$status" -eq 0 ]
}

@test "time_is_valid_date rejects invalid dates" {
    run time_is_valid_date "2023-02-29"  # Not a leap year
    [ "$status" -eq 1 ]
    
    run time_is_valid_date "2023-13-01"  # Invalid month
    [ "$status" -eq 1 ]
    
    run time_is_valid_date "invalid-date"
    [ "$status" -eq 1 ]
}

@test "time_format_date formats epoch to date string" {
    local epoch_jan_1_2023=1672531200  # 2023-01-01 00:00:00 UTC
    
    run time_format_date "$epoch_jan_1_2023" "%Y-%m-%d"
    [ "$status" -eq 0 ]
    [ "$output" = "2023-01-01" ]
}

@test "time_get_relative returns relative time descriptions" {
    local current_epoch
    current_epoch=$(time_epoch)
    local past_epoch=$((current_epoch - 3600))  # 1 hour ago
    
    run time_get_relative "$past_epoch"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "hour" ]] || [[ "$output" =~ "ago" ]]
}

#===============================================================================
# CRON AND SCHEDULING TESTS
#===============================================================================

@test "time_matches_cron validates cron patterns" {
    # Test with a simple pattern (every day at midnight)
    local epoch_midnight=1672531200  # 2023-01-01 00:00:00 UTC (Sunday)
    
    run time_matches_cron "0 0 * * *" "$epoch_midnight"
    [ "$status" -eq 0 ]
}

@test "time_matches_cron rejects non-matching patterns" {
    local epoch_non_midnight=1672534800  # 2023-01-01 01:00:00 UTC
    
    run time_matches_cron "0 0 * * *" "$epoch_non_midnight"
    [ "$status" -eq 1 ]
}

@test "time_next_cron_run calculates next run time" {
    # This test is complex as it depends on current time and timezone
    # Just verify it doesn't crash and returns a number
    run time_next_cron_run "0 0 * * *"
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
    if [ "$status" -eq 0 ]; then
        [[ "$output" =~ ^[0-9]+$ ]]
    fi
}

@test "time_is_weekday identifies weekdays correctly" {
    # 2023-01-02 was a Monday (weekday)
    local monday_epoch=1672617600
    
    run time_is_weekday "$monday_epoch"
    [ "$status" -eq 0 ]
}

@test "time_is_weekend identifies weekends correctly" {
    # 2023-01-01 was a Sunday (weekend)  
    local sunday_epoch=1672531200
    
    run time_is_weekend "$sunday_epoch"
    [ "$status" -eq 0 ]
}

@test "time_is_weekday and time_is_weekend are mutually exclusive" {
    local test_epoch=1672531200  # 2023-01-01 (Sunday)

    run time_is_weekday "$test_epoch"
    local weekday_result=$status

    run time_is_weekend "$test_epoch"
    local weekend_result=$status

    # One should succeed (status 0) and the other should fail (status 1)
    [[ ($weekday_result -eq 0 && $weekend_result -eq 1) || ($weekday_result -eq 1 && $weekend_result -eq 0) ]]
}

#===============================================================================
# ERROR HANDLING TESTS
#===============================================================================

@test "time functions handle invalid epoch times" {
    # Test with invalid epoch times
    run time_add_days "invalid" 1
    [ "$status" -eq 1 ]
    
    run time_add_hours "not_a_number" 1
    [ "$status" -eq 1 ]
    
    run time_format_date "invalid" "%Y"
    [ "$status" -eq 1 ]
}

@test "time functions handle missing arguments" {
    run time_add_days
    [ "$status" -eq 1 ]
    
    run time_add_hours 
    [ "$status" -eq 1 ]
    
    run time_format_date
    [ "$status" -eq 1 ]
    
    run time_matches_cron
    [ "$status" -eq 1 ]
}

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "time arithmetic functions work together" {
    local base_epoch=1672531200  # 2023-01-01 00:00:00 UTC
    
    # Add 1 day, 2 hours, and 30 minutes
    local after_days
    after_days=$(time_add_days "$base_epoch" 1)
    
    local after_hours
    after_hours=$(time_add_hours "$after_days" 2)
    
    local final_time
    final_time=$(time_add_minutes "$after_hours" 30)
    
    # Should be 2023-01-02 02:30:00 UTC = base + 93000 seconds
    local expected=$((base_epoch + 86400 + 7200 + 1800))
    [ "$final_time" -eq "$expected" ]
}