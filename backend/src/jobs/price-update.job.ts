import cron from 'node-cron';
import { config } from '../config/index.js';
import { supabaseAdmin } from '../config/supabase.js';

interface PokeTraceCard {
  id: string;
  name: string;
  cardNumber?: string;
  set?: { slug?: string; name?: string };
  prices?: {
    tcgplayer?: PokeTraceConditions;
    ebay?: PokeTraceConditions;
  };
}

interface PokeTraceConditions {
  NEAR_MINT?: PokeTracePricePoint;
  LIGHTLY_PLAYED?: PokeTracePricePoint;
  MODERATELY_PLAYED?: PokeTracePricePoint;
}

interface PokeTracePricePoint {
  avg?: number;
  low?: number;
  high?: number;
  saleCount?: number;
}

interface PokeTraceResponse {
  data: PokeTraceCard[];
}

interface CollectionCardRow {
  card_id: string;
  name: string;
  set_name: string | null;
  number: string | null;
}

export class PriceUpdateJob {
  private isRunning = false;
  private readonly apiKey = config.poketrace.apiKey;
  private readonly baseUrl = config.poketrace.baseUrl;

  start(): void {
    cron.schedule(config.jobs.priceUpdateCron, async () => {
      await this.run();
    });

    // Run 30 seconds after startup for initial price refresh
    setTimeout(() => {
      this.run().catch(err => console.error('Initial price update failed:', err));
    }, 30_000);

    console.log(`Price update job scheduled: ${config.jobs.priceUpdateCron}`);
  }

  async run(): Promise<void> {
    if (this.isRunning) {
      console.log('Price update job already running, skipping');
      return;
    }

    this.isRunning = true;
    console.log('Starting price update job (PokeTrace)');

    try {
      // Get all unique cards from collections (need name + set for PokeTrace search)
      const { data: cards, error } = await supabaseAdmin
        .from('collection_cards')
        .select('card_id, name, set_name, number');

      if (error) {
        throw error;
      }

      // Deduplicate by card_id
      const seen = new Set<string>();
      const uniqueCards: CollectionCardRow[] = [];
      for (const card of cards) {
        if (!seen.has(card.card_id)) {
          seen.add(card.card_id);
          uniqueCards.push(card);
        }
      }

      console.log(`Updating prices for ${uniqueCards.length} unique cards`);

      let updated = 0;
      let failed = 0;

      for (const card of uniqueCards) {
        try {
          const price = await this.fetchPokeTracePrice(card);

          if (price !== null) {
            // Insert price history (table may not exist yet)
            try {
              await supabaseAdmin.from('price_history').insert({
                card_id: card.card_id,
                price,
                price_source: 'poketrace',
              });
            } catch {
              // price_history table might not exist, skip
            }

            // Update current price in collection cards
            await supabaseAdmin
              .from('collection_cards')
              .update({
                current_price: price,
                updated_at: new Date().toISOString(),
              })
              .eq('card_id', card.card_id);

            updated++;
            console.log(`  Updated ${card.name}: $${price}`);
          }
        } catch (error) {
          console.error(`Failed to update price for ${card.name}:`, error);
          failed++;
        }

        // Rate limit: 500ms between requests
        await this.delay(500);
      }

      console.log(`Price update job completed: ${updated} updated, ${failed} failed`);
    } catch (error) {
      console.error('Price update job failed:', error);
    } finally {
      this.isRunning = false;
    }
  }

  private async fetchPokeTracePrice(card: CollectionCardRow): Promise<number | null> {
    // Build search query
    let searchQuery = card.name;
    if (card.set_name) {
      searchQuery += ` ${card.set_name}`;
    }

    const params = new URLSearchParams({
      search: searchQuery,
      limit: '10',
    });

    const response = await fetch(`${this.baseUrl}/cards?${params}`, {
      headers: {
        'x-api-key': this.apiKey,
      },
    });

    if (!response.ok) {
      throw new Error(`PokeTrace API error: ${response.status}`);
    }

    const data = (await response.json()) as PokeTraceResponse;

    if (!data.data || data.data.length === 0) {
      return null;
    }

    // Find best match
    const match = this.findBestMatch(data.data, card);
    if (!match) return null;

    // Extract best price: NM TCGPlayer > NM eBay > LP TCGPlayer > LP eBay
    return this.extractBestPrice(match);
  }

  private findBestMatch(results: PokeTraceCard[], card: CollectionCardRow): PokeTraceCard | null {
    const nameLower = card.name.toLowerCase();

    // Try exact name + number match
    if (card.number) {
      for (const r of results) {
        if (r.name.toLowerCase() === nameLower && r.cardNumber?.includes(card.number)) {
          return r;
        }
      }
    }

    // Try exact name match
    for (const r of results) {
      if (r.name.toLowerCase() === nameLower) {
        return r;
      }
    }

    // Try contains match
    for (const r of results) {
      if (r.name.toLowerCase().includes(nameLower) || nameLower.includes(r.name.toLowerCase())) {
        return r;
      }
    }

    // Fall back to first result
    return results[0] ?? null;
  }

  private extractBestPrice(card: PokeTraceCard): number | null {
    const tcg = card.prices?.tcgplayer;
    const ebay = card.prices?.ebay;

    return tcg?.NEAR_MINT?.avg
      ?? ebay?.NEAR_MINT?.avg
      ?? tcg?.LIGHTLY_PLAYED?.avg
      ?? ebay?.LIGHTLY_PLAYED?.avg
      ?? tcg?.MODERATELY_PLAYED?.avg
      ?? null;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
