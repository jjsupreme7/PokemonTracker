import { Router } from 'express';
import { CollectionController } from '../controllers/collection.controller.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();
const controller = new CollectionController();

// All routes require authentication
router.use(authMiddleware);

router.get('/', (req, res) => controller.getCollection(req, res));
router.post('/', (req, res) => controller.addCard(req, res));
router.put('/:cardId', (req, res) => controller.updateCard(req, res));
router.delete('/:cardId', (req, res) => controller.removeCard(req, res));
router.post('/sync', (req, res) => controller.syncCollection(req, res));

export const collectionRoutes = router;
