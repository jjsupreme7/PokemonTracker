-- PokemonTracker Database Schema
-- Initial migration: Creates all tables, RLS policies, indexes, and triggers

-- ============================================================================
-- TABLES
-- ============================================================================

-- 1. profiles - Links to Supabase Auth users
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    display_name TEXT,
    tier TEXT NOT NULL DEFAULT 'free',
    preferred_currency TEXT NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. collection_cards - User's Pokemon card collection
CREATE TABLE collection_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    card_id TEXT NOT NULL,                    -- Pokemon TCG API ID
    name TEXT NOT NULL,
    set_id TEXT,
    set_name TEXT,
    number TEXT,
    rarity TEXT,
    image_small TEXT,
    image_large TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    purchase_price NUMERIC(10, 2),
    current_price NUMERIC(10, 2),
    date_added TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. price_history - Global price tracking for all cards
CREATE TABLE price_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id TEXT NOT NULL,                    -- Pokemon TCG API ID
    price NUMERIC(10, 2) NOT NULL,
    price_source TEXT NOT NULL DEFAULT 'tcgplayer',
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. price_alerts - User price alerts
CREATE TABLE price_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    card_id TEXT NOT NULL,
    card_name TEXT NOT NULL,
    target_price NUMERIC(10, 2) NOT NULL,
    alert_type TEXT NOT NULL CHECK (alert_type IN ('above', 'below')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    triggered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. device_tokens - Push notification tokens
CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- collection_cards indexes
CREATE INDEX idx_collection_cards_user_card ON collection_cards(user_id, card_id);
CREATE INDEX idx_collection_cards_user_date ON collection_cards(user_id, date_added DESC);

-- price_history indexes
CREATE INDEX idx_price_history_card_recorded ON price_history(card_id, recorded_at DESC);

-- price_alerts indexes
CREATE INDEX idx_price_alerts_user_active ON price_alerts(user_id, is_active) WHERE is_active = true;

-- device_tokens indexes
CREATE INDEX idx_device_tokens_user_active ON device_tokens(user_id, is_active) WHERE is_active = true;

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- profiles policies
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
    ON profiles FOR DELETE
    USING (auth.uid() = id);

-- collection_cards policies
CREATE POLICY "Users can view own collection cards"
    ON collection_cards FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own collection cards"
    ON collection_cards FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own collection cards"
    ON collection_cards FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own collection cards"
    ON collection_cards FOR DELETE
    USING (auth.uid() = user_id);

-- price_history policies (public read, service role write)
CREATE POLICY "Anyone can view price history"
    ON price_history FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert price history"
    ON price_history FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

-- price_alerts policies
CREATE POLICY "Users can view own price alerts"
    ON price_alerts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own price alerts"
    ON price_alerts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own price alerts"
    ON price_alerts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own price alerts"
    ON price_alerts FOR DELETE
    USING (auth.uid() = user_id);

-- device_tokens policies
CREATE POLICY "Users can view own device tokens"
    ON device_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device tokens"
    ON device_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device tokens"
    ON device_tokens FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own device tokens"
    ON device_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function to automatically create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call handle_new_user on auth.users insert
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for profiles updated_at
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger for collection_cards updated_at
CREATE TRIGGER update_collection_cards_updated_at
    BEFORE UPDATE ON collection_cards
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- COMMENTS (for documentation)
-- ============================================================================

COMMENT ON TABLE profiles IS 'User profiles linked to Supabase Auth';
COMMENT ON TABLE collection_cards IS 'Pokemon cards in user collections';
COMMENT ON TABLE price_history IS 'Historical price data for Pokemon cards';
COMMENT ON TABLE price_alerts IS 'Price alert configurations for users';
COMMENT ON TABLE device_tokens IS 'Push notification device tokens';

COMMENT ON COLUMN collection_cards.card_id IS 'Pokemon TCG API card identifier';
COMMENT ON COLUMN price_history.card_id IS 'Pokemon TCG API card identifier';
COMMENT ON COLUMN price_alerts.alert_type IS 'Trigger when price goes above or below target';
