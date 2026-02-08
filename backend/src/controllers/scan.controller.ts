import { Response } from 'express';
import Anthropic from '@anthropic-ai/sdk';
import type { AuthenticatedRequest } from '../types/index.js';

const CARD_PROMPT = `You are a Pokemon TCG card identification expert. Analyze this image and identify the card.

Look for:
1. The Pokemon name (printed prominently on the card)
2. The set name (usually bottom area)
3. The card number (format like "025/198", usually bottom-left or bottom-right)
4. The variant type (Holo Rare, V, VMAX, ex, Full Art, Reverse Holo, etc.)

Respond with ONLY valid JSON, no markdown formatting:
{
  "name": "Pokemon name as printed",
  "set": "Set name or null",
  "cardNumber": "Number only (e.g. '025'), or null",
  "variant": "Variant type or null",
  "confidence": "high" | "medium" | "low" | "none",
  "reasoning": "Brief explanation"
}`;

export class ScanController {
  async identify(req: AuthenticatedRequest, res: Response): Promise<void> {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      res.status(500).json({ error: 'Scanner not configured. ANTHROPIC_API_KEY is missing.' });
      return;
    }

    const { image, mimeType } = req.body as { image: string; mimeType: string };

    if (!image || !mimeType) {
      res.status(400).json({ error: 'Missing image or mimeType in request body' });
      return;
    }

    const validTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!validTypes.includes(mimeType)) {
      res.status(400).json({ error: 'Invalid image type. Supported: JPEG, PNG, GIF, WebP' });
      return;
    }

    try {
      const anthropic = new Anthropic({ apiKey });

      const message = await anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 512,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: mimeType as 'image/jpeg' | 'image/png' | 'image/gif' | 'image/webp',
                  data: image,
                },
              },
              {
                type: 'text',
                text: CARD_PROMPT,
              },
            ],
          },
        ],
      });

      const textBlock = message.content.find((block) => block.type === 'text');
      if (!textBlock || textBlock.type !== 'text') {
        res.status(500).json({ error: 'No response from card identification' });
        return;
      }

      const raw = textBlock.text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      const identification = JSON.parse(raw);

      res.json(identification);
    } catch (error) {
      console.error('Card identification error:', error);
      res.status(500).json({ error: 'Failed to identify card. Please try again.' });
    }
  }
}
