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
- Accounts (email + password) and hunting groups via Supabase (below)

## Accounts & groups setup (Supabase)
1. In your Supabase project, open SQL Editor → New query, paste all of `supabase/duck-setup.sql`, and Run.
2. Authentication → URL Configuration: set **Site URL** to your Vercel address (e.g. `https://your-app.vercel.app`) so confirm-email and password-reset links open the app.
3. Optional: Authentication → Sign In / Providers → Email → turn off **Confirm email** if you don't want new users to have to click an email link first.
4. Put your Project URL and `anon` public key into `SB_URL` / `SB_KEY` near the top of the Supabase section in `index.html` so users only see email + password. (Left blank, the app shows URL/key fields instead.)

How it works: each person signs up under More → Account & group. One person starts a group and shares its 6-character code; others join with it. History, Table and Stats get a "My hunts / Whole group" switch. Everyone in a group can see each other's hunts; only the person who logged a hunt can edit or delete it (enforced by row-level security in the database). Photos are not uploaded — they stay on the phone that took them.

The anon key is designed to be public; the row-level security rules are what keep data private.
