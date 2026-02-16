import { Suspense } from 'react';
import { createClient } from '@/lib/supabase/server';
import Link from 'next/link';
import { PortfolioChart } from '@/components/PortfolioChart';
import { TimePeriodSelector } from '@/components/TimePeriodSelector';
import { CollectionCardList } from '@/components/CollectionCardList';
import { FilterIcon } from '@/components/icons';

const periodDays: Record<string, number> = {
  '7d': 7, '30d': 30, '90d': 90, '1y': 365, 'all': 3650,
};

const periodLabels: Record<string, string> = {
  '7d': '7D', '30d': '30D', '90d': '90D', '1y': '1Y', 'all': 'ALL',
};

export default async function CollectionPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string }>;
}) {
  const params = await searchParams;
  const period = params.period || '30d';
  const days = periodDays[period] || 30;

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

  // Query price_history for real portfolio change and chart data
  const cardIds = cards?.map(c => c.card_id) || [];
  let valueChange = 0;
  let changePercent = 0;
  let hasHistoricalData = false;
  let chartDataForPeriod: { date: string; value: number }[] = [];

  if (cardIds.length > 0) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const { data: priceHistory } = await supabase
      .from('price_history')
      .select('card_id, price, recorded_at')
      .in('card_id', cardIds)
      .gte('recorded_at', startDate.toISOString())
      .order('recorded_at', { ascending: true });

    if (priceHistory && priceHistory.length > 0) {
      hasHistoricalData = true;

      // Get first and last price per card within the period
      const firstPrice = new Map<string, number>();
      const lastPrice = new Map<string, number>();
      for (const entry of priceHistory) {
        if (!firstPrice.has(entry.card_id)) {
          firstPrice.set(entry.card_id, entry.price);
        }
        lastPrice.set(entry.card_id, entry.price);
      }

      // Calculate total portfolio value at start and end of period
      let totalValueThen = 0;
      let totalValueNow = 0;
      for (const card of cards || []) {
        const qty = card.quantity || 1;
        const oldPrice = firstPrice.get(card.card_id);
        const newPrice = lastPrice.get(card.card_id) ?? card.current_price ?? 0;
        totalValueNow += newPrice * qty;
        totalValueThen += (oldPrice !== undefined ? oldPrice : newPrice) * qty;
      }

      valueChange = totalValueNow - totalValueThen;
      changePercent = totalValueThen > 0
        ? ((totalValueNow - totalValueThen) / totalValueThen) * 100
        : 0;

      // Build daily portfolio value chart from price_history
      const dailyPrices = new Map<string, Map<string, number>>();
      for (const entry of priceHistory) {
        const dateKey = new Date(entry.recorded_at).toISOString().split('T')[0];
        if (!dailyPrices.has(dateKey)) {
          dailyPrices.set(dateKey, new Map());
        }
        dailyPrices.get(dateKey)!.set(entry.card_id, entry.price);
      }

      const runningPrices = new Map<string, number>();
      const sortedDates = Array.from(dailyPrices.keys()).sort();

      for (const dateStr of sortedDates) {
        const dayPrices = dailyPrices.get(dateStr)!;
        for (const [cardId, price] of dayPrices) {
          runningPrices.set(cardId, price);
        }
        let dayValue = 0;
        for (const card of cards || []) {
          const qty = card.quantity || 1;
          const price = runningPrices.get(card.card_id) ?? card.current_price ?? 0;
          dayValue += price * qty;
        }
        chartDataForPeriod.push({
          date: new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
          value: parseFloat(dayValue.toFixed(2)),
        });
      }
    }
  }

  // Fall back to card-addition-based chart if no price history
  let fallbackChartData: { date: string; value: number }[] = [];
  if (chartDataForPeriod.length < 2) {
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
    const chartDataMap = new Map<string, { date: string; value: number }>();
    chartData.forEach((point) => chartDataMap.set(point.date, point));
    fallbackChartData = Array.from(chartDataMap.values());
  }

  const finalChartData = chartDataForPeriod.length >= 2 ? chartDataForPeriod : fallbackChartData;

  return (
    <div className="space-y-6 animate-fade-in-up">
      {/* Portfolio Value Header */}
      <div>
        <p className="text-4xl font-heading font-extrabold text-text-primary">
          ${totalValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </p>
        {totalValue > 0 && hasHistoricalData && (
          <div className="flex items-center gap-2 mt-1">
            <span className={`text-sm font-medium ${changePercent >= 0 ? 'text-accent-green' : 'text-accent-red'}`}>
              {valueChange >= 0 ? '+' : '-'}${Math.abs(valueChange).toFixed(2)} ({changePercent >= 0 ? '+' : ''}{changePercent.toFixed(2)}%)
            </span>
            <span className="px-2 py-0.5 rounded-full bg-bg-surface text-text-secondary text-[10px] font-medium">
              {periodLabels[period] || '30D'}
            </span>
          </div>
        )}
      </div>

      {/* Portfolio Chart */}
      <div className="bg-bg-surface rounded-xl border border-border-subtle p-4 gradient-border">
        <PortfolioChart data={finalChartData} />
      </div>

      {/* Time Period Selector */}
      <Suspense fallback={<div className="flex items-center gap-2 h-8" />}>
        <TimePeriodSelector />
      </Suspense>

      {/* My Cards Section */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="text-sm font-heading font-semibold text-text-primary">
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
          <div className="text-center py-16 animate-fade-in-up">
            <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-accent-gold-dim flex items-center justify-center">
              <span className="text-3xl text-accent-gold">+</span>
            </div>
            <h2 className="text-xl font-heading font-semibold text-text-primary mb-2">No cards yet</h2>
            <p className="text-sm text-text-secondary mb-6">
              Start building your collection by searching for cards.
            </p>
            <Link
              href="/search"
              className="inline-block px-6 py-3 bg-accent-red text-white font-semibold rounded-xl btn-pokeball"
            >
              Search Cards
            </Link>
          </div>
        ) : (
          <CollectionCardList cards={cards} />
        )}
      </div>
    </div>
  );
}
