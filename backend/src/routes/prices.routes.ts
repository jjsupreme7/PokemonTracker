import { Router } from 'express';
import { PricesController } from '../controllers/prices.controller.js';
import { optionalAuthMiddleware } from '../middleware/auth.js';

const router = Router();
const controller = new PricesController();

// Price endpoints don't require auth but can use it
router.use(optionalAuthMiddleware);

router.get('/batch', (req, res) => controller.getBatchPrices(req, res));
router.get('/:cardId', (req, res) => controller.getPrice(req, res));
router.get('/:cardId/history', (req, res) => controller.getPriceHistory(req, res));

export const pricesRoutes = router;
