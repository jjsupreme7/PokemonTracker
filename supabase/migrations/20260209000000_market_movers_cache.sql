-- Market Movers Cache Table
-- Stores precomputed market movers (gainers, losers, hot cards)
-- Updated by cron job every 30 minutes

CREATE TABLE IF NOT EXISTS market_movers_cache (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category TEXT NOT NULL CHECK (category IN ('gainers', 'losers', 'hot_cards')),
  card_id TEXT NOT NULL,
  name TEXT NOT NULL,
  set_name TEXT NOT NULL,
  rarity TEXT,
  image_small TEXT NOT NULL,
  image_large TEXT NOT NULL,
  current_price DECIMAL(10, 2),
  previous_price DECIMAL(10, 2),
  price_change DECIMAL(10, 2),
  price_change_percent DECIMAL(8, 2),
  tracker_count INTEGER DEFAULT 0,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX idx_market_movers_category ON market_movers_cache (category);
CREATE INDEX idx_market_movers_computed_at ON market_movers_cache (computed_at DESC);
CREATE INDEX idx_market_movers_category_computed ON market_movers_cache (category, computed_at DESC);

-- RLS
ALTER TABLE market_movers_cache ENABLE ROW LEVEL SECURITY;

-- Anyone can read market movers (public endpoint)
CREATE POLICY "Market movers are publicly readable"
  ON market_movers_cache FOR SELECT
  USING (true);

-- Only service role can write (via cron job)
CREATE POLICY "Service role can manage market movers"
  ON market_movers_cache FOR ALL
  USING (auth.role() = 'service_role');
