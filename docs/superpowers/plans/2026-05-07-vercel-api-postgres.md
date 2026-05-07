# Vercel API + Postgres Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy the existing meeting-minutes backend on Vercel with Postgres-backed point management and Groq-backed transcription/summarization.

**Architecture:** Keep the Flutter API contract unchanged and adapt `server/src/index.ts` into a Vercel-compatible Express serverless function. Store points and point history in Vercel Postgres/Neon through `DATABASE_URL`; keep audio files temporary and never persist them server-side.

**Tech Stack:** Flutter/Dart client, Node.js/Express backend, TypeScript, Vercel serverless functions, PostgreSQL via `pg`, Groq API, `multer` memory upload handling.

---

## File Structure

- Modify `server/src/index.ts`: export the Express app for Vercel, avoid `app.listen()` on Vercel, use memory uploads, initialize schema with transaction history, and return JSON errors.
- Create `server/api/index.ts`: Vercel function entrypoint that imports the Express app.
- Create `server/vercel.json`: route all API paths to `api/index.ts` and set function limits.
- Modify `server/package.json`: add Vercel build/dev scripts if needed.
- Modify `server/.env.example`: document Vercel env vars.
- Modify Flutter `.env`: set `BACKEND_URL` after Vercel deploy.

## Task 1: Make Express App Vercel-Compatible

**Files:**
- Modify: `server/src/index.ts`
- Create: `server/api/index.ts`
- Create: `server/vercel.json`

- [ ] **Step 1: Write the failing compile check**

Run: `npm run build`

Expected before changes: PASS or FAIL depending on current state. This establishes the baseline before Vercel changes.

- [ ] **Step 2: Replace disk upload and export app**

In `server/src/index.ts`, replace the upload setup and app listen section with Vercel-safe code:

```ts
const upload = multer({ storage: multer.memoryStorage() });

const isVercel = Boolean(process.env.VERCEL);
if (!isVercel) {
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

export default app;
```

Update transcription to use `file.buffer` instead of `fs.createReadStream(file.path)`:

```ts
formData.append('file', file.buffer, {
  filename: file.originalname || 'recording.m4a',
  contentType: file.mimetype || 'audio/m4a',
});
```

Remove all `fs.unlinkSync(file.path)` calls because memory uploads have no temporary disk file.

- [ ] **Step 3: Create Vercel entrypoint**

Create `server/api/index.ts`:

```ts
import app from '../src/index';

export default app;
```

- [ ] **Step 4: Create Vercel routing config**

Create `server/vercel.json`:

```json
{
  "version": 2,
  "builds": [
    {
      "src": "api/index.ts",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "api/index.ts"
    }
  ],
  "functions": {
    "api/index.ts": {
      "maxDuration": 60
    }
  }
}
```

- [ ] **Step 5: Run compile check**

Run: `npm run build`

Expected: TypeScript compile succeeds with no errors.

## Task 2: Add Point Transaction History

**Files:**
- Modify: `server/src/index.ts`

- [ ] **Step 1: Extend schema initialization**

Update `initDb` query to create `point_transactions` and `updated_at`:

```ts
const queryText = `
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    device_id TEXT UNIQUE NOT NULL,
    points INTEGER NOT NULL DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );

  ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
  UPDATE users SET points = 100 WHERE points = 0;

  CREATE TABLE IF NOT EXISTS point_transactions (
    id SERIAL PRIMARY KEY,
    device_id TEXT NOT NULL,
    amount INTEGER NOT NULL,
    type TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
`;
```

- [ ] **Step 2: Record initial user creation transaction**

When inserting a new user in `GET /user/balance/:deviceId`, also insert:

```ts
await pool.query(
  'INSERT INTO point_transactions (device_id, amount, type, reason) VALUES ($1, $2, $3, $4)',
  [deviceId, defaultPoints, 'initial', 'Initial signup balance']
);
```

- [ ] **Step 3: Record reward transactions**

In `POST /user/reward`, validate inputs and update points:

```ts
if (!deviceId || typeof amount !== 'number' || amount <= 0) {
  return res.status(400).json({ error: 'Invalid reward request' });
}

await pool.query(
  'INSERT INTO users (device_id, points) VALUES ($1, 100) ON CONFLICT (device_id) DO NOTHING',
  [deviceId]
);

const result = await pool.query(
  'UPDATE users SET points = points + $1, updated_at = CURRENT_TIMESTAMP WHERE device_id = $2 RETURNING points',
  [amount, deviceId]
);

await pool.query(
  'INSERT INTO point_transactions (device_id, amount, type, reason) VALUES ($1, $2, $3, $4)',
  [deviceId, amount, 'reward', 'Reward or test purchase']
);
```

- [ ] **Step 4: Record summarize consumption transaction**

After successful Groq summary, replace the point deduction with:

```ts
await pool.query(
  'UPDATE users SET points = points - $1, updated_at = CURRENT_TIMESTAMP WHERE device_id = $2',
  [pointCost, deviceId]
);

await pool.query(
  'INSERT INTO point_transactions (device_id, amount, type, reason) VALUES ($1, $2, $3, $4)',
  [deviceId, -pointCost, 'consume', 'AI summary']
);
```

- [ ] **Step 5: Run compile check**

Run: `npm run build`

Expected: TypeScript compile succeeds with no errors.

## Task 3: Harden API Responses

**Files:**
- Modify: `server/src/index.ts`
- Modify: `server/.env.example`

- [ ] **Step 1: Add required environment validation helper**

Near the top of `server/src/index.ts`, add:

```ts
const requireEnv = (name: string): string => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
};
```

Use `requireEnv('GROQ_API_KEY')` inside Groq request handlers and keep `DATABASE_URL` required by `pg` connection setup.

- [ ] **Step 2: Validate transcription request**

In `POST /ai/transcribe`, add:

```ts
if (!deviceId) return res.status(400).json({ error: 'deviceId is required' });
if (!file) return res.status(400).json({ error: 'No file uploaded' });
```

- [ ] **Step 3: Validate summary request**

In `POST /ai/summarize`, add:

```ts
if (!deviceId || !text) {
  return res.status(400).json({ error: 'deviceId and text are required' });
}
```

- [ ] **Step 4: Update env example**

Set `server/.env.example` to:

```env
DATABASE_URL=postgresql://user:password@host:5432/database?sslmode=require
GROQ_API_KEY=your_groq_api_key_here
PORT=3000
```

- [ ] **Step 5: Run compile check**

Run: `npm run build`

Expected: TypeScript compile succeeds with no errors.

## Task 4: Deploy and Configure

**Files:**
- Modify: `.env`

- [ ] **Step 1: Install/use Vercel CLI**

Run from `server/`: `npx vercel --version`

Expected: prints a Vercel CLI version or prompts to install.

- [ ] **Step 2: Link/deploy server**

Run from `server/`: `npx vercel`

Expected: Vercel links the project and returns a preview deployment URL.

- [ ] **Step 3: Add Vercel environment variables**

In Vercel project settings, add:

```text
DATABASE_URL=<Vercel Postgres/Neon connection string>
GROQ_API_KEY=<current Groq API key>
```

- [ ] **Step 4: Deploy production**

Run from `server/`: `npx vercel --prod`

Expected: Vercel returns a production URL like `https://<project>.vercel.app`.

- [ ] **Step 5: Set Flutter backend URL**

Update root `.env`:

```env
BACKEND_URL=https://<project>.vercel.app
```

Keep `GROQ_API_KEY` out of Flutter once Vercel is confirmed, because the app should not ship server secrets.

## Task 5: Verify End-to-End

**Files:**
- Read: `lib/services/backend_service.dart`
- Read: `.env`

- [ ] **Step 1: Verify balance endpoint**

Run:

```bash
curl -i "https://<project>.vercel.app/user/balance/test-device"
```

Expected: `HTTP/2 200` and JSON like `{"points":100}`.

- [ ] **Step 2: Verify reward endpoint**

Run:

```bash
curl -i -X POST "https://<project>.vercel.app/user/reward" \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"test-device","amount":5}'
```

Expected: `HTTP/2 200` and JSON with `points` increased by 5.

- [ ] **Step 3: Run Flutter tests**

Run from project root: `flutter test`

Expected: `All tests passed!`.

- [ ] **Step 4: Run Android app**

Run from project root: `flutter run -d 4XVKYPWOHMONUSFQ --debug`

Expected: app launches on the Android device.

- [ ] **Step 5: Verify recording transcription**

On the Android device, start recording, speak briefly, stop recording.

Expected logs:

```text
RecordingNotifier: 録音ファイルサイズ: <nonzero> bytes
BackendService: transcribe url=https://<project>.vercel.app/ai/transcribe
```

Expected UI result: a new minute is created with transcribed text.

## Self-Review Notes

- Spec coverage: Vercel hosting, Postgres points, Groq proxying, temporary audio handling, and Flutter URL configuration are covered.
- Placeholder scan: deployment URL placeholders are intentionally marked as `<project>` because Vercel generates them at deploy time; every code change includes concrete snippets.
- Type consistency: API paths and JSON keys match `lib/services/backend_service.dart`.
