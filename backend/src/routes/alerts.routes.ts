import { Router } from 'express';
import { AlertsController } from '../controllers/alerts.controller.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();
const controller = new AlertsController();

// All routes require authentication
router.use(authMiddleware);

router.get('/', (req, res) => controller.getAlerts(req, res));
router.post('/', (req, res) => controller.createAlert(req, res));
router.put('/:alertId', (req, res) => controller.updateAlert(req, res));
router.delete('/:alertId', (req, res) => controller.deleteAlert(req, res));

export const alertsRoutes = router;
