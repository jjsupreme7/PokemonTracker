import { Router } from 'express';
import { authRoutes } from './auth.routes.js';
import { collectionRoutes } from './collection.routes.js';
import { pricesRoutes } from './prices.routes.js';
import { alertsRoutes } from './alerts.routes.js';
import { devicesRoutes } from './devices.routes.js';
import { scanRoutes } from './scan.routes.js';

export const routes = Router();

routes.use('/auth', authRoutes);
routes.use('/collection', collectionRoutes);
routes.use('/prices', pricesRoutes);
routes.use('/alerts', alertsRoutes);
routes.use('/devices', devicesRoutes);
routes.use('/scan', scanRoutes);
