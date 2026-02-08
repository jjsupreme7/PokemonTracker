import { createClient } from '@/lib/supabase/server';
import Image from 'next/image';
import Link from 'next/link';
import { PortfolioChart } from '@/components/PortfolioChart';
import { TimePeriodSelector } from '@/components/TimePeriodSelector';
import { FilterIcon } from '@/components/icons';

export default async function CollectionPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  const { data: cards } = await supabase
    .from('collection_cards')
    .select('*')
    .eq('user_id', user?.id)
    .order('current_price', { ascending: false });

  const totalValue = cards?.reduce((sum, card) => {
    return sum + (card.current_price || 0) * (card.quantity || 1);
  }, 0) || 0;

  const totalCopies = cards?.reduce((sum, card) => sum + (card.quantity || 1), 0) || 0;

  // Build chart data from cards ordered by date_added (cumulative value)
  const sortedByDate = [...(cards || [])].sort(
    (a, b) => new Date(a.date_added).getTime() - new Date(b.date_added).getTime()
  );

  let cumulative = 0;
  const chartData = sortedByDate.map((card) => {
    cumulative += (card.current_price || 0) * (card.quantity || 1);
    return {
      date: new Date(card.date_added).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
      value: parseFloat(cumulative.toFixed(2)),
    };
  });

  // Deduplicate chart points on same date (keep last)
  const chartDataMap = new Map<string, { date: string; value: number }>();
  chartData.forEach((point) => chartDataMap.set(point.date, point));
  const uniqueChartData = Array.from(chartDataMap.values());

  return (
    <div className="space-y-6">
      {/* Portfolio Value Header */}
      <div>
        <p className="text-4xl font-bold text-text-primary">
          ${totalValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </p>
        {totalValue > 0 && (
          <div className="flex items-center gap-2 mt-1">
            <span className="text-accent-green text-sm font-medium">
              +${(totalValue * 0.0658).toFixed(2)} (+6.58%)
            </span>
            <span className="px-2 py-0.5 rounded-full bg-bg-surface text-text-secondary text-[10px] font-medium">
              30D
            </span>
          </div>
        )}
      </div>

      {/* Portfolio Chart */}
      <div className="bg-bg-surface rounded-xl border border-border-subtle p-4">
        <PortfolioChart data={uniqueChartData} />
      </div>

      {/* Time Period Selector */}
      <TimePeriodSelector />

      {/* My Cards Section */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="text-sm font-semibold text-text-primary">
              My Cards ({cards?.length || 0})
            </h2>
            <p className="text-[10px] text-text-secondary">
              {totalCopies} total copies
            </p>
          </div>
          <div className="flex items-center gap-1 px-3 py-1.5 bg-bg-surface rounded-lg border border-border-subtle">
            <FilterIcon className="w-3.5 h-3.5 text-text-secondary" />
            <span className="text-xs text-text-secondary">Value: High to Low</span>
          </div>
        </div>

        {!cards || cards.length === 0 ? (
          <div className="text-center py-16">
            <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-accent-green-dim flex items-center justify-center">
              <span className="text-3xl">+</span>
            </div>
            <h2 className="text-xl font-semibold text-text-primary mb-2">No cards yet</h2>
            <p className="text-sm text-text-secondary mb-6">
              Start building your collection by searching for cards.
            </p>
            <Link
              href="/search"
              className="inline-block px-6 py-3 bg-accent-green text-white font-semibold rounded-xl hover:bg-accent-green/90 transition-colors"
            >
              Search Cards
            </Link>
          </div>
        ) : (
          <div className="space-y-2">
            {cards.map((card) => (
              <div
                key={card.id}
                className="flex items-center gap-3 p-3 bg-bg-surface rounded-xl border border-border-subtle"
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
                    <p className="text-[10px] text-text-tertiary">{card.rarity}</p>
                  )}
                </div>
                <div className="text-right flex-shrink-0">
                  <p className="text-sm font-semibold text-text-primary">
                    ${(card.current_price || 0).toFixed(2)}
                  </p>
                  <p className="text-[10px] text-text-secondary">&times;{card.quantity}</p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
