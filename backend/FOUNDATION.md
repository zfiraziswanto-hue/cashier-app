# Backend Foundation - Setup Complete ✓

## Status
- ✅ Server berjalan di port 4000
- ✅ Environment validation (fail-fast jika var wajib kosong)
- ✅ Middleware lengkap: error handler, validation, logging, rate limiting
- ✅ Scheduler auto-cancel orders (runs every 5 minutes)
- ✅ Product endpoint tervalidasi dengan Zod schemas
- ✅ Error handling seragam tanpa stack trace di production

## Struktur Folder

```
src/
├── index.ts                 # Main app entry point
├── middleware/
│   ├── auth.ts             # Authentication & authorization
│   ├── errorHandler.ts     # Seragam error response format
│   ├── validate.ts         # Zod schema validation
│   ├── requestLogger.ts    # HTTP request logging (no password/token)
│   └── loginRateLimiter.ts # Login rate limit (5x per 5 min)
├── routes/
│   └── productRoutes.ts    # Product endpoints (validated)
├── controllers/
│   └── productController.ts # Product logic (asyncHandler)
├── services/
│   └── productService.ts   # Database queries (AppError)
├── schemas/
│   ├── product.ts          # ✓ Product validation schemas
│   ├── auth.ts             # Placeholder for auth
│   ├── transaction.ts      # Placeholder for transactions
│   ├── order.ts            # Placeholder for orders
│   ├── report.ts           # Placeholder for reports
│   ├── admin.ts            # Placeholder for admin
│   └── category.ts         # Placeholder for categories
├── jobs/
│   └── autoCancelOrders.ts # Cron job (node-cron)
└── utils/
    ├── AppError.ts         # Custom error class
    ├── asyncHandler.ts     # Async middleware wrapper
    └── validateEnv.ts      # Environment validation
```

## Middleware Execution Order

1. Helmet (security headers)
2. CORS
3. Express.json()
4. Global rate limiter (100 req/15 min)
5. Request logger (masking passwords/tokens)
6. Routes
7. 404 handler
8. Error handler (last)

## Error Response Format

### Success Response
```json
{
  "success": true,
  "data": {...},
  "warning": "optional warning message"
}
```

### Error Response (400 - Validation)
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": [
      {
        "path": "field.name",
        "message": "Validation error message"
      }
    ]
  }
}
```

### Error Response (500 - Server Error)
```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "Internal server error"
  }
}
```

## Dependencies Installed

- ✅ `zod` - Schema validation
- ✅ `node-cron` - Scheduled jobs
- ✅ `pdfkit` - PDF generation (for future use)
- ✅ `exceljs` - Excel export (for future use)
- ✅ Existing: express, helmet, cors, pino

## Environment Variables

**Required:**
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key

**Optional:**
- `PORT` - Server port (default: 4000)
- `NODE_ENV` - Environment (development/production)
- `FRONTEND_URL` - Frontend CORS origin (default: http://localhost:3000)
- `AUTO_CANCEL_ORDERS_ENABLED` - Enable auto-cancel job (default: true)

## Starting Development

```bash
npm run dev    # Start with ts-node-dev (hot reload)
npm run build  # Compile TypeScript
npm start      # Run compiled JS
npm run lint   # Check ESLint
```

## Testing Endpoints

### Health Check
```bash
curl http://localhost:4000/api/v1/health
```

### Get Products (requires auth)
```bash
curl -H "Authorization: Bearer <token>" \
  http://localhost:4000/api/v1/products
```

### Create Product (invalid - should return 400)
```bash
curl -X POST http://localhost:4000/api/v1/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"invalid": "data"}'
```

## Next Steps

1. **Auth endpoints** - POST /auth/login, register, logout (Prompt 2)
2. **Transaction endpoints** - POST /transactions, GET /transactions (Prompt 3)
3. **Order endpoints** - POST /orders, confirm payment (Prompt 4)
4. **Report endpoints** - GET /reports/profit, daily (Prompt 5)
5. **Admin endpoints** - Cashier CRUD, sessions log (Prompt 6)

## Notes

- All controllers use `asyncHandler` to avoid try-catch boilerplate
- All services throw `AppError` for consistent error handling
- Product schema already integrated and working
- Validation happens at middleware level before controller
- Login rate limiter tracks per IP+email combination
- Auto-cancel scheduler disabled in development via env var
- Stack trace only shown in development mode

---

Last updated: 2026-11-09
