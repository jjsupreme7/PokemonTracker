import { supabaseAdmin } from '../config/supabase.js';
import { PokemonTCGService } from './pokemon-tcg.service.js';

export interface MarketMoverCard {
  card_id: string;
  name: string;
  set_name: string;
  rarity: string | null;
  image_small: string;
  image_large: string;
  current_price: number | null;
  previous_price: number | null;
  price_change: number | null;
  price_change_percent: number | null;
  tracker_count: number;
}

export interface MarketMoversResponse {
  gainers: MarketMoverCard[];
  losers: MarketMoverCard[];
  hot_cards: MarketMoverCard[];
  cached_at: string;
}


export class MarketMoversService {
  private pokemonTCGService = new PokemonTCGService();
  private cache: { data: MarketMoversResponse; timestamp: number } | null = null;
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutes

  // Called by controller - reads from cache
  async getMarketMovers(): Promise<MarketMoversResponse> {
    // Check in-memory cache first
    if (this.cache && Date.now() - this.cache.timestamp < this.CACHE_TTL) {
      return this.cache.data;
    }

    // Fallback to Supabase
    const { data, error } = await supabaseAdmin
      .from('market_movers_cache')
      .select('*')
      .order('computed_at', { ascending: false })
      .limit(30);

    if (error || !data?.length) {
      return { gainers: [], losers: [], hot_cards: [], cached_at: new Date().toISOString() };
    }

    // Get the most recent computed_at timestamp
    const cachedAt = data[0].computed_at;

    // Filter to only the latest batch
    const latestBatch = data.filter((d: any) => d.computed_at === cachedAt);

    const result: MarketMoversResponse = {
      gainers: latestBatch.filter((d: any) => d.category === 'gainers').map(this.mapRow),
      losers: latestBatch.filter((d: any) => d.category === 'losers').map(this.mapRow),
      hot_cards: latestBatch.filter((d: any) => d.category === 'hot_cards').map(this.mapRow),
      cached_at: cachedAt,
    };

    // Update in-memory cache
    this.cache = { data: result, timestamp: Date.now() };

    return result;
  }

  // Called by cron job - heavy computation
  async computeMarketMovers(): Promise<void> {
    console.log('Computing market movers...');

    const [gainers, losers, hotCards] = await Promise.all([
      this.computeGainers(),
      this.computeLosers(),
      this.computeHotCards(),
    ]);

    const computedAt = new Date().toISOString();

    // Build rows for insert
    const rows = [
      ...gainers.map(card => ({ ...card, category: 'gainers', computed_at: computedAt })),
      ...losers.map(card => ({ ...card, category: 'losers', computed_at: computedAt })),
      ...hotCards.map(card => ({ ...card, category: 'hot_cards', computed_at: computedAt })),
    ];

    if (rows.length === 0) {
      console.log('No market movers data to insert');
      return;
    }

    // Clear old data and insert new
    await supabaseAdmin
      .from('market_movers_cache')
      .delete()
      .lt('computed_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    const { error } = await supabaseAdmin
      .from('market_movers_cache')
      .insert(rows);

    if (error) {
      console.error('Failed to insert market movers:', error);
      return;
    }

    // Invalidate in-memory cache
    this.cache = null;

    console.log(`Market movers computed: ${gainers.length} gainers, ${losers.length} losers, ${hotCards.length} hot cards`);
  }

  private async computeGainers(): Promise<Omit<MarketMoverCard, never>[]> {
    return this.computePriceMovers('desc');
  }

  private async computeLosers(): Promise<Omit<MarketMoverCard, never>[]> {
    return this.computePriceMovers('asc');
  }

  private async computePriceMovers(direction: 'asc' | 'desc'): Promise<MarketMoverCard[]> {
    try {
      // Get cards with price history in the last 7 days
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

      const { data: recentPrices } = await supabaseAdmin
        .from('price_history')
        .select('card_id, price, recorded_at')
        .gte('recorded_at', sevenDaysAgo)
        .order('recorded_at', { ascending: true });

      if (!recentPrices?.length) {
        return this.getFallbackCards(direction);
      }

      // Group prices by card_id, get first and last price
      const cardPrices = new Map<string, { first: number; last: number }>();
      for (const entry of recentPrices) {
        const existing = cardPrices.get(entry.card_id);
        if (!existing) {
          cardPrices.set(entry.card_id, { first: entry.price, last: entry.price });
        } else {
          existing.last = entry.price;
        }
      }

      // Calculate % change and sort
      const movers = Array.from(cardPrices.entries())
        .map(([cardId, prices]) => ({
          cardId,
          currentPrice: prices.last,
          previousPrice: prices.first,
          change: prices.last - prices.first,
          changePercent: prices.first > 0
            ? ((prices.last - prices.first) / prices.first) * 100
            : 0,
        }))
        .filter(m => direction === 'desc' ? m.changePercent > 0 : m.changePercent < 0)
        .sort((a, b) => direction === 'desc'
          ? b.changePercent - a.changePercent
          : a.changePercent - b.changePercent
        )
        .slice(0, 10);

      if (movers.length < 5) {
        const fallbacks = await this.getFallbackCards(direction);
        return [...movers.map(m => this.moverToCard(m)), ...fallbacks].slice(0, 10);
      }

      // Fetch card metadata from Pokemon TCG API
      const cardIds = movers.map(m => m.cardId);
      const cards = await this.fetchCardMetadata(cardIds);

      return movers.map(m => {
        const card = cards.get(m.cardId);
        return {
          card_id: m.cardId,
          name: card?.name || m.cardId,
          set_name: card?.set?.name || 'Unknown Set',
          rarity: card?.rarity || null,
          image_small: card?.images?.small || '',
          image_large: card?.images?.large || '',
          current_price: m.currentPrice,
          previous_price: m.previousPrice,
          price_change: Math.round(m.change * 100) / 100,
          price_change_percent: Math.round(m.changePercent * 100) / 100,
          tracker_count: 0,
        };
      });
    } catch (error) {
      console.error(`Error computing ${direction} movers:`, error);
      return this.getFallbackCards(direction);
    }
  }

  private async computeHotCards(): Promise<MarketMoverCard[]> {
    try {
      // Get most tracked cards from collection_cards
      const { data: tracked } = await supabaseAdmin
        .from('collection_cards')
        .select('card_id, name, set_name, image_small, image_large, current_price')
        .order('date_added', { ascending: false });

      if (!tracked?.length) {
        return this.getFallbackCards('desc');
      }

      // Count trackers per card
      const trackerCounts = new Map<string, { count: number; card: typeof tracked[0] }>();
      for (const card of tracked) {
        const existing = trackerCounts.get(card.card_id);
        if (existing) {
          existing.count++;
        } else {
          trackerCounts.set(card.card_id, { count: 1, card });
        }
      }

      // Sort by tracker count
      const hotCards = Array.from(trackerCounts.entries())
        .sort((a, b) => b[1].count - a[1].count)
        .slice(0, 10)
        .map(([cardId, { count, card }]) => ({
          card_id: cardId,
          name: card.name,
          set_name: card.set_name,
          rarity: null,
          image_small: card.image_small,
          image_large: card.image_large,
          current_price: card.current_price,
          previous_price: null,
          price_change: null,
          price_change_percent: null,
          tracker_count: count,
        }));

      if (hotCards.length < 5) {
        const fallbacks = await this.getFallbackCards('desc');
        return [...hotCards, ...fallbacks].slice(0, 10);
      }

      return hotCards;
    } catch (error) {
      console.error('Error computing hot cards:', error);
      return this.getFallbackCards('desc');
    }
  }

  private async getFallbackCards(_direction: 'asc' | 'desc'): Promise<MarketMoverCard[]> {
    // No fallback — return empty rather than simulated data
    return [];
  }

  private async fetchCardMetadata(cardIds: string[]): Promise<Map<string, any>> {
    const map = new Map();
    try {
      const cards = await this.pokemonTCGService.getCardsByIds(cardIds);
      for (const card of cards) {
        map.set(card.id, card);
      }
    } catch (error) {
      console.error('Error fetching card metadata:', error);
    }
    return map;
  }

  private moverToCard(mover: { cardId: string; currentPrice: number; previousPrice: number; change: number; changePercent: number }): MarketMoverCard {
    return {
      card_id: mover.cardId,
      name: mover.cardId,
      set_name: 'Unknown',
      rarity: null,
      image_small: '',
      image_large: '',
      current_price: mover.currentPrice,
      previous_price: mover.previousPrice,
      price_change: Math.round(mover.change * 100) / 100,
      price_change_percent: Math.round(mover.changePercent * 100) / 100,
      tracker_count: 0,
    };
  }

  private mapRow(row: any): MarketMoverCard {
    return {
      card_id: row.card_id,
      name: row.name,
      set_name: row.set_name,
      rarity: row.rarity,
      image_small: row.image_small,
      image_large: row.image_large,
      current_price: row.current_price,
      previous_price: row.previous_price,
      price_change: row.price_change,
      price_change_percent: row.price_change_percent,
      tracker_count: row.tracker_count || 0,
    };
  }
}
