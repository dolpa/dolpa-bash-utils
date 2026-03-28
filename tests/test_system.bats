#!/usr/bin/env bats

# Test system.sh module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/system.sh"
    
    # Disable colors for consistent testing
    export NO_COLOR=1
}

teardown() {
    # Note: Cannot unset readonly variables
    true
}

@test "system module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/system.sh"
    [ "$status" -eq 0 ]
}

@test "system module sets BASH_UTILS_SYSTEM_LOADED" {
    [ "$BASH_UTILS_SYSTEM_LOADED" = "true" ]
}

@test "get_os_name returns a value" {
    result=$(get_os_name)
    [ -n "$result" ]
}

@test "get_os_version returns a value" {
    result=$(get_os_version)
    [ -n "$result" ]
}

@test "auto_detect_system function exists" {
    # This function may fail on systems without DMI info
    # Just test that it exists and doesn't crash
    run auto_detect_system
    # Status can be 0 (success) or 1 (no DMI info), both are valid
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# Note: More comprehensive system tests would require
# specific system configurations and are environment-dependent

#===============================================================================
# HARDWARE AND SYSTEM INFO TESTS
#===============================================================================

@test "get_cpu_info returns CPU information" {
    run get_cpu_info
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "get_memory_info returns memory information" {
    run get_memory_info
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "get_disk_info returns disk information" {
    run get_disk_info
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "get_system_info returns system information" {
    run get_system_info
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain some system details
    [[ "$output" == *"OS:"* ]] || [[ "$output" == *"Kernel:"* ]]
}

@test "detect_virtualization detects virtualization status" {
    run detect_virtualization
    [ "$status" -eq 0 ]
    # Output should be either "none", "vm", "container", or specific type
    [[ "$output" =~ ^(none|vm|container|kvm|vmware|virtualbox|xen|docker|podman)$ ]]
}

@test "get_architecture returns system architecture" {
    run get_architecture
    [ "$status" -eq 0 ]
    # Should return common architectures
    [[ "$output" =~ ^(x86_64|i386|i686|aarch64|arm64|armv7l|ppc64le|s390x)$ ]]
}

#===============================================================================
# PERFORMANCE MONITORING TESTS
#===============================================================================

@test "get_cpu_usage returns numeric value" {
    run get_cpu_usage
    [ "$status" -eq 0 ]
    # Should return a number (may include decimal)
    [[ "$output" =~ ^[0-9]+\.?[0-9]*$ ]]
}

@test "get_memory_usage returns memory usage information" {
    run get_memory_usage
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain memory statistics
    [[ "$output" == *"%"* ]] || [[ "$output" =~ [0-9] ]]
}

@test "get_disk_usage returns disk usage for root" {
    run get_disk_usage "/"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain percentage or numeric value
    [[ "$output" =~ [0-9] ]]
}

@test "get_disk_usage fails for non-existent path" {
    run get_disk_usage "/non/existent/path/12345"
    [ "$status" -eq 1 ]
}

@test "get_system_load returns load average" {
    run get_system_load
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Load should contain numbers
    [[ "$output" =~ [0-9] ]]
}

@test "get_uptime returns uptime information" {
    run get_uptime
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain time information
    [[ "$output" =~ [0-9] ]]
}

@test "check_system_health performs health check" {
    run check_system_health
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain health status information
    [[ "$output" == *"CPU"* ]] || [[ "$output" == *"Memory"* ]] || [[ "$output" == *"Disk"* ]]
}

#===============================================================================
# PROCESS MANAGEMENT TESTS  
#===============================================================================

@test "get_process_info gets info for current shell" {
    # Use current shell PID
    run get_process_info "$$"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain process information
    [[ "$output" =~ [0-9] ]]
}

@test "get_process_info fails for non-existent PID" {
    run get_process_info "999999"
    [ "$status" -eq 1 ]
}

@test "kill_process_tree requires PID argument" {
    run kill_process_tree
    [ "$status" -eq 1 ]
}

@test "kill_process_tree fails for non-existent PID" {
    run kill_process_tree "999999"
    [ "$status" -eq 1 ]
}

@test "start_service requires service name" {
    run start_service
    [ "$status" -eq 1 ]
}

@test "stop_service requires service name" {
    run stop_service
    [ "$status" -eq 1 ]
}

@test "restart_service requires service name" {
    run restart_service
    [ "$status" -eq 1 ]
}

@test "get_service_status requires service name" {
    run get_service_status
    [ "$status" -eq 1 ]
}

@test "get_service_status handles non-existent service" {
    run get_service_status "non-existent-service-12345"
    [ "$status" -eq 1 ]
}

#===============================================================================
# RESOURCE MONITORING TESTS
#===============================================================================

@test "monitor_system runs for short duration" {
    # Monitor for 1 second only (max_count=1 makes it finite; no external timeout needed)
    run monitor_system "1" "1"
    [ "$status" -eq 0 ]
}

@test "get_top_processes returns process list" {
    run get_top_processes "5"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain process information
    [[ "$output" =~ PID ]] || [[ "$output" =~ [0-9] ]]
}

@test "get_top_processes uses default count when no argument given" {
    run get_top_processes
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "check_resource_limits checks system limits" {
    run check_resource_limits
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain limit information
    [[ "$output" == *"limit"* ]] || [[ "$output" =~ [0-9] ]]
}

#===============================================================================
# ERROR HANDLING TESTS
#===============================================================================

@test "system functions handle missing tools gracefully" {
    # These functions should handle missing system tools gracefully
    # and either succeed with available alternatives or fail cleanly
    
    # Test functions that might use various system tools
    run get_cpu_info
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
    
    run get_memory_info  
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
    
    run detect_virtualization
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "system monitoring functions handle invalid arguments" {
    # Test with invalid numeric arguments
    run get_top_processes "invalid"
    [ "$status" -eq 1 ]
    
    # Test monitor_system with invalid arguments 
    run monitor_system "invalid" "1"
    [ "$status" -eq 1 ]
}

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "system info functions work together" {
    # Test that multiple system info functions can be called together
    os_name=$(get_os_name)
    os_version=$(get_os_version)
    arch=$(get_architecture)
    
    [ -n "$os_name" ]
    [ -n "$os_version" ]
    [ -n "$arch" ]
}