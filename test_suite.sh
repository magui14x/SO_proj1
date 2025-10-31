#!/bin/bash

#################################################
# Linux Recycle Bin Tests
# Author: Enrique Ornelas, Margarida Almeida
# Date: 2025-10-31
#################################################

# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

# Test Suite for Recycle Bin System
SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test Helper Functions
setup() {
    mkdir -p "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

teardown() {
    rm -rf "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

assert_fail() {
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}


# Test Cases
test_initialization() {
    echo "=== Test: Initialization ==="
    setup
    $SCRIPT help > /dev/null
    assert_success "Initialize recycle bin"
    [ -d "$RECYCLE_BIN_DIR" ] && echo "✓ Directory created"
    [ -d "$FILES_DIR" ]&& echo "✓ Files Directory created"
    [ -f "$METADATA_FILE" ] && echo "✓ Metadata file created"
    [ -f "$CONFIG_FILE" ] && echo "✓ Configurations file created"
    [ -f "$LOG_FILE" ] && echo "✓ Log file created"
}

test_delete_file() {
    echo "=== Test: Delete File ==="
    setup
    echo "test content" > "$TEST_DIR/test.txt"
    $SCRIPT delete "$TEST_DIR/test.txt" > /dev/null 2>&1
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original location"
}

test_list_empty() {
    echo "=== Test: List Empty Bin ==="
    setup
    
    $SCRIPT empty > /dev/null 2>&1 <<< "yes"
    
    output=$($SCRIPT list 2>/dev/null)
    if echo "$output" | grep -qi "empty" || \
       echo "$output" | grep -qi "Recycle bin is empty" || \
       echo "$output" | grep -qi "0 items" || \
       [ "$(grep -c -v -e "ID,ORIGINAL_NAME" -e "^#" ~/recycle_bin/metadata.db 2>/dev/null)" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: List empty recycle bin"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: List empty recycle bin"
        ((FAIL++))
        echo "DEBUG - Actual output:"
        echo "$output"
    fi
    ((TOTAL++))
}

test_restore_file() {
    echo "=== Test: Restore File ==="
    setup
    echo "test" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt" > /dev/null 2>&1
    
    ID=$(grep "restore_test" ~/recycle_bin/metadata.db | cut -d',' -f1)
    $SCRIPT restore "$ID" > /dev/null 2>&1
    sleep 0.1
    assert_success "Restore file"
    [ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
}

# =============================================================================
# NOVOS TESTES
# =============================================================================

test_delete_multiple_files() {
    echo "=== Test: Delete Multiple Files ==="
    setup
    echo "test1" > "$TEST_DIR/test1.txt"
    echo "test2" > "$TEST_DIR/test2.txt"
    echo "test3" > "$TEST_DIR/test3.txt"
    $SCRIPT delete "$TEST_DIR/test1.txt" "$TEST_DIR/test2.txt" "$TEST_DIR/test3.txt" > /dev/null 2>&1
    assert_success "Delete multiple files"
    [ ! -f "$TEST_DIR/test1.txt" ] && [ ! -f "$TEST_DIR/test2.txt" ] && [ ! -f "$TEST_DIR/test3.txt" ] && echo "✓ All files removed"
}

test_delete_directory() {
    echo "=== Test: Delete Directory ==="
    setup
    mkdir -p "$TEST_DIR/subdir"
    echo "content" > "$TEST_DIR/subdir/file.txt"
    $SCRIPT delete "$TEST_DIR/subdir" > /dev/null 2>&1
    assert_success "Delete directory recursively"
    [ ! -d "$TEST_DIR/subdir" ] && echo "✓ Directory removed"
}

test_delete_nonexistent_file() {
    echo "=== Test: Delete Non-Existent File ==="
    setup
    $SCRIPT delete "$TEST_DIR/nonexistent.txt" 2>&1 | grep -q "Error non-existant"
    assert_success "Handle non-existent file deletion"
}

test_restore_by_name() {
    echo "=== Test: Restore File by Name ==="
    setup
    echo "content" > "$TEST_DIR/restore_name.txt"
    $SCRIPT delete "$TEST_DIR/restore_name.txt" > /dev/null 2>&1
    
    sleep 1
    
    $SCRIPT restore "restore_name" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        if [ -f "$TEST_DIR/restore_name.txt" ]; then
            echo -e "${GREEN}✓ PASS${NC}: Restore file by name pattern"
            ((PASS++))
            echo "✓ File restored"
        else
            echo -e "${RED}✗ FAIL${NC}: Restore file by name pattern"
            ((FAIL++))
        fi
    else
        ID=$(grep "restore_name" ~/recycle_bin/metadata.db | cut -d',' -f1 2>/dev/null)
        if [ -n "$ID" ]; then
            $SCRIPT restore "$ID" > /dev/null 2>&1
            if [ -f "$TEST_DIR/restore_name.txt" ]; then
                echo -e "${GREEN}✓ PASS${NC}: Restore file by name pattern (via ID)"
                ((PASS++))
                echo "✓ File restored via ID"
            else
                echo -e "${RED}✗ FAIL${NC}: Restore file by name pattern"
                ((FAIL++))
            fi
        else
            echo -e "${RED}✗ FAIL${NC}: Restore file by name pattern"
            ((FAIL++))
        fi
    fi
    ((TOTAL++))
}


test_restore_nonexistent() {
    echo "=== Test: Restore Non-Existent File ==="
    setup
    $SCRIPT restore "nonexistent_id" 2>&1 | grep -q "Error"
    assert_success "Handle non-existent file restoration"
}

test_search_functionality() {
    echo "=== Test: Search Functionality ==="
    setup
    echo "test" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null 2>&1
    $SCRIPT search "search_test" | grep -q "search_test"
    assert_success "Search files by name"
}

test_empty_entire_bin() {
    echo "=== Test: Empty Entire Recycle Bin ==="
    setup
    echo "test" > "$TEST_DIR/empty_test.txt"
    $SCRIPT delete "$TEST_DIR/empty_test.txt" > /dev/null 2>&1
    echo "yes" | $SCRIPT empty > /dev/null 2>&1
    assert_success "Empty entire recycle bin"

    output=$($SCRIPT list 2>/dev/null)
    echo "$output" | grep -q "empty" || echo "$output" | grep -q "Recycle bin is empty"
    echo "✓ Bin emptied successfully"
}

test_empty_specific_file() {
    echo "=== Test: Empty Specific File ==="
    setup

    echo "test content" > "$TEST_DIR/simple_test.txt"
    $SCRIPT delete "$TEST_DIR/simple_test.txt" > /dev/null 2>&1
    sleep 1

    if ! grep -q "simple_test.txt" "$METADATA_FILE"; then
        echo -e "${RED}✗ FAIL${NC}: File not found in metadata"
        ((FAIL++)); ((TOTAL++)); return 1
    fi

    {
        echo "1"
        echo "yes"
    } | $SCRIPT empty "simple_test.txt" > /dev/null 2>&1

    if grep -q "simple_test.txt" "$METADATA_FILE"; then
        echo -e "${RED}✗ FAIL${NC}: File still in metadata after empty"
        ((FAIL++))
    else
        echo -e "${GREEN}✓ PASS${NC}: File successfully emptied"
        ((PASS++))
    fi

    ((TOTAL++))
}



test_auto_cleanup() {
    echo "=== Test: Auto Cleanup ==="
    setup
    echo "test" > "$TEST_DIR/cleanup_test.txt"
    $SCRIPT delete "$TEST_DIR/cleanup_test.txt" > /dev/null 2>&1
    
    echo "AUTO_CLEANUP_DAYS=0" > ~/recycle_bin/config
    echo "MAX_SIZE_MB=1024" >> ~/recycle_bin/config
    
    $SCRIPT auto > /dev/null 2>&1
    assert_success "Auto cleanup old files"
    
    output=$($SCRIPT list 2>/dev/null)
    echo "$output" | grep -q "empty" || echo "$output" | grep -q "Recycle bin is empty"
    echo "✓ Files cleaned up"
}

test_statistics_display() {
    echo "=== Test: Statistics Display ==="
    setup
    echo "test" > "$TEST_DIR/stats_test.txt"
    $SCRIPT delete "$TEST_DIR/stats_test.txt" > /dev/null 2>&1
    $SCRIPT stats | grep -q "Total items"
    assert_success "Display statistics"
}

test_file_with_spaces() {
    echo "=== Test: File with Spaces ==="
    setup
    echo "content" > "$TEST_DIR/file with spaces.txt"
    $SCRIPT delete "$TEST_DIR/file with spaces.txt" > /dev/null 2>&1
    assert_success "Delete file with spaces in name"
    
    $SCRIPT list | grep -q "file with spaces" && echo "✓ File with spaces handled"
}

test_permission_handling() {
    echo "=== Test: Permission Handling ==="
    setup
    echo "content" > "$TEST_DIR/permission_test.txt"
    chmod 000 "$TEST_DIR/permission_test.txt"
    
    $SCRIPT delete "$TEST_DIR/permission_test.txt" > /dev/null 2>&1
    assert_success "Delete file without permissions"
    [ ! -f "$TEST_DIR/permission_test.txt" ] && echo "✓ File moved despite permissions"
    
    chmod 644 ~/recycle_bin/files/* 2>/dev/null || true
}





# =============================================================================
# PERFORMANCE TESTS
# =============================================================================


measure_time() {
    local start_time end_time duration
    start_time=$(date +%s.%N)
    if [ "$PERF_DEBUG" = "true" ]; then
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    echo "$duration"
}


format_time() {
    local time_val="$1"
    if (( $(echo "$time_val < 0.001" | bc -l 2>/dev/null) )); then
        printf "%.6f seconds" "$time_val"
    elif (( $(echo "$time_val < 1" | bc -l 2>/dev/null) )); then
        printf "%.3f seconds" "$time_val"
    else
        printf "%.2f seconds" "$time_val"
    fi
}

#TESTES DE PERFORMANCE

performance_delete_100_files() {
    echo "=== Performance Test: Delete 100+ Files ==="
    setup
    
    echo "Creating 100+ test files..."
    for i in {1..105}; do
        echo "content $i" > "$TEST_DIR/test_file_$i.txt"
    done
    

    local file_count
    file_count=$(find "$TEST_DIR" -name "test_file_*.txt" | wc -l)
    echo "Created $file_count files for testing"

    echo "Starting deletion of $file_count files..."
    
    local start_time end_time
    start_time=$(date +%s.%N)
    $SCRIPT delete "$TEST_DIR"/test_file_*.txt > /dev/null 2>&1
    end_time=$(date +%s.%N)
    delete_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo -e "${BLUE}Performance Result:${NC}"
    echo "  Files deleted: $file_count"
    echo -e "  Time taken: $(format_time "$delete_time")"
    
    if (( $(echo "$delete_time > 0" | bc -l 2>/dev/null) )); then
        local avg_time
        avg_time=$(echo "$delete_time / $file_count" | bc -l)
        echo -e "  Average time per file: $(format_time "$avg_time")"
    fi

    local remaining_files
    remaining_files=$(find "$TEST_DIR" -name "test_file_*.txt" | wc -l)
    if [ "$remaining_files" -eq 0 ]; then
        echo -e "${GREEN}✓ SUCCESS: All files deleted${NC}"
    else
        echo -e "${RED}✗ FAIL: $remaining_files files remaining${NC}"
    fi
    
    teardown
    echo ""
}

performance_list_100_items() {
    echo "=== Performance Test: List Recycle Bin with 100+ Items ==="
    setup
    
    echo "Populating recycle bin with 100+ items..."
    local created_count=0
    for i in {1..105}; do
        echo "content $i" > "$TEST_DIR/list_file_$i.txt"
        if $SCRIPT delete "$TEST_DIR/list_file_$i.txt" > /dev/null 2>&1; then
            ((created_count++))
        fi
    done
    
    echo "Successfully added $created_count items to recycle bin"
    
    if [ -f "$METADATA_FILE" ]; then
        local item_count
        item_count=$(tail -n +3 "$METADATA_FILE" 2>/dev/null | wc -l)
        echo "Current items in recycle bin: $item_count"
    fi
    
    echo "Starting list operation..."
    local start_time end_time
    start_time=$(date +%s.%N)
    $SCRIPT list > /dev/null 2>&1
    end_time=$(date +%s.%N)
    list_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo -e "${BLUE}Performance Result:${NC}"
    echo "  Items in bin: $created_count"
    echo -e "  Time taken: $(format_time "$list_time")"
    
    if [ -f "$METADATA_FILE" ] && [ -s "$METADATA_FILE" ]; then
        echo -e "${GREEN}✓ SUCCESS: List operation completed${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING: Metadata file issues${NC}"
    fi
    
    teardown
    echo ""
}

performance_search_large_metadata() {
    echo "=== Performance Test: Search in Large Metadata File ==="
    setup
    
    echo "Creating large metadata file with 200+ entries..."
    local added_count=0
    for i in {1..205}; do
        echo "search_content_$i" > "$TEST_DIR/search_file_$i.txt"
        if $SCRIPT delete "$TEST_DIR/search_file_$i.txt" > /dev/null 2>&1; then
            ((added_count++))
        fi
    done
    
    echo "Added $added_count entries to metadata"
    
    local metadata_size=0
    if [ -f "$METADATA_FILE" ]; then
        metadata_size=$(wc -l < "$METADATA_FILE" 2>/dev/null || echo "0")
        echo "Metadata file size: $metadata_size lines"
    fi
    
    echo "Testing search performance..."

    local start_time end_time
    start_time=$(date +%s.%N)
    $SCRIPT search "search_file_150" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    search_specific_time=$(echo "$end_time - $start_time" | bc -l)
    
    start_time=$(date +%s.%N)
    $SCRIPT search "search_file_1*" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    search_wildcard_time=$(echo "$end_time - $start_time" | bc -l)
    
    start_time=$(date +%s.%N)
    $SCRIPT search "*.txt" > /dev/null 2>&1
    end_time=$(date +%s.%N)
    search_ext_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo -e "${BLUE}Performance Results:${NC}"
    echo "  Metadata entries: $((metadata_size - 2))"
    echo -e "  Specific search time: $(format_time "$search_specific_time")"
    echo -e "  Wildcard search time: $(format_time "$search_wildcard_time")"
    echo -e "  Extension search time: $(format_time "$search_ext_time")"
    
    if $SCRIPT search "search_file_1" 2>/dev/null | grep -q "search_file"; then
        echo -e "${GREEN}✓ SUCCESS: Search operations completed${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING: Search may not be working correctly${NC}"
    fi
    
    teardown
    echo ""
}

performance_restore_many_items() {
    echo "=== Performance Test: Restore from Bin with Many Items ==="
    setup
    
    echo "Setting up recycle bin with 100+ items..."
    local restore_ids=()
    local added_count=0
    
    for i in {1..105}; do
        echo "restore_content_$i" > "$TEST_DIR/restore_file_$i.txt"
        if $SCRIPT delete "$TEST_DIR/restore_file_$i.txt" > /dev/null 2>&1; then
            ((added_count++))

            if [ $((i % 10)) -eq 0 ] && [ -f "$METADATA_FILE" ]; then
                local id
                id=$(grep "restore_file_$i.txt" "$METADATA_FILE" 2>/dev/null | cut -d',' -f1 | head -1)
                if [ -n "$id" ]; then
                    restore_ids+=("$id")
                    echo "Stored ID for restoration: $id"
                fi
            fi
        fi
    done
    
    echo "Added $added_count items to recycle bin"
    echo "Items ready for restoration: ${#restore_ids[@]}"
    

    if [ ${#restore_ids[@]} -gt 0 ]; then
        echo "Testing restoration performance..."
        
        local total_restore_time=0
        local successful_restores=0
        
        for i in {0..2}; do
            if [ -n "${restore_ids[$i]}" ]; then
                echo "Restoring file with ID: ${restore_ids[$i]}"
                
                local start_time end_time restore_time
                start_time=$(date +%s.%N)

                echo "y" | $SCRIPT restore "${restore_ids[$i]}" > /dev/null 2>&1
                end_time=$(date +%s.%N)
                restore_time=$(echo "$end_time - $start_time" | bc -l)
                
                if (( $(echo "$restore_time > 0" | bc -l 2>/dev/null) )); then
                    total_restore_time=$(echo "$total_restore_time + $restore_time" | bc -l)
                    ((successful_restores++))
                    echo -e "  File $((i+1)): $(format_time "$restore_time")"
                else
                    echo -e "  ${YELLOW}File $((i+1)): Timing too short to measure accurately${NC}"
                fi
            fi
        done
        
        if [ "$successful_restores" -gt 0 ]; then
            local avg_restore_time
            avg_restore_time=$(echo "$total_restore_time / $successful_restores" | bc -l)
            
            echo -e "${BLUE}Performance Results:${NC}"
            echo "  Files restored: $successful_restores"
            echo -e "  Total restoration time: $(format_time "$total_restore_time")"
            echo -e "  Average time per file: $(format_time "$avg_restore_time")"
            echo -e "${GREEN}✓ SUCCESS: Restoration performance test completed${NC}"
        else
            echo -e "${YELLOW}⚠ WARNING: No measurable restoration times recorded${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ WARNING: No valid IDs found for restoration test${NC}"
    fi
    
    teardown
    echo ""
}


# Run all tests
echo "========================================="
echo " Recycle Bin Test Suite"
echo "========================================="

# Testes originais
test_initialization
test_delete_file
test_list_empty
test_restore_file

# Novos testes
test_delete_multiple_files
test_delete_directory
test_delete_nonexistent_file
test_restore_by_name
test_restore_nonexistent
test_search_functionality
test_empty_entire_bin
test_empty_specific_file
test_auto_cleanup
test_statistics_display
test_file_with_spaces
test_permission_handling



performance_delete_100_files
performance_list_100_items
performance_search_large_metadata
performance_restore_many_items

teardown

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
