-- Add variant column to collection_cards for accurate card matching
-- Variant identifies the specific card type (V, VMAX, ex, Full Art, Reverse Holo, etc.)
-- Nullable for backward compatibility with existing rows

ALTER TABLE collection_cards ADD COLUMN variant TEXT;

COMMENT ON COLUMN collection_cards.variant IS 'Card variant type (e.g., V, VMAX, ex, Full Art, Reverse Holo)';
