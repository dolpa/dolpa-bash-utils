#!/usr/bin/env bats

#=====================================================================
# Test suite for the network.sh module
#
# The style follows the other test files in the repository:
#   • All required modules are sourced in the correct order.
#   • Colours are disabled (NO_COLOR=1) for deterministic output.
#   • Environment variables that can be changed by the tests are
#     reset in teardown().
#   • Each public function is exercised with both success and failure
#     cases where possible.
#=====================================================================

# ------------------------------------------------------------------
# Global setup – executed before *any* test case.
# ------------------------------------------------------------------
setup() {
    # Load the library modules in dependency order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/network.sh"

    # Ensure deterministic output – no colour codes.
    export NO_COLOR=1

    # Use a short timeout for the network calls so the CI does not
    # stall for a long time if the network is unreachable.
    export BASH_UTILS_NETWORK_TIMEOUT=3
}

# ------------------------------------------------------------------
# Global teardown – executed after *each* test case.
# ------------------------------------------------------------------
teardown() {
    # Reset any variables that the tests may have altered.
    unset BASH_UTILS_NETWORK_TIMEOUT
    unset NO_COLOR
}

# ------------------------------------------------------------------
# Verify the module loads correctly and the loaded flag is set.
# ------------------------------------------------------------------
@test "network module reports that it has been loaded" {
    [ -n "${BASH_UTILS_NETWORK_LOADED:-}" ]
}

# ------------------------------------------------------------------
# ping_host() – ping localhost (should always succeed)
# ------------------------------------------------------------------
@test "ping_host succeeds for localhost" {
    source "${BATS_TEST_DIRNAME}/../modules/network.sh"
    
    run ping_host localhost
    [ "$status" -eq 0 ]
}

@test "ping_host fails for an invalid host" {
    run ping_host "nonexistent.invalid.host"
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# resolve_ip() – resolve known hostnames
# ------------------------------------------------------------------
@test "resolve_ip returns an IP for localhost" {
    run resolve_ip "localhost"
    [ "$status" -eq 0 ]
    # The result can be IPv4 or IPv6 – accept both.
    [[ "${output}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "${output}" =~ ^(::1|[0-9a-fA-F:]+)$ ]]
}

@test "resolve_ip fails for a non‑existent hostname" {
    run resolve_ip "nonexistent.invalid.host"
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# is_port_open() – check a port that is *very likely* closed.
# ------------------------------------------------------------------
@test "is_port_open reports closed port on localhost" {
    # Choose a high random port that is almost certainly not used.
    run is_port_open "127.0.0.1" "54321"
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# download_file()
# ------------------------------------------------------------------
@test "download_file fails for an invalid URL" {
    # Use a clearly malformed URL – validation should reject it.
    run download_file "ht!tp://bad_url" "/tmp/does_not_matter"
    [ "$status" -eq 1 ]
}

@test "download_file fails when destination directory does not exist" {
    run download_file "https://example.com" "/nonexistent_dir/file.txt"
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# check_url()
# ------------------------------------------------------------------
@test "check_url succeeds for a reachable URL (example.com)" {
    run check_url "https://example.com"
    [ "$status" -eq 0 ]
}

@test "check_url fails for an unreachable URL" {
    run check_url "http://10.255.255.1"   # an IP that is not routable on most CI runners
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# get_public_ip()
# ------------------------------------------------------------------
@test "get_public_ip returns a syntactically valid IPv4 address" {
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "${output}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

#=====================================================================
# END OF TEST FILE
#=====================================================================