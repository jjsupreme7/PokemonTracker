import { Router } from 'express';
import { DevicesController } from '../controllers/devices.controller.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();
const controller = new DevicesController();

// All routes require authentication
router.use(authMiddleware);

router.get('/', (req, res) => controller.getDevices(req, res));
router.post('/register', (req, res) => controller.registerDevice(req, res));
router.delete('/:token', (req, res) => controller.unregisterDevice(req, res));

export const devicesRoutes = router;
