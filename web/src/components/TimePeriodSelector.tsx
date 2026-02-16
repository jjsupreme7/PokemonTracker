'use client';

import { useRouter, useSearchParams } from 'next/navigation';

const periods = [
  { label: '7D', value: '7d' },
  { label: '30D', value: '30d' },
  { label: '90D', value: '90d' },
  { label: '1Y', value: '1y' },
  { label: 'All', value: 'all' },
] as const;

export function TimePeriodSelector() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const active = searchParams.get('period') || '30d';

  const handleSelect = (value: string) => {
    const params = new URLSearchParams(searchParams.toString());
    params.set('period', value);
    router.push(`/collection?${params.toString()}`);
  };

  return (
    <div className="flex items-center gap-2">
      {periods.map((period) => (
        <button
          key={period.value}
          onClick={() => handleSelect(period.value)}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
            active === period.value
              ? 'bg-accent-red/15 text-accent-red'
              : 'text-text-secondary hover:text-text-primary hover:bg-bg-surface-hover'
          }`}
        >
          {period.label}
        </button>
      ))}
    </div>
  );
}
