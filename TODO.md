# Pokemon Tracker - TODO

## Pending

- [ ] **Run Supabase migration for `market_movers_cache` table**
  - Go to [Supabase Dashboard](https://supabase.com/dashboard) → project `twqjbatnqmytypfgewdn` → SQL Editor
  - Paste and run the SQL from `supabase/migrations/20260209000000_market_movers_cache.sql`
  - This creates the table, indexes, and RLS policies needed for the Market Movers feature
  - Once applied, the backend cron job will auto-populate data every 30 minutes

- [ ] **Share app with friends on iPhone**
  - Set up TestFlight distribution via App Store Connect
  - Add testers by email or create a public TestFlight link
  - Requires Apple Developer Program membership ($99/year)

## Completed

- [x] Pokemon/Japanese theme redesign (web + iOS)
- [x] Real Market Movers feature (backend service, cron job, iOS + web integration)
- [x] Wire View All buttons on Market Movers and Trending Cards carousels
- [x] Switch iOS to PokeTrace API for pricing
- [x] Claude Vision card scanner
- [x] Make repo public
