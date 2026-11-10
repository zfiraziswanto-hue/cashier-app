# 🔐 Auth Endpoints - Quick Reference

## Test Accounts (dari database seed)

```
Admin:
  Email: admin@osis.local
  Password: admin123
  Role: admin

Kasir 1:
  Email: kasir1@osis.local
  Password: kasir123
  Role: kasir

Kasir 2:
  Email: kasir2@osis.local
  Password: kasir123
  Role: kasir

User:
  Email: user@osis.local
  Password: user123
  Role: user
```

## Endpoints Quick Summary

| Method | Endpoint | Auth | Rate Limit | Notes |
|--------|----------|------|-----------|-------|
| POST | /auth/register | No | Global | role=user always |
| POST | /auth/login | No | 5/5min | Generic error |
| POST | /auth/logout | Yes | Global | Closes session |
| PATCH | /auth/password | Yes | Global | Verify old pwd |
| POST | /auth/admin/reset-password/:userId | Yes (admin) | Global | Returns temp pwd |

## Quick Test Commands

### Register
```bash
curl -X POST http://localhost:4000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "Password123",
    "nama": "New User"
  }'
```

### Login
```bash
curl -X POST http://localhost:4000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "Password123"
  }'
```

### Access Protected Endpoint
```bash
curl -X GET http://localhost:4000/api/v1/products \
  -H "Authorization: Bearer {access_token}"
```

### Change Password
```bash
curl -X PATCH http://localhost:4000/api/v1/auth/password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {access_token}" \
  -d '{
    "old_password": "Password123",
    "new_password": "NewPassword123"
  }'
```

### Logout
```bash
curl -X POST http://localhost:4000/api/v1/auth/logout \
  -H "Authorization: Bearer {access_token}"
```

### Admin Reset Password
```bash
curl -X POST http://localhost:4000/api/v1/auth/admin/reset-password/00000000-0000-0000-0000-000000000004 \
  -H "Authorization: Bearer {admin_token}"
```

## Testing Workflow

1. **Start Server**
   ```bash
   cd backend
   npm run dev
   ```

2. **Register New User**
   ```bash
   ./test-auth.sh  # or run individual curl commands
   ```

3. **Login & Get Token**
   ```bash
   # Copy access_token from login response
   ```

4. **Test Protected Endpoint**
   ```bash
   # Use token from login
   ```

5. **Test Rate Limiting**
   ```bash
   # Login 6 times with wrong password
   # 6th attempt should return 429
   ```

## File Locations

- **Service**: `backend/src/services/authService.ts`
- **Controller**: `backend/src/controllers/authController.ts`
- **Routes**: `backend/src/routes/authRoutes.ts`
- **Schemas**: `backend/src/schemas/auth.ts`
- **Tests**: `backend/test-auth.sh` or `backend/test-auth.http`
- **Docs**: `backend/AUTH-API.md`

## Key Security Features

✅ **Rate Limiting**: 5 failed attempts per 5 minutes per IP+email
✅ **Password**: Minimum 8 characters
✅ **Error Messages**: Generic for auth (prevents email enumeration)
✅ **Activity Logging**: All actions logged with IP/timestamp
✅ **Session Tracking**: Kasir sessions tracked in database
✅ **Admin-Only**: Reset password endpoint restricted to admin

## Common Issues & Solutions

**Issue**: "Could not find the table 'public.profiles'"
- **Solution**: Apply database migrations first

**Issue**: "Email atau password salah" on valid credentials
- **Solution**: Check if account is active (is_active=true)

**Issue**: 429 on first login attempt
- **Solution**: Rate limiter only tracks failed attempts, not successful ones

**Issue**: Cannot login with test accounts
- **Solution**: Run migrations and seed data, then check if users exist

---

Last Updated: 2026-11-09
