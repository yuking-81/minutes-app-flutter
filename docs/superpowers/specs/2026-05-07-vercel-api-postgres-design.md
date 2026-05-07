# Vercel API + Postgres Migration Design

## Goal

Move the meeting-minutes backend from the current Coolify URL setup to Vercel, while keeping audio files stored only on the device. Vercel will expose the API used by the Flutter app, proxy AI requests to Groq, and store point balances in Vercel Postgres/Neon via `DATABASE_URL`.

## Current Context

The Flutter app calls these backend endpoints through `lib/services/backend_service.dart`:

- `GET /user/balance/:deviceId`
- `POST /user/reward`
- `POST /ai/summarize`
- `POST /ai/transcribe`

A Node/Express backend already exists under `server/`. It uses PostgreSQL for points, Groq for summarization/transcription, and `multer` for audio upload handling. The current Coolify URLs tested so far either point to the Coolify dashboard or do not route the API paths correctly.

## Architecture

Use the existing `server/` app as the backend source and adapt it for Vercel serverless deployment.

- Flutter keeps using the existing `BackendService` endpoint contract.
- Vercel hosts the Express app as a serverless function.
- Vercel Postgres/Neon stores point balances and point transaction history.
- Groq API key is configured only in Vercel environment variables.
- Audio uploads are temporary request payloads only; the backend forwards them to Groq and deletes any temporary file/buffer after processing.

## Data Model

Use two tables:

```sql
users (
  id SERIAL PRIMARY KEY,
  device_id TEXT UNIQUE NOT NULL,
  points INTEGER NOT NULL DEFAULT 100,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)

point_transactions (
  id SERIAL PRIMARY KEY,
  device_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```

The `users.points` column is the current balance. `point_transactions` preserves history for rewards, purchases, and AI consumption.

## API Behavior

- `GET /user/balance/:deviceId`: creates a user with 100 points if missing, then returns `{ points }`.
- `POST /user/reward`: increments points and records a positive transaction.
- `POST /ai/summarize`: checks points, calls Groq chat completions, deducts 10 points, records a negative transaction, and returns `{ summary }`.
- `POST /ai/transcribe`: receives an audio file, forwards it to Groq audio transcription, does not store the audio permanently, and returns `{ text }`.

## Environment Variables

Vercel must define:

- `DATABASE_URL`: Vercel Postgres/Neon connection string.
- `GROQ_API_KEY`: Groq API key.

Flutter `.env` must define:

- `BACKEND_URL`: the deployed Vercel app URL, e.g. `https://<project>.vercel.app`.

## Error Handling

Backend responses should return JSON errors instead of HTML:

- `400` for missing inputs or missing upload.
- `403` for insufficient points.
- `500` for database or Groq failures.

The Flutter app already treats `403` summarize responses as insufficient points. Transcription failures currently return `null`; diagnostic logging can remain during setup but should not expose secrets.

## Deployment Flow

1. Adapt `server/` for Vercel serverless routing.
2. Add Vercel config so all API routes resolve to the backend function.
3. Configure Vercel environment variables.
4. Deploy with Vercel.
5. Set Flutter `BACKEND_URL` to the Vercel URL.
6. Verify on Android: balance, reward, recording, transcription, and summary.

## Scope

This migration does not store audio files on the server. It does not add user accounts. It keeps the current device ID based identity model.
