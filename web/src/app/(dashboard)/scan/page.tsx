'use client';

import { useState } from 'react';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/client';
import { CameraCapture } from '@/components/CameraCapture';
import { SearchIcon, PokeballIcon } from '@/components/icons';

const POKETRACE_KEY = process.env.NEXT_PUBLIC_POKETRACE_API_KEY;

interface Identification {
  name: string | null;
  set: string | null;
  cardNumber: string | null;
  variant: string | null;
  confidence: 'high' | 'medium' | 'low' | 'none';
  reasoning: string;
}

interface DisplayCard {
  id: string;
  poketraceId: string;
  name: string;
  setId: string;
  setName: string;
  number: string;
  variant: string;
  rarity: string | null;
  imageSmall: string;
  imageLarge: string;
  price: number;
  priceSource: string;
}

interface PokeTraceDetail {
  data: {
    prices?: {
      tcgplayer?: Record<string, { avg: number }>;
      ebay?: Record<string, { avg: number }>;
    };
  };
}

function extractPrice(detail: PokeTraceDetail['data']): { price: number; source: string } {
  const tcg = detail.prices?.tcgplayer;
  const ebay = detail.prices?.ebay;

  if (tcg?.NEAR_MINT?.avg) return { price: tcg.NEAR_MINT.avg, source: 'TCGPlayer' };
  if (tcg?.LIGHTLY_PLAYED?.avg) return { price: tcg.LIGHTLY_PLAYED.avg, source: 'TCGPlayer' };
  if (ebay?.NEAR_MINT?.avg) return { price: ebay.NEAR_MINT.avg, source: 'eBay' };
  if (ebay?.LIGHTLY_PLAYED?.avg) return { price: ebay.LIGHTLY_PLAYED.avg, source: 'eBay' };

  if (tcg) {
    const first = Object.values(tcg).find(v => v.avg > 0);
    if (first) return { price: first.avg, source: 'TCGPlayer' };
  }
  if (ebay) {
    const first = Object.values(ebay).find(v => v.avg > 0);
    if (first) return { price: first.avg, source: 'eBay' };
  }

  return { price: 0, source: '' };
}

type Phase = 'idle' | 'preview' | 'identifying' | 'searching' | 'results' | 'error';

export default function ScanPage() {
  const [phase, setPhase] = useState<Phase>('idle');
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [identification, setIdentification] = useState<Identification | null>(null);
  const [results, setResults] = useState<DisplayCard[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [addingCard, setAddingCard] = useState<string | null>(null);
  const [addedCards, setAddedCards] = useState<Set<string>>(new Set());
  const supabase = createClient();

  const handleCapture = async (base64: string, mimeType: string) => {
    setImagePreview(`data:${mimeType};base64,${base64}`);
    setPhase('identifying');
    setError(null);
    setIdentification(null);
    setResults([]);

    try {
      // Step 1: Send to Claude Vision API
      const identifyRes = await fetch('/api/scan/identify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ image: base64, mimeType }),
      });

      if (!identifyRes.ok) {
        const err = await identifyRes.json();
        throw new Error(err.error || 'Failed to identify card');
      }

      const id: Identification = await identifyRes.json();
      setIdentification(id);

      if (id.confidence === 'none' || !id.name) {
        setPhase('error');
        setError('Could not identify a Pokemon card. Try again with a clearer photo.');
        return;
      }

      // Step 2: Search PokeTrace for the identified card
      setPhase('searching');
      const searchRes = await fetch(
        `https://api.poketrace.com/v1/cards?search=${encodeURIComponent(id.name)}&limit=20`,
        { headers: { 'X-API-Key': POKETRACE_KEY || '' } }
      );
      const searchData = await searchRes.json();
      const cards = searchData.data || [];

      if (cards.length === 0) {
        setPhase('error');
        setError(`Identified as "${id.name}" but no matching cards found in price database.`);
        return;
      }

      // Step 3: Build display cards, prioritize matches by card number
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let displayCards: DisplayCard[] = cards.map((card: any) => ({
        id: `${card.set.slug}-${card.cardNumber}-${card.variant}`,
        poketraceId: card.id,
        name: card.name,
        setId: card.set.slug,
        setName: card.set.name,
        number: card.cardNumber,
        variant: card.variant,
        rarity: card.rarity || null,
        imageSmall: card.image,
        imageLarge: card.image,
        price: 0,
        priceSource: '',
      }));

      // If Claude identified a card number, move matching cards to the top
      if (id.cardNumber) {
        displayCards.sort((a, b) => {
          const aMatch = a.number.startsWith(id.cardNumber!) ? 0 : 1;
          const bMatch = b.number.startsWith(id.cardNumber!) ? 0 : 1;
          return aMatch - bMatch;
        });
      }

      setResults(displayCards);
      setPhase('results');

      // Step 4: Fetch prices in parallel
      const withPrices = await Promise.all(
        displayCards.map(async (card) => {
          try {
            const detailRes = await fetch(
              `https://api.poketrace.com/v1/cards/${card.poketraceId}`,
              { headers: { 'X-API-Key': POKETRACE_KEY || '' } }
            );
            const detailData = await detailRes.json();
            const { price, source } = extractPrice(detailData.data);
            return { ...card, price, priceSource: source };
          } catch {
            return card;
          }
        })
      );
      setResults(withPrices);
    } catch (err) {
      setPhase('error');
      setError(err instanceof Error ? err.message : 'Something went wrong');
    }
  };

  const addToCollection = async (card: DisplayCard) => {
    setAddingCard(card.poketraceId);

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      setError('You must be logged in to add cards');
      setAddingCard(null);
      return;
    }

    const { error: insertError } = await supabase.from('collection_cards').insert({
      user_id: user.id,
      card_id: card.poketraceId,
      name: card.name,
      set_id: card.setId,
      set_name: card.setName,
      number: card.number,
      rarity: card.rarity,
      image_small: card.imageSmall,
      image_large: card.imageLarge,
      quantity: 1,
      current_price: card.price,
    });

    if (insertError) {
      setError('Failed to add card: ' + insertError.message);
    } else {
      setAddedCards(prev => new Set(prev).add(card.poketraceId));
    }
    setAddingCard(null);
  };

  const reset = () => {
    setPhase('idle');
    setImagePreview(null);
    setIdentification(null);
    setResults([]);
    setError(null);
  };

  const confidenceColor = (c: string) => {
    switch (c) {
      case 'high': return 'bg-accent-green-dim text-accent-green';
      case 'medium': return 'bg-accent-gold-dim text-accent-gold';
      case 'low': return 'bg-accent-red-dim text-accent-red';
      default: return 'bg-bg-surface text-text-secondary';
    }
  };

  return (
    <div className="space-y-5 animate-fade-in-up">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-heading font-semibold text-text-primary">Card Scanner</h2>
        {phase !== 'idle' && (
          <button onClick={reset} className="text-sm text-accent-red font-medium btn-press">
            Scan Again
          </button>
        )}
      </div>

      {/* Idle: Show camera capture */}
      {phase === 'idle' && (
        <CameraCapture
          onCapture={handleCapture}
          isProcessing={false}
        />
      )}

      {/* Identifying: Show preview + pokeball spinner */}
      {(phase === 'identifying' || phase === 'searching') && imagePreview && (
        <div className="space-y-4">
          <div className="relative aspect-[2.5/3.5] max-w-[200px] mx-auto rounded-xl overflow-hidden">
            <Image src={imagePreview} alt="Scanned card" fill className="object-cover" unoptimized />
          </div>
          <div className="flex flex-col items-center gap-3 py-4">
            <PokeballIcon className="w-10 h-10 text-accent-red animate-pokeball-wobble" />
            <p className="text-text-secondary text-sm">
              {phase === 'identifying' ? 'Identifying card...' : 'Looking up prices...'}
            </p>
          </div>
        </div>
      )}

      {/* Identification Result */}
      {identification && identification.confidence !== 'none' && phase !== 'identifying' && (
        <div className="bg-bg-surface rounded-xl p-4 border border-border-subtle space-y-3 gradient-border animate-scale-in">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-heading font-semibold text-text-primary">Identified Card</h3>
            <span className={`text-[10px] px-2 py-1 rounded-full font-medium ${confidenceColor(identification.confidence)}`}>
              {identification.confidence.charAt(0).toUpperCase() + identification.confidence.slice(1)} Confidence
            </span>
          </div>
          <div className="space-y-1">
            <p className="text-text-primary font-medium">{identification.name}</p>
            {identification.set && (
              <p className="text-text-secondary text-xs">{identification.set}</p>
            )}
            <div className="flex gap-3 text-xs text-text-tertiary">
              {identification.cardNumber && <span>#{identification.cardNumber}</span>}
              {identification.variant && <span>{identification.variant}</span>}
            </div>
          </div>
          <p className="text-[11px] text-text-tertiary italic">{identification.reasoning}</p>
        </div>
      )}

      {/* Error */}
      {phase === 'error' && (
        <div className="space-y-4">
          {imagePreview && (
            <div className="relative aspect-[2.5/3.5] max-w-[200px] mx-auto rounded-xl overflow-hidden opacity-60">
              <Image src={imagePreview} alt="Scanned card" fill className="object-cover" unoptimized />
            </div>
          )}
          <div className="bg-accent-red-dim border border-accent-red/30 text-accent-red px-4 py-3 rounded-xl text-sm text-center">
            {error}
          </div>
          <button
            onClick={reset}
            className="w-full py-3 bg-bg-surface border border-border-subtle text-text-primary font-semibold rounded-xl btn-press"
          >
            Try Again
          </button>
        </div>
      )}

      {/* Results Grid */}
      {phase === 'results' && results.length > 0 && (
        <div>
          <p className="text-xs text-text-secondary mb-3">
            {results.length} matching cards found — select one to add:
          </p>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 stagger-children">
            {results.map((card) => (
              <div
                key={card.id}
                className="bg-bg-surface rounded-xl overflow-hidden border border-border-subtle card-holo-shimmer card-tilt animate-fade-in-up"
              >
                <div className="aspect-[2.5/3.5] relative bg-bg-surface">
                  <Image
                    src={card.imageSmall}
                    alt={card.name}
                    fill
                    className="object-cover"
                    sizes="(max-width: 640px) 50vw, (max-width: 768px) 33vw, 25vw"
                    unoptimized
                  />
                </div>
                <div className="p-3">
                  <p className="text-sm font-medium text-text-primary truncate">{card.name}</p>
                  <p className="text-[10px] text-text-secondary truncate">
                    {card.setName} &middot; {card.variant}
                  </p>
                  <div className="mt-2">
                    {card.price > 0 ? (
                      <div>
                        <span className="text-accent-gold font-semibold text-sm">
                          ${card.price.toFixed(2)}
                        </span>
                        <span className="text-[9px] text-text-tertiary ml-1">
                          {card.priceSource}
                        </span>
                      </div>
                    ) : (
                      <div className="skeleton-shimmer h-4 w-16" />
                    )}
                  </div>
                  <button
                    onClick={() => addToCollection(card)}
                    disabled={addingCard === card.poketraceId || addedCards.has(card.poketraceId)}
                    className={`btn-press w-full mt-2 text-xs px-3 py-2 rounded-lg font-medium transition-colors ${
                      addedCards.has(card.poketraceId)
                        ? 'bg-accent-red-dim text-accent-red'
                        : 'bg-accent-red/10 text-accent-red hover:bg-accent-red/20'
                    } disabled:opacity-50`}
                  >
                    {addingCard === card.poketraceId ? '...' : addedCards.has(card.poketraceId) ? 'Added' : 'Add to Collection'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Empty state info */}
      {phase === 'idle' && (
        <div className="bg-bg-surface rounded-xl p-4 border border-border-subtle">
          <h3 className="text-xs font-semibold text-text-secondary mb-2">Tips for best results</h3>
          <ul className="space-y-1.5 text-xs text-text-tertiary">
            <li className="flex items-center gap-2">
              <SearchIcon className="w-3.5 h-3.5 text-accent-gold" />
              Good lighting helps accuracy
            </li>
            <li className="flex items-center gap-2">
              <SearchIcon className="w-3.5 h-3.5 text-accent-gold" />
              Keep the card flat and centered
            </li>
            <li className="flex items-center gap-2">
              <SearchIcon className="w-3.5 h-3.5 text-accent-gold" />
              Make sure the card name is visible
            </li>
          </ul>
        </div>
      )}
    </div>
  );
}
