import { createClient } from '@/lib/supabase/server';
import Link from 'next/link';
import { TrendUpIcon, TrendDownIcon, ChevronRightIcon } from '@/components/icons';

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  const { data: collection } = await supabase
    .from('collection_cards')
    .select('current_price, quantity, set_name')
    .eq('user_id', user?.id);

  const totalCards = collection?.reduce((sum, card) => sum + (card.quantity || 1), 0) || 0;
  const uniqueCards = collection?.length || 0;
  const totalValue = collection?.reduce((sum, card) => {
    return sum + (card.current_price || 0) * (card.quantity || 1);
  }, 0) || 0;

  // Calculate unique sets
  const uniqueSets = new Set(collection?.map(c => c.set_name).filter(Boolean)).size;

  // Estimate cards up/down (based on price thresholds for visual display)
  const cardsWithPrice = collection?.filter(c => c.current_price > 0) || [];
  const cardsUp = cardsWithPrice.filter(c => c.current_price >= 5).length;
  const cardsDown = cardsWithPrice.filter(c => c.current_price < 5).length;
  const upPercent = cardsWithPrice.length > 0 ? Math.round((cardsUp / cardsWithPrice.length) * 100) : 0;
  const downPercent = cardsWithPrice.length > 0 ? Math.round((cardsDown / cardsWithPrice.length) * 100) : 0;
  const unchangedPercent = 100 - upPercent - downPercent;

  // Fetch recent additions
  const { data: recentCards } = await supabase
    .from('collection_cards')
    .select('*')
    .eq('user_id', user?.id)
    .order('date_added', { ascending: false })
    .limit(5);

  const formatValue = (val: number) => {
    if (val >= 1000) return `$${(val / 1000).toFixed(1)}K`;
    return `$${val.toFixed(2)}`;
  };

  return (
    <div className="space-y-6 animate-fade-in-up">
      {/* Market Overview Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-heading font-bold text-text-primary">Market Overview</h1>
          <div className="flex items-center gap-2 mt-1">
            {totalCards > 0 && (
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-accent-gold-dim text-accent-gold text-xs font-medium">
                <TrendUpIcon className="w-3 h-3" />
                Tracking
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Total Tracked Value */}
      <div className="p-5 rounded-2xl bg-bg-surface gradient-border sparkle-container">
        <p className="text-xs text-text-secondary mb-1 uppercase tracking-wider">Total Tracked Value</p>
        <p className="text-4xl font-heading font-extrabold text-text-primary mb-3">
          {formatValue(totalValue)}
        </p>
        {/* Percentage Pills */}
        {totalCards > 0 && (
          <div className="flex items-center gap-2 flex-wrap">
            <span className="px-2 py-0.5 rounded-full bg-accent-green-dim text-accent-green text-xs font-medium">
              +{upPercent}%
            </span>
            <span className="px-2 py-0.5 rounded-full bg-bg-surface-hover text-text-secondary text-xs font-medium">
              {uniqueSets} sets
            </span>
            <span className="px-2 py-0.5 rounded-full bg-bg-surface-hover text-text-secondary text-xs font-medium">
              {totalCards} cards
            </span>
          </div>
        )}
      </div>

      {/* Stat Cards Grid */}
      <div className="grid grid-cols-2 gap-3 stagger-children">
        <StatCard
          color="gold"
          label="Cards Tracked"
          value={totalCards.toLocaleString()}
          sub={`${uniqueSets} sets`}
        />
        <StatCard
          color="green"
          label="Cards Up"
          value={cardsUp.toLocaleString()}
          sub={`${upPercent}% of tracked`}
        />
        <StatCard
          color="red"
          label="Cards Down"
          value={cardsDown.toLocaleString()}
          sub={`${downPercent}% of market`}
        />
        <StatCard
          color="blue"
          label="Unique Cards"
          value={uniqueCards.toLocaleString()}
          sub={`${uniqueSets} sets`}
        />
      </div>

      {/* Market Movement Bar */}
      {totalCards > 0 && (
        <div>
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-sm font-heading font-semibold text-text-primary">Market Movement</h2>
          </div>
          <div className="flex h-2 rounded-full overflow-hidden bg-bg-surface">
            {upPercent > 0 && (
              <div
                className="bg-accent-green rounded-l-full"
                style={{ width: `${upPercent}%` }}
              />
            )}
            {unchangedPercent > 0 && (
              <div
                className="bg-text-tertiary"
                style={{ width: `${unchangedPercent}%` }}
              />
            )}
            {downPercent > 0 && (
              <div
                className="bg-accent-red rounded-r-full"
                style={{ width: `${downPercent}%` }}
              />
            )}
          </div>
          <div className="flex items-center justify-between mt-2 text-[10px]">
            <span className="text-accent-green">{upPercent}% up</span>
            <span className="text-text-tertiary">{unchangedPercent}% unchanged</span>
            <span className="text-accent-red">{downPercent}% down</span>
          </div>
        </div>
      )}

      {/* Recent Additions */}
      {recentCards && recentCards.length > 0 && (
        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-heading font-semibold text-text-primary">Recent Additions</h2>
            <Link href="/collection" className="text-xs text-accent-red font-medium flex items-center gap-0.5">
              View All
              <ChevronRightIcon className="w-3 h-3" />
            </Link>
          </div>
          <div className="space-y-2 stagger-children">
            {recentCards.map((card) => (
              <div
                key={card.id}
                className="flex items-center gap-3 p-3 bg-bg-surface rounded-xl border border-border-subtle card-holo-shimmer animate-fade-in-up"
              >
                {card.image_small ? (
                  <img
                    src={card.image_small}
                    alt={card.name}
                    className="w-10 h-14 object-cover rounded"
                  />
                ) : (
                  <div className="w-10 h-14 bg-bg-primary rounded flex items-center justify-center text-text-tertiary text-sm">
                    ?
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-text-primary truncate">{card.name}</p>
                  <p className="text-xs text-text-secondary truncate">{card.set_name}</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-semibold text-accent-gold">
                    ${(card.current_price || 0).toFixed(2)}
                  </p>
                  <p className="text-xs text-text-secondary">&times;{card.quantity}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Empty State */}
      {(!recentCards || recentCards.length === 0) && (
        <div className="text-center py-16 animate-fade-in-up">
          <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-accent-gold-dim flex items-center justify-center">
            <TrendUpIcon className="w-10 h-10 text-accent-gold" />
          </div>
          <h3 className="text-xl font-heading font-semibold text-text-primary mb-2">Start Your Collection</h3>
          <p className="text-sm text-text-secondary mb-6 max-w-xs mx-auto">
            Scan your first Pokemon card or search for cards to add to your portfolio.
          </p>
          <Link
            href="/search"
            className="inline-block px-6 py-3 bg-accent-red text-white font-semibold rounded-xl btn-pokeball"
          >
            Search Cards
          </Link>
        </div>
      )}
    </div>
  );
}

function StatCard({ color, label, value, sub }: {
  color: 'gold' | 'green' | 'red' | 'blue';
  label: string;
  value: string;
  sub: string;
}) {
  const borderColor = {
    gold: 'border-l-accent-gold',
    green: 'border-l-accent-green',
    red: 'border-l-accent-red',
    blue: 'border-l-accent-blue',
  }[color];

  const textColor = {
    gold: 'text-accent-gold',
    green: 'text-accent-green',
    red: 'text-accent-red',
    blue: 'text-accent-blue',
  }[color];

  return (
    <div className={`p-4 bg-bg-surface rounded-xl border border-border-subtle border-l-4 ${borderColor} card-holo-shimmer animate-fade-in-up`}>
      <p className="text-xs text-text-secondary mb-1">{label}</p>
      <p className={`text-2xl font-heading font-bold ${textColor}`}>{value}</p>
      <p className="text-[10px] text-text-tertiary mt-0.5">{sub}</p>
    </div>
  );
}
