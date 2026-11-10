# Backend Quick Start

## Setup

```bash
cd backend
npm install
```

## Development

```bash
# Start server dengan hot-reload
npm run dev

# In another terminal, test endpoints
curl http://localhost:4000/api/v1/health
```

## Building

```bash
# Compile TypeScript
npm run build

# Run compiled version
npm start
```

## Project Structure

```
src/
├── middleware/      # Request processing (auth, validation, logging, errors)
├── routes/          # API endpoints
├── controllers/     # Route handlers (use asyncHandler)
├── services/        # Business logic (throw AppError)
├── schemas/         # Zod validation schemas
├── jobs/            # Cron jobs (auto-cancel orders)
└── utils/           # Helpers (AppError, asyncHandler, validateEnv)
```

## Adding New Endpoints

### 1. Create Schema (src/schemas/feature.ts)
```typescript
import { z } from 'zod';

export const createFeatureSchema = z.object({
  name: z.string().min(1)
});
```

### 2. Create Service (src/services/featureService.ts)
```typescript
import { AppError } from '../utils/AppError';

export class FeatureService {
  static async create(data: any) {
    // throw AppError for errors
    // return data on success
  }
}
```

### 3. Create Controller (src/controllers/featureController.ts)
```typescript
import { asyncHandler } from '../utils/asyncHandler';

export class FeatureController {
  static create = asyncHandler(async (req, res) => {
    const data = await FeatureService.create(req.body);
    res.status(201).json({ success: true, data });
  });
}
```

### 4. Create Routes (src/routes/featureRoutes.ts)
```typescript
import { Router } from 'express';
import { validate } from '../middleware/validate';
import { createFeatureSchema } from '../schemas/feature';

const router = Router();

router.post(
  '/',
  authenticate,
  validate({ body: createFeatureSchema }),
  FeatureController.create
);

export default router;
```

### 5. Register Routes (src/index.ts)
```typescript
import featureRoutes from './routes/featureRoutes';
app.use('/api/v1/features', featureRoutes);
```

## Error Handling

### AppError Usage
```typescript
// In services
throw new AppError('CODE', 'Message', 400);

// Available codes: VALIDATION_ERROR, NOT_FOUND, FORBIDDEN, etc.
```

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message"
  }
}
```

## Validation

Zod schemas validate automatically at middleware level before controller.

```typescript
// Schema
const schema = z.object({
  email: z.string().email(),
  age: z.number().positive()
});

// Route
router.post('/', validate({ body: schema }), controller);

// Invalid request returns 400 with validation details
```

## Environment Variables

Create `.env` file:
```
PORT=4000
NODE_ENV=development
FRONTEND_URL=http://localhost:3000
SUPABASE_URL=your-url
SUPABASE_SERVICE_ROLE_KEY=your-key
AUTO_CANCEL_ORDERS_ENABLED=true
```

## Logging

Request logger automatically logs:
- Method, path, status, duration
- Masks passwords and tokens
- User ID if authenticated

## Rate Limiting

- Global: 100 requests / 15 minutes
- Login: 5 attempts / 5 minutes per IP+email

## Testing

```bash
# Lint
npm run lint

# Type check
npm run typecheck
```

---

For detailed info, see FOUNDATION.md
