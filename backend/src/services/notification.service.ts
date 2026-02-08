import apn from '@parse/node-apn';
import { config } from '../config/index.js';
import type { PushNotificationPayload } from '../types/index.js';

export class NotificationService {
  private provider: apn.Provider | null = null;

  constructor() {
    // Only initialize if APNs config is present
    if (config.apns.keyPath && config.apns.keyId && config.apns.teamId) {
      try {
        this.provider = new apn.Provider({
          token: {
            key: config.apns.keyPath,
            keyId: config.apns.keyId,
            teamId: config.apns.teamId,
          },
          production: config.nodeEnv === 'production',
        });
      } catch (error) {
        console.warn('APNs provider initialization failed:', error);
      }
    } else {
      console.warn('APNs not configured - push notifications disabled');
    }
  }

  async sendPushNotification(
    deviceToken: string,
    payload: PushNotificationPayload
  ): Promise<boolean> {
    if (!this.provider) {
      console.warn('APNs provider not available');
      return false;
    }

    const notification = new apn.Notification();

    notification.alert = {
      title: payload.title,
      body: payload.body,
    };
    notification.topic = config.apns.bundleId;
    notification.sound = 'default';
    notification.badge = 1;

    if (payload.data) {
      notification.payload = payload.data;
    }

    try {
      const result = await this.provider.send(notification, deviceToken);

      if (result.failed.length > 0) {
        console.error('Push notification failed:', result.failed[0].response);
        return false;
      }

      return true;
    } catch (error) {
      console.error('Push notification error:', error);
      return false;
    }
  }

  async sendBulkNotifications(
    deviceTokens: string[],
    payload: PushNotificationPayload
  ): Promise<{ success: number; failed: number }> {
    let success = 0;
    let failed = 0;

    for (const token of deviceTokens) {
      const sent = await this.sendPushNotification(token, payload);
      if (sent) {
        success++;
      } else {
        failed++;
      }
    }

    return { success, failed };
  }

  shutdown(): void {
    if (this.provider) {
      this.provider.shutdown();
    }
  }
}
