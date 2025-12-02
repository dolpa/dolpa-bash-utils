#!/usr/bin/env bats

# Test files.sh module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/files.sh"
    
    # Disable colors for consistent testing
    export NO_COLOR=1
    
    # Create temporary directory for tests
    TEST_DIR="$(mktemp -d)"
}

teardown() {
    # Note: Cannot unset readonly variables
    # Clean up test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

@test "files module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/files.sh"
    [ "$status" -eq 0 ]
}

@test "files module sets BASH_UTILS_FILES_LOADED" {
    [ "$BASH_UTILS_FILES_LOADED" = "true" ]
}

@test "create_backup creates backup file" {
    # Create a test file
    test_file="$TEST_DIR/test.txt"
    echo "test content" > "$test_file"
    
    run create_backup "$test_file"
    [ "$status" -eq 0 ]
    
    # Check that backup was created
    backup_files=("$TEST_DIR"/test.txt.backup.*)
    [ -f "${backup_files[0]}" ]
}

@test "create_backup fails for non-existing file" {
    run create_backup "$TEST_DIR/non_existing.txt"
    [ "$status" -eq 1 ]
}

@test "create_backup with custom backup directory" {
    # Create test file and backup directory
    test_file="$TEST_DIR/test.txt"
    backup_dir="$TEST_DIR/backups"
    echo "test content" > "$test_file"
    
    run create_backup "$test_file" "$backup_dir"
    [ "$status" -eq 0 ]
    
    # Check that backup was created in custom directory
    backup_files=("$backup_dir"/test.txt.backup.*)
    [ -f "${backup_files[0]}" ]
}

@test "ensure_directory creates directory" {
    new_dir="$TEST_DIR/new_directory"
    
    run ensure_directory "$new_dir"
    [ "$status" -eq 0 ]
    [ -d "$new_dir" ]
}

@test "ensure_directory succeeds for existing directory" {
    run ensure_directory "$TEST_DIR"
    [ "$status" -eq 0 ]
}

@test "ensure_directory creates nested directories" {
    nested_dir="$TEST_DIR/level1/level2/level3"
    
    run ensure_directory "$nested_dir"
    [ "$status" -eq 0 ]
    [ -d "$nested_dir" ]
}

@test "get_absolute_path returns absolute path for directory" {
    # Change to test directory
    cd "$TEST_DIR"
    
    result=$(get_absolute_path ".")
    [ "$result" = "$TEST_DIR" ]
}

@test "get_absolute_path returns absolute path for file" {
    # Create a test file
    test_file="$TEST_DIR/test.txt"
    echo "test" > "$test_file"
    
    # Change to different directory
    cd "$BATS_TEST_DIRNAME"
    
    result=$(get_absolute_path "$test_file")
    [ "$result" = "$test_file" ]
}

@test "get_absolute_path fails for non-existing path" {
    run get_absolute_path "$TEST_DIR/non_existing"
    [ "$status" -eq 1 ]
}

@test "get_script_dir returns directory of calling script" {
    # This test is tricky since we're in a test environment
    # We'll test that the function exists and returns something
    result=$(get_script_dir)
    [ -n "$result" ]
    [ -d "$result" ]
}

@test "get_script_name returns name of calling script" {
    # This test is tricky since we're in a test environment
    # We'll test that the function exists and returns something reasonable
    result=$(get_script_name)
    [ -n "$result" ]
    # The result should be a filename (contain no path separators at the end)
    [[ "$result" != *"/"* ]] || [[ "$result" == *".bats" ]] || [[ "$result" == "bats" ]]
}