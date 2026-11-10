#!/bin/bash

# Transaction API Test Suite
# Test workflow: create transaction → list → get detail → get receipt → void request
# Base URL
BASE_URL="http://localhost:4000/api/v1"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}          🧾 TRANSACTION API TEST SUITE${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}\n"

# Step 1: Login as kasir1 to get token
echo -e "${YELLOW}SETUP: Login as Kasir${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "kasir1@osis.local",
    "password": "kasir123"
  }')

KASIR_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"access_token":"[^"]*' | head -1 | cut -d'"' -f4)
KASIR_ID=$(echo $LOGIN_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo -e "${GREEN}✓ Kasir logged in: ${KASIR_ID:0:8}...${NC}\n"

# Step 2: Login as admin
echo -e "${YELLOW}SETUP: Login as Admin${NC}"
ADMIN_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@osis.local",
    "password": "admin123"
  }')

ADMIN_TOKEN=$(echo $ADMIN_LOGIN | grep -o '"access_token":"[^"]*' | head -1 | cut -d'"' -f4)
echo -e "${GREEN}✓ Admin logged in${NC}\n"

# TEST 1: Create transaction with tunai payment
echo -e "${YELLOW}TEST 1: Create Transaction (Tunai - Success)${NC}"
CREATE_TXN=$(curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{
    "items": [
      {"product_id": 1, "qty": 2},
      {"product_id": 2, "qty": 1}
    ],
    "metode_bayar": "tunai",
    "uang_diterima": 50000
  }')

echo "Response: $(echo $CREATE_TXN | head -c 150)..."
TXN_ID=$(echo $CREATE_TXN | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
TXN_NUMBER=$(echo $CREATE_TXN | grep -o '"nomor_transaksi":"[^"]*' | head -1 | cut -d'"' -f4)

if echo $CREATE_TXN | grep -q "nomor_transaksi"; then
  echo -e "${GREEN}✓ Transaction created: $TXN_NUMBER (ID: $TXN_ID)${NC}\n"
else
  echo -e "${RED}✗ Failed to create transaction${NC}\n"
fi

# TEST 2: Create transaction with insufficient stock (should fail)
echo -e "${YELLOW}TEST 2: Create Transaction (Insufficient Stock - Should Fail)${NC}"
FAIL_TXN=$(curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{
    "items": [
      {"product_id": 1, "qty": 999}
    ],
    "metode_bayar": "tunai",
    "uang_diterima": 9999999
  }')

echo "Response: $FAIL_TXN"
if echo $FAIL_TXN | grep -q "INSUFFICIENT_STOCK\|stok.*tidak cukup"; then
  echo -e "${GREEN}✓ Correctly rejected: Stock error${NC}\n"
else
  echo -e "${RED}✗ Should have rejected for insufficient stock${NC}\n"
fi

# TEST 3: Create transaction with non-tunai (uang_diterima must equal total)
echo -e "${YELLOW}TEST 3: Create Transaction (QRIS - Mismatch Payment)${NC}"
QRIS_TXN=$(curl -s -X POST "$BASE_URL/transactions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KASIR_TOKEN" \
  -d '{
    "items": [
      {"product_id": 1, "qty": 1}
    ],
    "metode_bayar": "qris",
    "uang_diterima": 5000
  }')

echo "Response: $QRIS_TXN"
if echo $QRIS_TXN | grep -q "INVALID_PAYMENT\|uang_diterima"; then
  echo -e "${GREEN}✓ Correctly rejected: Payment mismatch${NC}\n"
else
  echo -e "${RED}✗ Should validate payment amount${NC}\n"
fi

# TEST 4: List transactions - Kasir only sees own
echo -e "${YELLOW}TEST 4: List Transactions (Kasir - Own Only)${NC}"
LIST_TXN=$(curl -s -X GET "$BASE_URL/transactions?page=1&limit=10" \
  -H "Authorization: Bearer $KASIR_TOKEN")

echo "Response: $(echo $LIST_TXN | head -c 150)..."
if echo $LIST_TXN | grep -q "pagination"; then
  echo -e "${GREEN}✓ List retrieved with pagination${NC}\n"
else
  echo -e "${RED}✗ Failed to list transactions${NC}\n"
fi

# TEST 5: Get transaction detail
echo -e "${YELLOW}TEST 5: Get Transaction Detail${NC}"
if [ ! -z "$TXN_ID" ]; then
  DETAIL=$(curl -s -X GET "$BASE_URL/transactions/$TXN_ID" \
    -H "Authorization: Bearer $KASIR_TOKEN")
  
  echo "Response: $(echo $DETAIL | head -c 150)..."
  if echo $DETAIL | grep -q "nomor_transaksi"; then
    echo -e "${GREEN}✓ Transaction detail retrieved${NC}\n"
  else
    echo -e "${RED}✗ Failed to get transaction detail${NC}\n"
  fi
fi

# TEST 6: Get receipt (58mm)
echo -e "${YELLOW}TEST 6: Get Receipt (58mm Format)${NC}"
if [ ! -z "$TXN_ID" ]; then
  RECEIPT_58=$(curl -s -X GET "$BASE_URL/transactions/$TXN_ID/receipt?paperSize=58mm" \
    -H "Authorization: Bearer $KASIR_TOKEN")
  
  if echo $RECEIPT_58 | grep -q "<!DOCTYPE html>\|nama_toko"; then
    echo -e "${GREEN}✓ Receipt HTML generated (58mm)${NC}\n"
  else
    echo -e "${RED}✗ Failed to generate receipt${NC}\n"
  fi
fi

# TEST 7: Get receipt (80mm)
echo -e "${YELLOW}TEST 7: Get Receipt (80mm Format)${NC}"
if [ ! -z "$TXN_ID" ]; then
  RECEIPT_80=$(curl -s -X GET "$BASE_URL/transactions/$TXN_ID/receipt?paperSize=80mm" \
    -H "Authorization: Bearer $KASIR_TOKEN")
  
  if echo $RECEIPT_80 | grep -q "<!DOCTYPE html>\|nomor_transaksi"; then
    echo -e "${GREEN}✓ Receipt HTML generated (80mm)${NC}\n"
  else
    echo -e "${RED}✗ Failed to generate receipt (80mm)${NC}\n"
  fi
fi

# TEST 8: Create void request
echo -e "${YELLOW}TEST 8: Create Void Request${NC}"
if [ ! -z "$TXN_ID" ]; then
  VOID_REQ=$(curl -s -X POST "$BASE_URL/transactions/$TXN_ID/void-request" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KASIR_TOKEN" \
    -d '{"alasan": "Kesalahan input"}')
  
  echo "Response: $VOID_REQ"
  if echo $VOID_REQ | grep -q "status.*menunggu"; then
    echo -e "${GREEN}✓ Void request created${NC}\n"
  else
    echo -e "${RED}✗ Failed to create void request${NC}\n"
  fi
fi

# TEST 9: Authorization - Kasir cannot see other kasir's transaction
echo -e "${YELLOW}TEST 9: Authorization (Kasir - Cannot See Other Kasir)${NC}"
if [ ! -z "$TXN_ID" ]; then
  # Login as kasir2
  KASIR2_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "kasir2@osis.local",
      "password": "kasir123"
    }')
  
  KASIR2_TOKEN=$(echo $KASIR2_LOGIN | grep -o '"access_token":"[^"]*' | head -1 | cut -d'"' -f4)
  
  # Try to access kasir1's transaction
  AUTH_TEST=$(curl -s -X GET "$BASE_URL/transactions/$TXN_ID" \
    -H "Authorization: Bearer $KASIR2_TOKEN")
  
  echo "Response: $AUTH_TEST"
  if echo $AUTH_TEST | grep -q "FORBIDDEN\|tidak bisa mengakses"; then
    echo -e "${GREEN}✓ Correctly blocked: 403 Forbidden${NC}\n"
  else
    echo -e "${RED}✗ Authorization check failed${NC}\n"
  fi
fi

# TEST 10: Admin can see all transactions
echo -e "${YELLOW}TEST 10: Authorization (Admin - Can See All)${NC}"
ADMIN_LIST=$(curl -s -X GET "$BASE_URL/transactions?page=1&limit=10" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

echo "Response: $(echo $ADMIN_LIST | head -c 150)..."
if echo $ADMIN_LIST | grep -q "pagination"; then
  echo -e "${GREEN}✓ Admin can list all transactions${NC}\n"
else
  echo -e "${RED}✗ Admin listing failed${NC}\n"
fi

# TEST 11: Validation - Missing alasan in void request
echo -e "${YELLOW}TEST 11: Validation (Missing Alasan in Void)${NC}"
if [ ! -z "$TXN_ID" ]; then
  BAD_VOID=$(curl -s -X POST "$BASE_URL/transactions/$TXN_ID/void-request" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KASIR_TOKEN" \
    -d '{}')
  
  echo "Response: $BAD_VOID"
  if echo $BAD_VOID | grep -q "MISSING_REASON\|alasan"; then
    echo -e "${GREEN}✓ Correctly rejected: Missing alasan${NC}\n"
  else
    echo -e "${RED}✗ Should validate alasan field${NC}\n"
  fi
fi

# TEST 12: Invalid paper size
echo -e "${YELLOW}TEST 12: Validation (Invalid Paper Size)${NC}"
if [ ! -z "$TXN_ID" ]; then
  BAD_SIZE=$(curl -s -X GET "$BASE_URL/transactions/$TXN_ID/receipt?paperSize=A4" \
    -H "Authorization: Bearer $KASIR_TOKEN")
  
  echo "Response: $BAD_SIZE"
  if echo $BAD_SIZE | grep -q "INVALID_SIZE\|58mm\|80mm"; then
    echo -e "${GREEN}✓ Correctly rejected: Invalid size${NC}\n"
  else
    echo -e "${RED}✗ Should validate paper size${NC}\n"
  fi
fi

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ TEST SUITE COMPLETE${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}\n"
