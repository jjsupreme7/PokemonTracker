'use client';

import { useEffect, useState, useCallback } from 'react';
import Image from 'next/image';
import { PokeballIcon } from './icons';

const POKETRACE_KEY = process.env.NEXT_PUBLIC_POKETRACE_API_KEY;

interface PricePoint {
  avg?: number;
  low?: number;
  high?: number;
  saleCount?: number;
}

interface PriceData {
  tcgplayer?: Record<string, PricePoint>;
  ebay?: Record<string, PricePoint>;
}

interface CardData {
  card_id: string;
  name: string;
  set_name?: string;
  number?: string;
  variant?: string;
  rarity?: string;
  image_small?: string;
  image_large?: string;
  current_price?: number;
}

interface CardPriceModalProps {
  card: CardData;
  onClose: () => void;
}

function ConditionRow({ label, point }: { label: string; point?: PricePoint }) {
  if (!point?.avg) return null;
  return (
    <div className="flex items-center justify-between gap-2">
      <span className="text-[10px] font-medium text-text-secondary w-6">{label}</span>
      <span className="text-xs font-semibold text-text-primary">
        ${point.avg.toFixed(2)}
      </span>
      <span className="text-[9px] text-text-tertiary ml-auto">
        {point.saleCount ? `${point.saleCount.toLocaleString()} sold` : ''}
      </span>
    </div>
  );
}

export function CardPriceModal({ card, onClose }: CardPriceModalProps) {
  const [prices, setPrices] = useState<PriceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchPrices() {
      try {
        const res = await fetch(
          `https://api.poketrace.com/v1/cards/${card.card_id}`,
          { headers: { 'X-API-Key': POKETRACE_KEY || '' } }
        );
        if (!res.ok) throw new Error('Failed to fetch');
        const data = await res.json();
        setPrices(data.data?.prices || null);
      } catch {
        setError('Could not load live prices');
      } finally {
        setLoading(false);
      }
    }
    fetchPrices();
  }, [card.card_id]);

  // Close on Escape key
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [onClose]);

  // Prevent body scroll when modal is open
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => { document.body.style.overflow = ''; };
  }, []);

  const handleBackdropClick = useCallback((e: React.MouseEvent) => {
    if (e.target === e.currentTarget) onClose();
  }, [onClose]);

  const tcg = prices?.tcgplayer;
  const ebay = prices?.ebay;

  // Compute best price from live data, fall back to stored price
  const bestPrice =
    tcg?.NEAR_MINT?.avg ??
    tcg?.LIGHTLY_PLAYED?.avg ??
    ebay?.NEAR_MINT?.avg ??
    ebay?.LIGHTLY_PLAYED?.avg ??
    card.current_price ??
    null;

  const totalSales =
    (tcg?.NEAR_MINT?.saleCount ?? 0) +
    (ebay?.NEAR_MINT?.saleCount ?? 0);

  return (
    <div
      className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center animate-fade-in"
      onClick={handleBackdropClick}
    >
      <div className="bg-bg-elevated rounded-t-2xl sm:rounded-2xl border border-border-subtle w-full max-w-md max-h-[90vh] overflow-y-auto animate-scale-in">
        {/* Close Button */}
        <div className="sticky top-0 z-10 flex justify-end p-3">
          <button
            onClick={onClose}
            className="btn-press w-8 h-8 flex items-center justify-center rounded-full bg-bg-surface border border-border-subtle text-text-secondary hover:text-text-primary"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="px-5 pb-6 -mt-4 space-y-5">
          {/* Card Image */}
          <div className="flex justify-center">
            <div className="relative w-44 aspect-[2.5/3.5] rounded-xl overflow-hidden shadow-lg shadow-black/40">
              {card.image_large || card.image_small ? (
                <Image
                  src={card.image_large || card.image_small || ''}
                  alt={card.name}
                  fill
                  className="object-cover"
                  sizes="176px"
                  unoptimized
                />
              ) : (
                <div className="w-full h-full bg-bg-surface flex items-center justify-center">
                  <span className="text-text-tertiary text-2xl">?</span>
                </div>
              )}
            </div>
          </div>

          {/* Live Market Price */}
          <div className="bg-bg-surface rounded-xl p-4 border border-border-subtle space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-heading font-semibold text-text-primary">Live Market Price</h3>
              {loading && (
                <PokeballIcon className="w-4 h-4 text-accent-red animate-pokeball-wobble" />
              )}
            </div>

            {loading ? (
              <div className="flex flex-col items-center gap-3 py-4">
                <PokeballIcon className="w-8 h-8 text-accent-red animate-pokeball-wobble" />
                <p className="text-xs text-text-secondary">Loading prices...</p>
              </div>
            ) : error && !prices ? (
              <div className="text-center space-y-2">
                <p className="text-3xl font-extrabold text-text-primary">
                  {card.current_price ? `$${card.current_price.toFixed(2)}` : 'N/A'}
                </p>
                <p className="text-[10px] text-text-tertiary">{error}</p>
              </div>
            ) : (
              <>
                {/* Best Price */}
                <div className="text-center">
                  <p className="text-3xl font-extrabold text-accent-gold">
                    {bestPrice !== null ? `$${bestPrice.toFixed(2)}` : 'N/A'}
                  </p>
                </div>

                {/* TCGPlayer + eBay Columns */}
                {(tcg || ebay) && (
                  <div className="flex gap-4">
                    {/* TCGPlayer */}
                    <div className="flex-1 space-y-2">
                      <p className="text-[10px] font-semibold text-accent-blue text-center">TCGPlayer</p>
                      <div className="space-y-1.5">
                        <ConditionRow label="NM" point={tcg?.NEAR_MINT} />
                        <ConditionRow label="LP" point={tcg?.LIGHTLY_PLAYED} />
                        <ConditionRow label="MP" point={tcg?.MODERATELY_PLAYED} />
                      </div>
                    </div>

                    {/* Divider */}
                    <div className="w-px bg-border-subtle" />

                    {/* eBay */}
                    <div className="flex-1 space-y-2">
                      <p className="text-[10px] font-semibold text-accent-green text-center">eBay Sold</p>
                      <div className="space-y-1.5">
                        <ConditionRow label="NM" point={ebay?.NEAR_MINT} />
                        <ConditionRow label="LP" point={ebay?.LIGHTLY_PLAYED} />
                        <ConditionRow label="MP" point={ebay?.MODERATELY_PLAYED} />
                      </div>
                    </div>
                  </div>
                )}

                {/* Total Sales */}
                {totalSales > 0 && (
                  <p className="text-[10px] text-text-tertiary text-center">
                    Based on {totalSales.toLocaleString()} NM sales
                  </p>
                )}
              </>
            )}
          </div>

          {/* Card Details */}
          <div className="bg-bg-surface rounded-xl p-4 border border-border-subtle space-y-3">
            <h3 className="text-sm font-heading font-semibold text-text-primary">Card Details</h3>
            <div className="space-y-2">
              {card.set_name && (
                <div className="flex justify-between">
                  <span className="text-xs text-text-secondary">Set</span>
                  <span className="text-xs text-text-primary">{card.set_name}</span>
                </div>
              )}
              {card.number && (
                <div className="flex justify-between">
                  <span className="text-xs text-text-secondary">Number</span>
                  <span className="text-xs text-text-primary">#{card.number}</span>
                </div>
              )}
              {card.variant && (
                <div className="flex justify-between">
                  <span className="text-xs text-text-secondary">Variant</span>
                  <span className="text-xs text-text-primary">{card.variant}</span>
                </div>
              )}
              {card.rarity && (
                <div className="flex justify-between">
                  <span className="text-xs text-text-secondary">Rarity</span>
                  <span className="text-xs text-accent-gold">{card.rarity}</span>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
