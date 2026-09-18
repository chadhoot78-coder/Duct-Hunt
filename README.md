# Duck Tracker

Single-page duck hunt log for iPhone (PWA). Static site — no build step.

- `index.html` — the app (all HTML/CSS/JS in one file)
- `sw.js` — service worker for offline use
- `manifest.json` — PWA manifest
- `icon.png` — Home Screen icon

## Deploy
Push to GitHub, import the repo into Vercel with framework "Other", deploy.
Install on iPhone: open the URL in Safari → Share → Add to Home Screen.

When you edit `index.html`, bump `CACHE` in `sw.js` (v2 → v3 …) so phones pick up the new version.

## Features
- Species tallies with per-species and total bag-limit warnings (editable under More)
- Weather auto-fill from Open-Meteo (free, no key): wind, temps, sky, barometric pressure and trend, temp change from the previous day
- Legal shooting light (sunrise − 30 min) and sunset computed from GPS, no network needed
- Start/End hunt buttons that stamp the time and pin GPS
- Saved blinds with a map of where the ducks came from
- Photos per hunt (stored on the phone, included in backups)
- History, date-range table, season stats, "best conditions" stats
- CSV export, full JSON backup/restore
- Optional shared log across phones via Supabase (below)

## Shared log setup (optional)
1. Create a free project at supabase.com.
2. In the SQL editor, run:

```sql
create table if not exists hunts (
  id text primary key,
  crew text not null,
  data jsonb not null,
  updated_at timestamptz default now()
);
create index if not exists hunts_crew on hunts (crew);
alter table hunts enable row level security;
create policy "crew read"   on hunts for select to anon using (true);
create policy "crew insert" on hunts for insert to anon with check (true);
create policy "crew update" on hunts for update to anon using (true);
create policy "crew delete" on hunts for delete to anon using (true);
```

3. In Project Settings → API, copy the Project URL and the `anon` public key.
4. In the app under More → Shared log, paste both, pick a crew code, and tap Save settings. Everyone on the crew enters the same three values.

Anyone with the anon key and crew code can read and write the crew's hunts, so don't post the key publicly. Photos are not synced — they stay on the phone that took them.
