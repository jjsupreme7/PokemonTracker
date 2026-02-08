import { Response } from 'express';
import { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import type { AuthenticatedRequest } from '../types/index.js';

const createAlertSchema = z.object({
  card_id: z.string().min(1),
  card_name: z.string().min(1),
  target_price: z.number().positive(),
  alert_type: z.enum(['above', 'below']),
});

const updateAlertSchema = z.object({
  target_price: z.number().positive().optional(),
  alert_type: z.enum(['above', 'below']).optional(),
  is_active: z.boolean().optional(),
});

export class AlertsController {
  // GET /api/alerts
  async getAlerts(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const activeOnly = req.query.active === 'true';

    let query = supabaseAdmin
      .from('price_alerts')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    const { data, error } = await query;

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ data });
  }

  // POST /api/alerts
  async createAlert(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const validation = createAlertSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const alertData = validation.data;

    // Check if similar alert already exists
    const { data: existing } = await supabaseAdmin
      .from('price_alerts')
      .select('id')
      .eq('user_id', userId)
      .eq('card_id', alertData.card_id)
      .eq('alert_type', alertData.alert_type)
      .eq('is_active', true)
      .single();

    if (existing) {
      res.status(409).json({
        error: 'An active alert of this type already exists for this card',
      });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('price_alerts')
      .insert({
        user_id: userId,
        ...alertData,
      })
      .select()
      .single();

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(201).json({ data });
  }

  // PUT /api/alerts/:alertId
  async updateAlert(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { alertId } = req.params;
    const validation = updateAlertSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('price_alerts')
      .update(validation.data)
      .eq('id', alertId)
      .eq('user_id', userId)
      .select()
      .single();

    if (error) {
      res.status(404).json({ error: 'Alert not found' });
      return;
    }

    res.json({ data });
  }

  // DELETE /api/alerts/:alertId
  async deleteAlert(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { alertId } = req.params;

    const { error } = await supabaseAdmin
      .from('price_alerts')
      .delete()
      .eq('id', alertId)
      .eq('user_id', userId);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(204).send();
  }
}
