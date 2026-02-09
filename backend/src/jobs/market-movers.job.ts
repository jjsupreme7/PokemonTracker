import cron from 'node-cron';
import { MarketMoversService } from '../services/market-movers.service.js';

export class MarketMoversJob {
  private service = new MarketMoversService();
  private isRunning = false;

  start(): void {
    // Run every 30 minutes
    cron.schedule('*/30 * * * *', async () => {
      await this.run();
    });

    // Run 10 seconds after startup for initial data
    setTimeout(() => {
      this.run().catch(err => console.error('Initial market movers computation failed:', err));
    }, 10_000);

    console.log('Market movers job scheduled: */30 * * * *');
  }

  async run(): Promise<void> {
    if (this.isRunning) {
      console.log('Market movers job already running, skipping');
      return;
    }

    this.isRunning = true;
    console.log('Starting market movers job');

    try {
      await this.service.computeMarketMovers();
      console.log('Market movers job completed');
    } catch (error) {
      console.error('Market movers job failed:', error);
    } finally {
      this.isRunning = false;
    }
  }
}
