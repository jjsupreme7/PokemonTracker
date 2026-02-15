'use client';

import { useState } from 'react';
import Image from 'next/image';
import { CardPriceModal } from './CardPriceModal';

interface CollectionCard {
  id: string;
  card_id: string;
  name: string;
  set_id?: string;
  set_name?: string;
  number?: string;
  variant?: string;
  rarity?: string;
  image_small?: string;
  image_large?: string;
  quantity: number;
  current_price?: number;
}

export function CollectionCardList({ cards }: { cards: CollectionCard[] }) {
  const [selectedCard, setSelectedCard] = useState<CollectionCard | null>(null);

  return (
    <>
      <div className="space-y-2 stagger-children">
        {cards.map((card) => (
          <div
            key={card.id}
            onClick={() => setSelectedCard(card)}
            className="flex items-center gap-3 p-3 bg-bg-surface rounded-xl border border-border-subtle card-holo-shimmer animate-fade-in-up cursor-pointer hover:bg-bg-surface-hover transition-colors"
          >
            <div className="w-12 h-16 relative flex-shrink-0 rounded overflow-hidden">
              {card.image_small ? (
                <Image
                  src={card.image_small}
                  alt={card.name}
                  fill
                  className="object-cover"
                  sizes="48px"
                />
              ) : (
                <div className="w-full h-full bg-bg-primary flex items-center justify-center">
                  <span className="text-text-tertiary text-lg">?</span>
                </div>
              )}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-text-primary truncate">{card.name}</p>
              <p className="text-xs text-text-secondary truncate">{card.set_name}</p>
              {card.rarity && (
                <p className="text-[10px] text-accent-gold">{card.rarity}</p>
              )}
            </div>
            <div className="text-right flex-shrink-0">
              <p className="text-sm font-semibold text-accent-gold">
                ${(card.current_price || 0).toFixed(2)}
              </p>
              <p className="text-[10px] text-text-secondary">&times;{card.quantity}</p>
            </div>
          </div>
        ))}
      </div>

      {selectedCard && (
        <CardPriceModal
          card={selectedCard}
          onClose={() => setSelectedCard(null)}
        />
      )}
    </>
  );
}
