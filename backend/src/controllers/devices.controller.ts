import { Response } from 'express';
import { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import type { AuthenticatedRequest } from '../types/index.js';

const registerDeviceSchema = z.object({
  token: z.string().min(1),
  platform: z.enum(['ios', 'android']).default('ios'),
});

export class DevicesController {
  // POST /api/devices/register
  async registerDevice(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const validation = registerDeviceSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const { token, platform } = validation.data;

    // Upsert the device token
    const { data, error } = await supabaseAdmin
      .from('device_tokens')
      .upsert(
        {
          user_id: userId,
          token,
          platform,
          is_active: true,
          created_at: new Date().toISOString(),
        },
        {
          onConflict: 'token',
        }
      )
      .select()
      .single();

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(201).json({ data });
  }

  // DELETE /api/devices/:token
  async unregisterDevice(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { token } = req.params;

    // Mark as inactive rather than deleting
    const { error } = await supabaseAdmin
      .from('device_tokens')
      .update({ is_active: false })
      .eq('user_id', userId)
      .eq('token', token);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(204).send();
  }

  // GET /api/devices
  async getDevices(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;

    const { data, error } = await supabaseAdmin
      .from('device_tokens')
      .select('id, platform, is_active, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ data });
  }
}
