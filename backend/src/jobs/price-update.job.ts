import cron from 'node-cron';
import { config } from '../config/index.js';
import { supabaseAdmin } from '../config/supabase.js';
import { PokemonTCGService } from '../services/pokemon-tcg.service.js';

export class PriceUpdateJob {
  private pokemonTCGService = new PokemonTCGService();
  private isRunning = false;

  start(): void {
    cron.schedule(config.jobs.priceUpdateCron, async () => {
      await this.run();
    });

    console.log(`Price update job scheduled: ${config.jobs.priceUpdateCron}`);
  }

  async run(): Promise<void> {
    if (this.isRunning) {
      console.log('Price update job already running, skipping');
      return;
    }

    this.isRunning = true;
    console.log('Starting price update job');

    try {
      // Get all unique card IDs from collections
      const { data: cardIds, error } = await supabaseAdmin
        .from('collection_cards')
        .select('card_id');

      if (error) {
        throw error;
      }

      const uniqueCardIds = [...new Set(cardIds.map(c => c.card_id))];
      console.log(`Updating prices for ${uniqueCardIds.length} cards`);

      // Process in batches to respect API rate limits
      const batchSize = 50;
      let updated = 0;
      let failed = 0;

      for (let i = 0; i < uniqueCardIds.length; i += batchSize) {
        const batch = uniqueCardIds.slice(i, i + batchSize);
        const results = await this.processBatch(batch);
        updated += results.updated;
        failed += results.failed;

        // Respect Pokemon TCG API rate limits (1000/day without key, 20000 with)
        if (i + batchSize < uniqueCardIds.length) {
          await this.delay(1000);
        }
      }

      console.log(`Price update job completed: ${updated} updated, ${failed} failed`);
    } catch (error) {
      console.error('Price update job failed:', error);
    } finally {
      this.isRunning = false;
    }
  }

  private async processBatch(cardIds: string[]): Promise<{ updated: number; failed: number }> {
    let updated = 0;
    let failed = 0;

    for (const cardId of cardIds) {
      try {
        const card = await this.pokemonTCGService.getCard(cardId);
        const price = this.pokemonTCGService.extractMarketPrice(card);

        if (price !== null) {
          // Insert price history
          await supabaseAdmin.from('price_history').insert({
            card_id: cardId,
            price,
            price_source: 'tcgplayer',
          });

          // Update current price in collection cards
          await supabaseAdmin
            .from('collection_cards')
            .update({
              current_price: price,
              updated_at: new Date().toISOString(),
            })
            .eq('card_id', cardId);

          updated++;
        }
      } catch (error) {
        console.error(`Failed to update price for ${cardId}:`, error);
        failed++;
      }
    }

    return { updated, failed };
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
