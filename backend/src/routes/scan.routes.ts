import { Router } from 'express';
import { optionalAuthMiddleware } from '../middleware/auth.js';
import { ScanController } from '../controllers/scan.controller.js';

export const scanRoutes = Router();
const controller = new ScanController();

scanRoutes.post('/identify', optionalAuthMiddleware, controller.identify);
