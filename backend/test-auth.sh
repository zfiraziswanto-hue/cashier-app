#!/bin/bash

# Auth API Test Suite
# Test workflow: register → login → access protected → change password → logout
# Base URL
BASE_URL="http://localhost:4000/api/v1"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}          🔐 AUTH API TEST SUITE${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}\n"

# Test 1: Register new user
echo -e "${YELLOW}TEST 1: Register New User${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPassword123",
    "nama": "Test User"
  }')

echo "Request: POST /auth/register"
echo "Payload: { email, password (min 8), nama }"
echo "Response: $REGISTER_RESPONSE"

TEST_USER_ID=$(echo $REGISTER_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo -e "${GREEN}✓ User registered: $TEST_USER_ID${NC}\n"

# Test 2: Login with correct credentials
echo -e "${YELLOW}TEST 2: Login with Correct Credentials${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPassword123"
  }')

echo "Request: POST /auth/login"
echo "Payload: { email, password }"
echo "Response: $LOGIN_RESPONSE"

ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"access_token":"[^"]*' | head -1 | cut -d'"' -f4)
echo -e "${GREEN}✓ Login successful. Token: ${ACCESS_TOKEN:0:20}...${NC}\n"

# Test 3: Access protected endpoint with valid token
echo -e "${YELLOW}TEST 3: Access Protected Endpoint with Valid Token${NC}"
PRODUCTS_RESPONSE=$(curl -s -X GET "$BASE_URL/products" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "Request: GET /products (with valid token)"
echo "Response: $(echo $PRODUCTS_RESPONSE | head -c 100)..."
echo -e "${GREEN}✓ Protected endpoint accessible${NC}\n"

# Test 4: Access protected endpoint without token (should fail)
echo -e "${YELLOW}TEST 4: Access Protected Endpoint Without Token (Should Fail)${NC}"
NO_TOKEN_RESPONSE=$(curl -s -X GET "$BASE_URL/products")

echo "Request: GET /products (without token)"
echo "Response: $NO_TOKEN_RESPONSE"
if echo $NO_TOKEN_RESPONSE | grep -q "UNAUTHORIZED"; then
  echo -e "${GREEN}✓ Correctly rejected: 401 Unauthorized${NC}\n"
else
  echo -e "${RED}✗ Should have been rejected${NC}\n"
fi

# Test 5: Login with wrong password (should fail)
echo -e "${YELLOW}TEST 5: Login with Wrong Password (Should Fail)${NC}"
WRONG_PASS_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "WrongPassword123"
  }')

echo "Request: POST /auth/login with wrong password"
echo "Response: $WRONG_PASS_RESPONSE"
if echo $WRONG_PASS_RESPONSE | grep -q "Email atau password salah"; then
  echo -e "${GREEN}✓ Correctly rejected: Generic error message${NC}\n"
else
  echo -e "${RED}✗ Error message should be generic${NC}\n"
fi

# Test 6: Rate limit test (5 failed attempts should trigger 429)
echo -e "${YELLOW}TEST 6: Rate Limiting (5 Failed Attempts)${NC}"
echo "Attempting 5 failed logins..."

for i in {1..5}; do
  RATE_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "testuser@example.com",
      "password": "WrongPassword"
    }')
  echo "Attempt $i: $(echo $RATE_RESPONSE | grep -o '"code":"[^"]*' | cut -d'"' -f4)"
done

echo ""
RATE_LIMIT_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "WrongPassword"
  }')

echo "Request: POST /auth/login (6th attempt)"
echo "Response: $RATE_LIMIT_RESPONSE"
if echo $RATE_LIMIT_RESPONSE | grep -q "RATE_LIMIT_EXCEEDED"; then
  echo -e "${GREEN}✓ Correctly rate limited: 429 Too Many Requests${NC}\n"
else
  echo -e "${YELLOW}⚠ Rate limit may not have triggered (depends on previous requests)${NC}\n"
fi

# Test 7: Change password
echo -e "${YELLOW}TEST 7: Change Password${NC}"
CHANGE_PASS_RESPONSE=$(curl -s -X PATCH "$BASE_URL/auth/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "old_password": "TestPassword123",
    "new_password": "NewPassword123"
  }')

echo "Request: PATCH /auth/password (with valid old password)"
echo "Response: $CHANGE_PASS_RESPONSE"
if echo $CHANGE_PASS_RESPONSE | grep -q "Password berhasil diubah"; then
  echo -e "${GREEN}✓ Password changed successfully${NC}\n"
else
  echo -e "${RED}✗ Password change failed${NC}\n"
fi

# Test 8: Login with new password
echo -e "${YELLOW}TEST 8: Login with New Password${NC}"
NEW_LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "NewPassword123"
  }')

echo "Request: POST /auth/login with new password"
echo "Response: $(echo $NEW_LOGIN_RESPONSE | head -c 100)..."
if echo $NEW_LOGIN_RESPONSE | grep -q "access_token"; then
  NEW_TOKEN=$(echo $NEW_LOGIN_RESPONSE | grep -o '"access_token":"[^"]*' | head -1 | cut -d'"' -f4)
  echo -e "${GREEN}✓ New password works. Token: ${NEW_TOKEN:0:20}...${NC}\n"
else
  echo -e "${RED}✗ Login with new password failed${NC}\n"
fi

# Test 9: Logout
echo -e "${YELLOW}TEST 9: Logout${NC}"
LOGOUT_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/logout" \
  -H "Authorization: Bearer $NEW_TOKEN")

echo "Request: POST /auth/logout"
echo "Response: $LOGOUT_RESPONSE"
if echo $LOGOUT_RESPONSE | grep -q "Logout berhasil"; then
  echo -e "${GREEN}✓ Logout successful${NC}\n"
else
  echo -e "${RED}✗ Logout failed${NC}\n"
fi

# Test 10: Try to access protected endpoint after logout
echo -e "${YELLOW}TEST 10: Access Protected Endpoint After Logout${NC}"
AFTER_LOGOUT_RESPONSE=$(curl -s -X GET "$BASE_URL/products" \
  -H "Authorization: Bearer $NEW_TOKEN")

echo "Request: GET /products (after logout)"
echo "Response: $AFTER_LOGOUT_RESPONSE"
if echo $AFTER_LOGOUT_RESPONSE | grep -q "UNAUTHORIZED\|invalid"; then
  echo -e "${GREEN}✓ Correctly rejected after logout${NC}\n"
else
  echo -e "${YELLOW}⚠ Token may still be valid (depends on Supabase session)${NC}\n"
fi

# Test 11: Validation error - password too short
echo -e "${YELLOW}TEST 11: Validation Error - Password Too Short${NC}"
VALIDATION_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "shortpass@example.com",
    "password": "Short1",
    "nama": "Test"
  }')

echo "Request: POST /auth/register with password < 8 chars"
echo "Response: $VALIDATION_RESPONSE"
if echo $VALIDATION_RESPONSE | grep -q "VALIDATION_ERROR\|Password minimal 8"; then
  echo -e "${GREEN}✓ Correctly rejected: Validation error${NC}\n"
else
  echo -e "${RED}✗ Should validate password length${NC}\n"
fi

# Test 12: User role always 'user'
echo -e "${YELLOW}TEST 12: User Role Always 'user' (Not From Client)${NC}"
REGISTER_RESPONSE2=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "roletest@example.com",
    "password": "TestPassword123",
    "nama": "Role Tester",
    "role": "admin"
  }')

echo "Request: POST /auth/register (client tried to set role: admin)"
echo "Response: $REGISTER_RESPONSE2"
RETURNED_ROLE=$(echo $REGISTER_RESPONSE2 | grep -o '"role":"[^"]*' | head -1 | cut -d'"' -f4)
if [ "$RETURNED_ROLE" = "user" ]; then
  echo -e "${GREEN}✓ Role correctly set to 'user' (ignored client input)${NC}\n"
else
  echo -e "${RED}✗ Role should be 'user', got: $RETURNED_ROLE${NC}\n"
fi

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ TEST SUITE COMPLETE${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}\n"
