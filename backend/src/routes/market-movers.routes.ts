import { Router } from 'express';
import { MarketMoversController } from '../controllers/market-movers.controller.js';
import { optionalAuthMiddleware } from '../middleware/auth.js';

const router = Router();
const controller = new MarketMoversController();

router.use(optionalAuthMiddleware);

router.get('/', (req, res) => controller.getMarketMovers(req, res));

export const marketMoversRoutes = router;
