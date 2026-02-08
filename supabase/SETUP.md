# Supabase Database Setup

## Quick Start

### Option 1: Supabase Dashboard (Recommended for initial setup)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the contents of `migrations/20250122000000_initial_schema.sql`
4. Click **Run** to execute
5. (Optional) Run `migrations/20250122000001_seed_data.sql` for sample data

### Option 2: Supabase CLI

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Push migrations
supabase db push
```

## Verify Setup

After running the migrations, verify the setup:

1. **Check Tables**: Go to **Table Editor** - you should see:
   - `profiles`
   - `collection_cards`
   - `price_history`
   - `price_alerts`
   - `device_tokens`

2. **Test Auth Trigger**:
   - Go to **Authentication > Users**
   - Create a test user
   - Check **Table Editor > profiles** - a row should auto-create

3. **Test RLS**:
   - Go to **SQL Editor** and run:
   ```sql
   -- This should show all policies
   SELECT tablename, policyname, cmd, qual
   FROM pg_policies
   WHERE schemaname = 'public';
   ```

## Schema Overview

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles (auto-created on signup) |
| `collection_cards` | User's Pokemon card collection |
| `price_history` | Historical price data (public read) |
| `price_alerts` | User price alert configurations |
| `device_tokens` | Push notification tokens |

## RLS Policies

All tables have Row Level Security enabled:

- **profiles, collection_cards, price_alerts, device_tokens**: Users can only access their own data
- **price_history**: Public read access, service role write only

## Environment Variables

Required in your `.env`:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Troubleshooting

### "permission denied" errors
- Ensure RLS policies are created correctly
- Check that you're using the correct API key (anon vs service role)

### Profile not auto-creating
- Verify the `on_auth_user_created` trigger exists
- Check the `handle_new_user` function is in the `public` schema

### Can't insert price_history
- Use the service role key for price updates (not anon key)
