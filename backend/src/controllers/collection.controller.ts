import { Response } from 'express';
import { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import type { AuthenticatedRequest, SyncResult } from '../types/index.js';

const collectionCardSchema = z.object({
  card_id: z.string().min(1),
  name: z.string().min(1),
  set_id: z.string().min(1),
  set_name: z.string().min(1),
  number: z.string().min(1),
  rarity: z.string().nullable().optional(),
  image_small: z.string().url(),
  image_large: z.string().url(),
  quantity: z.number().int().positive().default(1),
  purchase_price: z.number().nullable().optional(),
  current_price: z.number().nullable().optional(),
});

const updateCardSchema = z.object({
  quantity: z.number().int().positive().optional(),
  purchase_price: z.number().nullable().optional(),
  current_price: z.number().nullable().optional(),
});

export class CollectionController {
  // GET /api/collection
  async getCollection(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = (page - 1) * limit;

    const { data, error, count } = await supabaseAdmin
      .from('collection_cards')
      .select('*', { count: 'exact' })
      .eq('user_id', userId)
      .order('date_added', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({
      data,
      pagination: {
        page,
        limit,
        total: count,
        totalPages: Math.ceil((count || 0) / limit),
      },
    });
  }

  // POST /api/collection
  async addCard(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const validation = collectionCardSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const cardData = validation.data;

    // Check if card already exists
    const { data: existing } = await supabaseAdmin
      .from('collection_cards')
      .select('id, quantity')
      .eq('user_id', userId)
      .eq('card_id', cardData.card_id)
      .single();

    if (existing) {
      // Update quantity
      const { data, error } = await supabaseAdmin
        .from('collection_cards')
        .update({
          quantity: existing.quantity + cardData.quantity,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id)
        .select()
        .single();

      if (error) {
        res.status(500).json({ error: error.message });
        return;
      }

      res.json({ data, merged: true });
      return;
    }

    // Insert new card
    const { data, error } = await supabaseAdmin
      .from('collection_cards')
      .insert({
        user_id: userId,
        ...cardData,
      })
      .select()
      .single();

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(201).json({ data });
  }

  // PUT /api/collection/:cardId
  async updateCard(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { cardId } = req.params;
    const validation = updateCardSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('collection_cards')
      .update({
        ...validation.data,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId)
      .eq('card_id', cardId)
      .select()
      .single();

    if (error) {
      res.status(404).json({ error: 'Card not found' });
      return;
    }

    res.json({ data });
  }

  // DELETE /api/collection/:cardId
  async removeCard(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { cardId } = req.params;

    const { error } = await supabaseAdmin
      .from('collection_cards')
      .delete()
      .eq('user_id', userId)
      .eq('card_id', cardId);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.status(204).send();
  }

  // POST /api/collection/sync
  async syncCollection(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { cards } = req.body;

    if (!Array.isArray(cards)) {
      res.status(400).json({ error: 'cards must be an array' });
      return;
    }

    const result: SyncResult = {
      inserted: 0,
      updated: 0,
      conflicts: [],
    };

    for (const card of cards) {
      const validation = collectionCardSchema.safeParse(card);
      if (!validation.success) continue;

      const cardData = validation.data;

      // Check for existing card
      const { data: existing } = await supabaseAdmin
        .from('collection_cards')
        .select('*')
        .eq('user_id', userId)
        .eq('card_id', cardData.card_id)
        .single();

      if (!existing) {
        // Insert new
        await supabaseAdmin.from('collection_cards').insert({
          user_id: userId,
          ...cardData,
        });
        result.inserted++;
      } else {
        // Compare timestamps for conflict resolution
        const serverUpdated = new Date(existing.updated_at);
        const clientUpdated = card.updated_at ? new Date(card.updated_at) : new Date(0);

        if (clientUpdated > serverUpdated) {
          // Client wins
          await supabaseAdmin
            .from('collection_cards')
            .update({
              ...cardData,
              updated_at: new Date().toISOString(),
            })
            .eq('id', existing.id);
          result.updated++;
        } else if (serverUpdated > clientUpdated) {
          // Server wins - record conflict
          result.conflicts.push({
            card_id: cardData.card_id,
            server_version: existing,
            client_version: cardData,
          });
        }
      }
    }

    res.json(result);
  }
}
