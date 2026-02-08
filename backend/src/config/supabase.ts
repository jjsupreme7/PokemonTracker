import { createClient } from '@supabase/supabase-js';
import { config } from './index.js';

// Client for authenticated user requests (uses user's JWT)
export const supabase = createClient(
  config.supabase.url,
  config.supabase.anonKey
);

// Admin client for server-side operations (bypasses RLS)
export const supabaseAdmin = createClient(
  config.supabase.url,
  config.supabase.serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);
