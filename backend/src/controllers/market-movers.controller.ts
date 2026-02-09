import { Response } from 'express';
import { MarketMoversService } from '../services/market-movers.service.js';
import type { AuthenticatedRequest } from '../types/index.js';

const marketMoversService = new MarketMoversService();

export class MarketMoversController {
  // GET /api/market-movers
  async getMarketMovers(_req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const data = await marketMoversService.getMarketMovers();
      res.json(data);
    } catch (error) {
      console.error('Get market movers error:', error);
      res.status(500).json({ error: 'Failed to get market movers' });
    }
  }
}

// Export a shared instance of the service for the cron job
export { marketMoversService };
