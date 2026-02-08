-- Seed data for development and testing
-- This migration adds sample price history data for testing

-- Sample price history for popular cards (card_ids from Pokemon TCG API)
INSERT INTO price_history (card_id, price, price_source, recorded_at) VALUES
    -- Charizard Base Set
    ('base1-4', 450.00, 'tcgplayer', now() - interval '30 days'),
    ('base1-4', 475.00, 'tcgplayer', now() - interval '21 days'),
    ('base1-4', 520.00, 'tcgplayer', now() - interval '14 days'),
    ('base1-4', 510.00, 'tcgplayer', now() - interval '7 days'),
    ('base1-4', 535.00, 'tcgplayer', now()),

    -- Pikachu Base Set
    ('base1-58', 15.00, 'tcgplayer', now() - interval '30 days'),
    ('base1-58', 16.50, 'tcgplayer', now() - interval '21 days'),
    ('base1-58', 17.00, 'tcgplayer', now() - interval '14 days'),
    ('base1-58', 16.75, 'tcgplayer', now() - interval '7 days'),
    ('base1-58', 18.00, 'tcgplayer', now()),

    -- Blastoise Base Set
    ('base1-2', 180.00, 'tcgplayer', now() - interval '30 days'),
    ('base1-2', 190.00, 'tcgplayer', now() - interval '21 days'),
    ('base1-2', 195.00, 'tcgplayer', now() - interval '14 days'),
    ('base1-2', 200.00, 'tcgplayer', now() - interval '7 days'),
    ('base1-2', 210.00, 'tcgplayer', now()),

    -- Venusaur Base Set
    ('base1-15', 125.00, 'tcgplayer', now() - interval '30 days'),
    ('base1-15', 130.00, 'tcgplayer', now() - interval '21 days'),
    ('base1-15', 135.00, 'tcgplayer', now() - interval '14 days'),
    ('base1-15', 140.00, 'tcgplayer', now() - interval '7 days'),
    ('base1-15', 145.00, 'tcgplayer', now())
ON CONFLICT DO NOTHING;
