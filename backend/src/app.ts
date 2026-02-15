import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { routes } from './routes/index.js';
import { errorHandler } from './middleware/errorHandler.js';

export const app = express();

// Security middleware
app.use(helmet());
app.use(cors());

// Body parsing (10mb limit for base64 card images)
app.use(express.json({ limit: '10mb' }));

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api', routes);

// Error handling
app.use(errorHandler);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});
