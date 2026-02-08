import { Response } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { PokemonTCGService } from '../services/pokemon-tcg.service.js';
import type { AuthenticatedRequest } from '../types/index.js';

export class PricesController {
  private pokemonTCGService = new PokemonTCGService();

  // GET /api/prices/:cardId
  async getPrice(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { cardId } = req.params;

    try {
      // Get latest price from history
      const { data: latestPrice } = await supabaseAdmin
        .from('price_history')
        .select('*')
        .eq('card_id', cardId)
        .order('recorded_at', { ascending: false })
        .limit(1)
        .single();

      // If no price in history or stale (> 6 hours), fetch fresh
      const isStale = !latestPrice ||
        Date.now() - new Date(latestPrice.recorded_at).getTime() > 6 * 60 * 60 * 1000;

      if (isStale) {
        const card = await this.pokemonTCGService.getCard(cardId);
        const price = this.pokemonTCGService.extractMarketPrice(card);

        if (price !== null) {
          // Store in history
          await supabaseAdmin.from('price_history').insert({
            card_id: cardId,
            price,
            price_source: 'tcgplayer',
          });

          res.json({
            card_id: cardId,
            price,
            source: 'tcgplayer',
            recorded_at: new Date().toISOString(),
            fresh: true,
          });
          return;
        }
      }

      if (latestPrice) {
        res.json({
          card_id: cardId,
          price: latestPrice.price,
          source: latestPrice.price_source,
          recorded_at: latestPrice.recorded_at,
          fresh: false,
        });
        return;
      }

      res.status(404).json({ error: 'Price not found' });
    } catch (error) {
      console.error('Get price error:', error);
      res.status(500).json({ error: 'Failed to get price' });
    }
  }

  // GET /api/prices/:cardId/history
  async getPriceHistory(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { cardId } = req.params;
    const days = parseInt(req.query.days as string) || 30;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const { data, error } = await supabaseAdmin
      .from('price_history')
      .select('price, price_source, recorded_at')
      .eq('card_id', cardId)
      .gte('recorded_at', startDate.toISOString())
      .order('recorded_at', { ascending: true });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    // Calculate stats
    const prices = data.map(d => d.price);
    const stats = prices.length > 0 ? {
      current: prices[prices.length - 1],
      min: Math.min(...prices),
      max: Math.max(...prices),
      avg: prices.reduce((a, b) => a + b, 0) / prices.length,
      change: prices.length > 1
        ? ((prices[prices.length - 1] - prices[0]) / prices[0]) * 100
        : 0,
    } : null;

    res.json({
      card_id: cardId,
      history: data,
      stats,
    });
  }

  // GET /api/prices/batch
  async getBatchPrices(req: AuthenticatedRequest, res: Response): Promise<void> {
    const cardIds = (req.query.ids as string)?.split(',') || [];

    if (cardIds.length === 0) {
      res.status(400).json({ error: 'ids query parameter required' });
      return;
    }

    if (cardIds.length > 100) {
      res.status(400).json({ error: 'Maximum 100 card IDs per request' });
      return;
    }

    // Get latest price for each card
    const { data, error } = await supabaseAdmin
      .from('price_history')
      .select('card_id, price, price_source, recorded_at')
      .in('card_id', cardIds)
      .order('recorded_at', { ascending: false });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    // Get most recent price per card
    const priceMap = new Map<string, typeof data[0]>();
    for (const price of data) {
      if (!priceMap.has(price.card_id)) {
        priceMap.set(price.card_id, price);
      }
    }

    res.json({
      prices: Object.fromEntries(priceMap),
    });
  }
}
