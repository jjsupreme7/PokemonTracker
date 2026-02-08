export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  supabase: {
    url: process.env.SUPABASE_URL || '',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  },

  pokemonTcg: {
    apiKey: process.env.POKEMON_TCG_API_KEY || '',
    baseUrl: 'https://api.pokemontcg.io/v2',
  },

  apns: {
    keyPath: process.env.APNS_KEY_PATH || '',
    keyId: process.env.APNS_KEY_ID || '',
    teamId: process.env.APNS_TEAM_ID || '',
    bundleId: process.env.IOS_BUNDLE_ID || '',
  },

  jobs: {
    priceUpdateCron: process.env.PRICE_UPDATE_CRON || '0 */6 * * *',
    alertProcessorCron: process.env.ALERT_PROCESSOR_CRON || '*/15 * * * *',
  },
} as const;

// Validate required config in production
if (config.nodeEnv === 'production') {
  const required = [
    ['SUPABASE_URL', config.supabase.url],
    ['SUPABASE_ANON_KEY', config.supabase.anonKey],
    ['SUPABASE_SERVICE_ROLE_KEY', config.supabase.serviceRoleKey],
  ] as const;

  for (const [name, value] of required) {
    if (!value) {
      throw new Error(`Missing required environment variable: ${name}`);
    }
  }
}
