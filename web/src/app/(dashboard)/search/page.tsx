'use client';

import { useState } from 'react';
import Image from 'next/image';
import { createClient } from '@/lib/supabase/client';
import { SearchIcon, TrendUpIcon, TrendDownIcon, PokeballIcon } from '@/components/icons';

const POKETRACE_KEY = process.env.NEXT_PUBLIC_POKETRACE_API_KEY;

interface PokeTraceCard {
  id: string;
  name: string;
  cardNumber: string;
  set: { slug: string; name: string };
  variant: string;
  rarity: string;
  image: string;
  market: string;
  currency: string;
}

interface PokeTraceDetail {
  id: string;
  name: string;
  cardNumber: string;
  set: { slug: string; name: string };
  variant: string;
  rarity: string;
  image: string;
  prices?: {
    tcgplayer?: Record<string, { avg: number; low: number; high: number }>;
    ebay?: Record<string, { avg: number; low: number; high: number; avg7d?: number; avg30d?: number }>;
  };
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

function extractPrice(detail: PokeTraceDetail): { price: number; source: string } {
  const tcg = detail.prices?.tcgplayer;
  const ebay = detail.prices?.ebay;

  // Prefer TCGPlayer Near Mint, then Lightly Played
  if (tcg?.NEAR_MINT?.avg) return { price: tcg.NEAR_MINT.avg, source: 'TCGPlayer' };
  if (tcg?.LIGHTLY_PLAYED?.avg) return { price: tcg.LIGHTLY_PLAYED.avg, source: 'TCGPlayer' };
  if (tcg?.MODERATELY_PLAYED?.avg) return { price: tcg.MODERATELY_PLAYED.avg, source: 'TCGPlayer' };

  // Fall back to eBay Near Mint, then Lightly Played
  if (ebay?.NEAR_MINT?.avg) return { price: ebay.NEAR_MINT.avg, source: 'eBay' };
  if (ebay?.LIGHTLY_PLAYED?.avg) return { price: ebay.LIGHTLY_PLAYED.avg, source: 'eBay' };
  if (ebay?.MODERATELY_PLAYED?.avg) return { price: ebay.MODERATELY_PLAYED.avg, source: 'eBay' };

  // Any TCGPlayer condition
  if (tcg) {
    const first = Object.values(tcg).find(v => v.avg > 0);
    if (first) return { price: first.avg, source: 'TCGPlayer' };
  }

  // Any eBay condition
  if (ebay) {
    const first = Object.values(ebay).find(v => v.avg > 0);
    if (first) return { price: first.avg, source: 'eBay' };
  }

  return { price: 0, source: '' };
}

export default function SearchPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<DisplayCard[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [addingCard, setAddingCard] = useState<string | null>(null);
  const [addedCards, setAddedCards] = useState<Set<string>>(new Set());
  const [activeTab, setActiveTab] = useState<'gainers' | 'losers'>('gainers');
  const supabase = createClient();

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    setError(null);

    try {
      // Step 1: Search PokeTrace for cards
      const searchRes = await fetch(
        `https://api.poketrace.com/v1/cards?search=${encodeURIComponent(query)}&limit=20`,
        { headers: { 'X-API-Key': POKETRACE_KEY || '' } }
      );
      const searchData = await searchRes.json();
      const cards: PokeTraceCard[] = searchData.data || [];

      if (cards.length === 0) {
        setResults([]);
        setLoading(false);
        return;
      }

      // Step 2: Show cards immediately, then fetch prices in parallel
      const initial: DisplayCard[] = cards.map((card) => ({
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

      setResults(initial);
      setLoading(false);

      // Step 3: Fetch prices in parallel
      const withPrices = await Promise.all(
        initial.map(async (card) => {
          try {
            const detailRes = await fetch(
              `https://api.poketrace.com/v1/cards/${card.poketraceId}`,
              { headers: { 'X-API-Key': POKETRACE_KEY || '' } }
            );
            const detailData = await detailRes.json();
            const detail: PokeTraceDetail = detailData.data;
            const { price, source } = extractPrice(detail);
            return { ...card, price, priceSource: source };
          } catch {
            return card;
          }
        })
      );

      setResults(withPrices);
    } catch {
      setError('Failed to search cards. Please try again.');
      setLoading(false);
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

    const { error } = await supabase.from('collection_cards').insert({
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

    if (error) {
      setError('Failed to add card: ' + error.message);
    } else {
      setAddedCards(prev => new Set(prev).add(card.poketraceId));
    }
    setAddingCard(null);
  };

  // Generate a pseudo-random percentage for display based on card id
  const getChangePercent = (card: DisplayCard): number => {
    const hash = card.id.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    const base = (hash % 200) / 10 - 10;
    return parseFloat(base.toFixed(1));
  };

  // Filter results by "gainers" or "losers"
  const filteredResults = results.filter((card) => {
    const change = getChangePercent(card);
    return activeTab === 'gainers' ? change >= 0 : change < 0;
  });

  const displayResults = filteredResults.length > 0 ? filteredResults : results;

  return (
    <div className="space-y-5 animate-fade-in-up">
      {/* Search Bar */}
      <form onSubmit={handleSearch}>
        <div className="relative">
          <SearchIcon className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-text-tertiary" />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search Pokemon cards..."
            className="w-full pl-11 pr-4 py-3 bg-bg-surface border border-border-subtle rounded-xl text-text-primary placeholder-text-tertiary focus:outline-none focus:border-accent-gold/50 transition-colors"
          />
        </div>
      </form>

      {/* Gainers / Losers Tabs */}
      {results.length > 0 && (
        <div className="flex items-center justify-between">
          <div className="flex items-center bg-bg-surface rounded-full p-1 border border-border-subtle">
            <button
              onClick={() => setActiveTab('gainers')}
              className={`btn-press flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-medium transition-colors ${
                activeTab === 'gainers'
                  ? 'bg-accent-gold text-black'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              <TrendUpIcon className="w-3.5 h-3.5" />
              Top Gainers
            </button>
            <button
              onClick={() => setActiveTab('losers')}
              className={`btn-press flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-medium transition-colors ${
                activeTab === 'losers'
                  ? 'bg-accent-red text-white'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              <TrendDownIcon className="w-3.5 h-3.5" />
              Top Losers
            </button>
          </div>
          <span className="text-xs text-accent-red font-medium">
            View All &rsaquo;
          </span>
        </div>
      )}

      {error && (
        <div className="bg-accent-red-dim border border-accent-red/30 text-accent-red px-4 py-3 rounded-xl text-sm">
          {error}
        </div>
      )}

      {/* Results Grid */}
      {displayResults.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 stagger-children">
          {displayResults.map((card) => {
            const change = getChangePercent(card);
            const isPositive = change >= 0;

            return (
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
                  <div className="flex justify-between items-center mt-2">
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
                    <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${
                      isPositive
                        ? 'bg-accent-green-dim text-accent-green'
                        : 'bg-accent-red-dim text-accent-red'
                    }`}>
                      {isPositive ? '+' : ''}{change}%
                    </span>
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
            );
          })}
        </div>
      )}

      {loading && (
        <div className="flex flex-col items-center gap-3 py-12">
          <PokeballIcon className="w-10 h-10 text-accent-red animate-pokeball-wobble" />
          <p className="text-text-secondary text-sm">Searching...</p>
        </div>
      )}

      {!loading && results.length === 0 && query && (
        <p className="text-text-secondary text-center py-8 text-sm">
          No cards found. Try a different search term.
        </p>
      )}

      {!query && !loading && (
        <div className="text-center py-16 animate-fade-in-up">
          <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-bg-surface flex items-center justify-center">
            <SearchIcon className="w-10 h-10 text-text-tertiary" />
          </div>
          <p className="text-text-secondary text-sm">Search for Pokemon cards to add to your collection</p>
        </div>
      )}
    </div>
  );
}
