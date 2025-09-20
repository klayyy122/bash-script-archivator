#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

echo_test() {
    echo -e "${YELLOW}TEST: $1${NC}"
    ((TEST_COUNT++))
}

echo_pass() {
    echo -e "${GREEN}PASS: $1${NC}"
    ((PASSED_COUNT++))
}

echo_fail() {
    echo -e "${RED}FAIL: $1${NC}"
    ((FAILED_COUNT++))
}

# Тест 1: Проверка использования
echo_test "Testing usage message"
output=$(bash l.sh 2>&1)
if echo "$output" | grep -q "Usage:"; then
    echo_pass "Usage message displayed correctly"
else
    echo_fail "Usage message not displayed"
fi

# Тест 2: Создание тестовой среды
echo_test "Creating test environment"
TEST_DIR=$(mktemp -d)
LOG_DIR="$TEST_DIR/test_logs"
mkdir -p "$LOG_DIR"

# Создаем тестовые файлы с разными датами
for i in {1..5}; do
    touch -d "$i days ago" "$LOG_DIR/file$i.log"
    echo "This is test file $i" > "$LOG_DIR/file$i.log"
done

if [ -d "$LOG_DIR" ] && [ $(ls "$LOG_DIR" | wc -l) -eq 5 ]; then
    echo_pass "Test environment created successfully"
else
    echo_fail "Failed to create test environment"
fi

# Тест 3: Запуск скрипта с малым лимитом
echo_test "Running script with small limit (should trigger archiving)"
original_size=$(du -sm "$LOG_DIR" | cut -f1)
output=$(echo "" | bash l.sh "$LOG_DIR" 1 10 2 2>&1)

# Проверяем, что архив создан
if [ -d "$LOG_DIR/backup" ] && [ $(find "$LOG_DIR/backup" -name "*.tar.gz" | wc -l) -gt 0 ]; then
    echo_pass "Archive created successfully"
else
    echo_fail "Archive not created"
fi

# Проверяем, что файлы удалены
remaining_files=$(find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" | wc -l)
if [ "$remaining_files" -eq 3 ]; then
    echo_pass "Correct number of files removed"
else
    echo_fail "Expected 3 files remaining, found $remaining_files"
fi

# Тест 4: Запуск скрипта с большим лимитом
echo_test "Running script with large limit (should not trigger archiving)"
output=$(bash l.sh "$LOG_DIR" 1000 10 2 2>&1)

if echo "$output" | grep -q "Usage is within limits"; then
    echo_pass "Script correctly identified usage within limits"
else
    echo_fail "Script did not correctly identify usage within limits"
fi

# Тест 5: Проверка обработки несуществующей директории
echo_test "Testing non-existent directory handling"
output=$(echo "/nonexistent" | timeout 5 bash l.sh "/invalid" 10 80 2 2>&1)

if echo "$output" | grep -q "ENTER CORRECT PATH"; then
    echo_pass "Script correctly prompted for correct path"
else
    echo_fail "Script did not handle non-existent directory correctly"
fi

# Очистка
rm -rf "$TEST_DIR"

# Итоги
echo
echo "=== TEST RESULTS ==="
echo "Total tests: $TEST_COUNT"
echo -e "${GREEN}Passed: $PASSED_COUNT${NC}"
echo -e "${RED}Failed: $FAILED_COUNT${NC}"

if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! ❌${NC}"
    exit 1
fi
