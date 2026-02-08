import Anthropic from '@anthropic-ai/sdk';
import { createClient } from '@/lib/supabase/server';
import { NextRequest, NextResponse } from 'next/server';

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

export async function POST(request: NextRequest) {
  // Auth check
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Validate API key exists
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: 'Scanner not configured. ANTHROPIC_API_KEY is missing.' },
      { status: 500 }
    );
  }

  // Parse request
  const body = await request.json();
  const { image, mimeType } = body as { image: string; mimeType: string };

  if (!image || !mimeType) {
    return NextResponse.json(
      { error: 'Missing image or mimeType in request body' },
      { status: 400 }
    );
  }

  const validTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
  if (!validTypes.includes(mimeType)) {
    return NextResponse.json(
      { error: 'Invalid image type. Supported: JPEG, PNG, GIF, WebP' },
      { status: 400 }
    );
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

    // Extract text response
    const textBlock = message.content.find((block) => block.type === 'text');
    if (!textBlock || textBlock.type !== 'text') {
      return NextResponse.json(
        { error: 'No response from card identification' },
        { status: 500 }
      );
    }

    // Parse JSON from Claude's response (strip any markdown code fences)
    const raw = textBlock.text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const identification = JSON.parse(raw);

    return NextResponse.json(identification);
  } catch (error) {
    console.error('Card identification error:', error);
    return NextResponse.json(
      { error: 'Failed to identify card. Please try again.' },
      { status: 500 }
    );
  }
}
