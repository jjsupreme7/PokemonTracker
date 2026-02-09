import 'dotenv/config';
import { app } from './app.js';
import { config } from './config/index.js';
import { PriceUpdateJob } from './jobs/price-update.job.js';
import { AlertProcessorJob } from './jobs/alert-processor.job.js';
import { MarketMoversJob } from './jobs/market-movers.job.js';

const PORT = config.port;

// Initialize scheduled jobs
const priceUpdateJob = new PriceUpdateJob();
const alertProcessorJob = new AlertProcessorJob();
const marketMoversJob = new MarketMoversJob();

// Start jobs
priceUpdateJob.start();
alertProcessorJob.start();
marketMoversJob.start();

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${config.nodeEnv}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
