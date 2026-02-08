import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { ScanController } from '../controllers/scan.controller.js';

export const scanRoutes = Router();
const controller = new ScanController();

scanRoutes.post('/identify', authMiddleware, controller.identify);
