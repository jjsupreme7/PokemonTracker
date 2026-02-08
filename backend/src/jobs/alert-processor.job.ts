import cron from 'node-cron';
import { config } from '../config/index.js';
import { supabaseAdmin } from '../config/supabase.js';
import { NotificationService } from '../services/notification.service.js';

interface PriceAlert {
  id: string;
  user_id: string;
  card_id: string;
  card_name: string;
  target_price: number;
  alert_type: 'above' | 'below';
}

export class AlertProcessorJob {
  private notificationService = new NotificationService();
  private isRunning = false;

  start(): void {
    cron.schedule(config.jobs.alertProcessorCron, async () => {
      await this.run();
    });

    console.log(`Alert processor job scheduled: ${config.jobs.alertProcessorCron}`);
  }

  async run(): Promise<void> {
    if (this.isRunning) {
      console.log('Alert processor job already running, skipping');
      return;
    }

    this.isRunning = true;
    console.log('Starting alert processor job');

    try {
      // Get all active alerts
      const { data: alerts, error: alertError } = await supabaseAdmin
        .from('price_alerts')
        .select('*')
        .eq('is_active', true);

      if (alertError) {
        throw alertError;
      }

      if (!alerts?.length) {
        console.log('No active alerts to process');
        return;
      }

      console.log(`Processing ${alerts.length} active alerts`);

      // Get latest prices for alert cards
      const cardIds = [...new Set(alerts.map(a => a.card_id))];
      const priceMap = await this.getLatestPrices(cardIds);

      // Check each alert
      let triggered = 0;
      for (const alert of alerts as PriceAlert[]) {
        const currentPrice = priceMap.get(alert.card_id);
        if (currentPrice === undefined) continue;

        const shouldTrigger =
          (alert.alert_type === 'above' && currentPrice >= alert.target_price) ||
          (alert.alert_type === 'below' && currentPrice <= alert.target_price);

        if (shouldTrigger) {
          await this.triggerAlert(alert, currentPrice);
          triggered++;
        }
      }

      console.log(`Alert processor job completed: ${triggered} alerts triggered`);
    } catch (error) {
      console.error('Alert processor job failed:', error);
    } finally {
      this.isRunning = false;
    }
  }

  private async getLatestPrices(cardIds: string[]): Promise<Map<string, number>> {
    const priceMap = new Map<string, number>();

    const { data: prices } = await supabaseAdmin
      .from('price_history')
      .select('card_id, price')
      .in('card_id', cardIds)
      .order('recorded_at', { ascending: false });

    if (prices) {
      for (const p of prices) {
        if (!priceMap.has(p.card_id)) {
          priceMap.set(p.card_id, p.price);
        }
      }
    }

    return priceMap;
  }

  private async triggerAlert(alert: PriceAlert, currentPrice: number): Promise<void> {
    try {
      // Get user's device tokens
      const { data: tokens } = await supabaseAdmin
        .from('device_tokens')
        .select('token')
        .eq('user_id', alert.user_id)
        .eq('is_active', true);

      if (tokens?.length) {
        const direction = alert.alert_type === 'above' ? 'reached' : 'dropped to';
        const message = {
          title: 'Price Alert',
          body: `${alert.card_name} has ${direction} $${currentPrice.toFixed(2)}!`,
          data: {
            type: 'price_alert',
            cardId: alert.card_id,
            alertId: alert.id,
          },
        };

        for (const { token } of tokens) {
          await this.notificationService.sendPushNotification(token, message);
        }

        console.log(`Alert ${alert.id} triggered for user ${alert.user_id}`);
      }

      // Mark alert as triggered
      await supabaseAdmin
        .from('price_alerts')
        .update({
          is_active: false,
          triggered_at: new Date().toISOString(),
        })
        .eq('id', alert.id);
    } catch (error) {
      console.error(`Failed to trigger alert ${alert.id}:`, error);
    }
  }
}
