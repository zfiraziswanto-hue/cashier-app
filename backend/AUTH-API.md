# 🔐 Auth API Documentation

## Overview

Complete authentication endpoints dengan:
- User registration (role: user only)
- Login with rate limiting (5 attempts per 5 min)
- Logout dengan session tracking
- Change password
- Admin reset password
- Activity logging

## Base URL

```
http://localhost:4000/api/v1
```

## Endpoints

### 1. POST /auth/register

Register new user account. Role always set to "user" (cannot be changed by client).

**Request**
```json
{
  "email": "user@example.com",
  "password": "Password123",
  "nama": "John Doe"
}
```

**Validation**
- `email`: Valid email format
- `password`: Minimum 8 characters
- `nama`: Not empty, max 255 characters

**Response (201 Created)**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "role": "user",
    "nama": "John Doe"
  }
}
```

**Error Cases**
- 400: Email already exists
- 400: Password too short
- 400: Invalid email format
- 500: Server error

---

### 2. POST /auth/login

Login with email and password. Returns JWT token.

**Rate Limiting**: 5 attempts per 5 minutes per IP+email combination
- 6th attempt in 5 min → 429 Too Many Requests

**Request**
```json
{
  "email": "user@example.com",
  "password": "Password123"
}
```

**Response (200 OK)**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "role": "user|kasir|admin",
      "nama": "John Doe"
    }
  }
}
```

**Error Cases**
- 401: Email or password incorrect (generic message)
- 403: Account inactive
- 429: Too many login attempts
- 400: Invalid email format

**Side Effects**
- For kasir role: Creates entry in `cashier_sessions` table
- Activity log: Logs LOGIN action with IP address

---

### 3. POST /auth/logout

Logout current user and end session.

**Headers Required**
```
Authorization: Bearer {access_token}
```

**Response (200 OK)**
```json
{
  "success": true,
  "data": {
    "message": "Logout berhasil"
  }
}
```

**Side Effects**
- For kasir role: Updates `cashier_sessions` with logout_at timestamp
- Activity log: Logs LOGOUT action

---

### 4. PATCH /auth/password

Change password for authenticated user.

**Headers Required**
```
Authorization: Bearer {access_token}
```

**Request**
```json
{
  "old_password": "OldPassword123",
  "new_password": "NewPassword123"
}
```

**Validation**
- `old_password`: Must be correct (verified against auth system)
- `new_password`: Minimum 8 characters

**Response (200 OK)**
```json
{
  "success": true,
  "data": {
    "message": "Password berhasil diubah"
  }
}
```

**Error Cases**
- 401: Old password incorrect
- 400: New password too short
- 401: Unauthorized (no token)
- 500: Server error

**Side Effects**
- Activity log: Logs CHANGE_PASSWORD action

---

### 5. POST /auth/admin/reset-password/:userId

Reset password for any user (admin only).

**Requirements**
- Admin role only
- Valid UUID in path

**Headers Required**
```
Authorization: Bearer {admin_token}
```

**Path Parameters**
```
:userId - UUID of user to reset password for
```

**Response (200 OK)**
```json
{
  "success": true,
  "data": {
    "temp_password": "ABC123XYZ456"
  }
}
```

**Error Cases**
- 401: Unauthorized (no token)
- 403: Forbidden (not admin)
- 404: User not found
- 500: Server error

**Side Effects**
- Activity log: Logs ADMIN_RESET_PASSWORD action with target email
- User must change password on next login

---

## Authentication

All protected endpoints require JWT token in Authorization header:

```bash
Authorization: Bearer {access_token}
```

Token validation includes:
- Signature verification
- Expiry check
- User active status check

---

## Error Response Format

**Generic Error**
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message in Indonesian"
  }
}
```

**Validation Error**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": [
      {
        "path": "password",
        "message": "Password minimal 8 karakter"
      }
    ]
  }
}
```

---

## Important Notes

### Security

1. **Password Length**: Minimum 8 characters enforced
2. **Generic Login Error**: "Email atau password salah" for both email not found and wrong password
3. **Rate Limiting**: 5 failed attempts per 5 minutes per IP+email
4. **Token Expiry**: Handled by Supabase (typically 1 hour)
5. **Activity Logging**: All auth actions logged with IP address

### Role Assignment

- Registration: Always sets role to "user"
- Client cannot specify role in request
- Role can only be changed by admin via database

### Cascading Actions

**Login (Kasir)**
- Creates cashier_sessions entry
- Logs activity

**Logout**
- Closes cashier_sessions (if kasir)
- Logs activity

**Password Change**
- Logs activity

**Admin Reset**
- Generates temporary password
- Logs activity with admin ID and target user email

---

## Test Scenarios

### Scenario 1: Complete Flow
```
1. Register user
2. Login with credentials
3. Access protected endpoint
4. Change password
5. Login with new password
6. Logout
```

### Scenario 2: Rate Limiting
```
1. Attempt login with wrong password 5 times (fails)
2. 6th attempt returns 429 Too Many Requests
3. Wait 5 minutes
4. Login succeeds
```

### Scenario 3: Admin Reset
```
1. Admin logs in
2. Admin resets user password
3. Temporary password returned
4. User logs in with temp password
5. User changes password
```

### Scenario 4: Authorization Check
```
1. User logs in (non-admin)
2. Attempt POST /auth/admin/reset-password
3. Returns 403 Forbidden
```

---

## Testing

### Using curl

See `test-auth.sh` for comprehensive test suite

### Using REST Client

Open `test-auth.http` with VSCode REST Client extension

### Manual Testing with curl

```bash
# Register
curl -X POST http://localhost:4000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Pass1234","nama":"Test"}'

# Login
curl -X POST http://localhost:4000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Pass1234"}'

# Use token to access protected endpoint
curl -X GET http://localhost:4000/api/v1/products \
  -H "Authorization: Bearer YOUR_TOKEN"

# Change password
curl -X PATCH http://localhost:4000/api/v1/auth/password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"old_password":"Pass1234","new_password":"NewPass1234"}'

# Logout
curl -X POST http://localhost:4000/api/v1/auth/logout \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

Generated: 2026-11-09
Version: 1.0
