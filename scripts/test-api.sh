#!/usr/bin/env bash

BASE_URL="https://asia-northeast3-woogie-sandbox-gcp.cloudfunctions.net/memoApi"
TEST_FILE="test-memo-$(date +%s)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  local body="$4"

  if [ "$actual" -eq "$expected" ]; then
    echo -e "${GREEN}[PASS]${NC} $label (HTTP $actual)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}[FAIL]${NC} $label — expected HTTP $expected, got HTTP $actual"
    FAIL=$((FAIL + 1))
  fi
  [ -n "$body" ] && echo "       $body"
}

call() {
  local method="$1"
  local path="$2"
  local data="$3"
  local args=(-s -X "$method" -w "\n%{http_code}")

  [ -n "$data" ] && args+=(-H "Content-Type: application/json" -d "$data")

  local response
  response=$(curl "${args[@]}" "$BASE_URL$path")
  local status
  status=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | head -n -1)

  echo "$status|$body"
}

echo ""
echo "=== MemoBox API Test ==="
echo "BASE_URL: $BASE_URL"
echo "TEST_FILE: $TEST_FILE"
echo ""

# ── 정상 시나리오 ────────────────────────────────────────

echo -e "${YELLOW}[ 정상 시나리오 ]${NC}"

# 1. POST / — 메모 생성
result=$(call POST "/" "{\"filename\":\"$TEST_FILE\",\"content\":\"hello memobox\"}")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "POST / — 메모 생성" 201 "$status" "$body"

# 2. GET / — 목록 조회
result=$(call GET "/")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "GET / — 목록 조회" 200 "$status" "$body"

# 3. GET /:filename — 내용 조회
result=$(call GET "/$TEST_FILE")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "GET /$TEST_FILE — 내용 조회" 200 "$status" "$body"

# 4. PUT /:filename — 내용 수정
result=$(call PUT "/$TEST_FILE" "{\"content\":\"updated content\"}")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "PUT /$TEST_FILE — 내용 수정" 200 "$status" "$body"

# 5. GET /:filename — 수정 내용 확인
result=$(call GET "/$TEST_FILE")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "GET /$TEST_FILE — 수정 내용 확인" 200 "$status" "$body"

# 6. DELETE /:filename — 삭제
result=$(call DELETE "/$TEST_FILE")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "DELETE /$TEST_FILE — 삭제" 204 "$status" "$body"

# 7. GET /:filename — 삭제 후 404 확인
result=$(call GET "/$TEST_FILE")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "GET /$TEST_FILE — 삭제 후 404 확인" 404 "$status" "$body"

echo ""

# ── 예외 시나리오 ────────────────────────────────────────

echo -e "${YELLOW}[ 예외 시나리오 ]${NC}"

DUPE_FILE="test-dupe-$(date +%s)"

# 8. POST / — 중복 파일명 409
call POST "/" "{\"filename\":\"$DUPE_FILE\",\"content\":\"first\"}" > /dev/null
result=$(call POST "/" "{\"filename\":\"$DUPE_FILE\",\"content\":\"second\"}")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "POST / — 중복 파일명 → 409" 409 "$status" "$body"

# 정리
call DELETE "/$DUPE_FILE" > /dev/null

# 9. GET — 존재하지 않는 파일 404
result=$(call GET "/nonexistent-file-xyz")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "GET /nonexistent-file-xyz — 존재하지 않는 파일 → 404" 404 "$status" "$body"

# 10. POST / — 잘못된 파일명 패턴 400
result=$(call POST "/" "{\"filename\":\"../bad-file\",\"content\":\"x\"}")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "POST / — 잘못된 파일명 패턴 → 400" 400 "$status" "$body"

# 11. PUT — 존재하지 않는 파일 404
result=$(call PUT "/nonexistent-file-xyz" "{\"content\":\"x\"}")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "PUT /nonexistent-file-xyz — 존재하지 않는 파일 → 404" 404 "$status" "$body"

# 12. DELETE — 존재하지 않는 파일 404
result=$(call DELETE "/nonexistent-file-xyz")
status=$(echo "$result" | cut -d'|' -f1)
body=$(echo "$result" | cut -d'|' -f2-)
check "DELETE /nonexistent-file-xyz — 존재하지 않는 파일 → 404" 404 "$status" "$body"

echo ""

# ── 결과 요약 ────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo "==========================="
echo -e "총 ${TOTAL}개 테스트: ${GREEN}PASS ${PASS}${NC} / ${RED}FAIL ${FAIL}${NC}"
echo "==========================="
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
