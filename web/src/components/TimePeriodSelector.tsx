'use client';

import { useState } from 'react';

const periods = ['7D', '30D', '90D', '1Y', 'All'] as const;

export function TimePeriodSelector() {
  const [active, setActive] = useState<string>('30D');

  return (
    <div className="flex items-center gap-2">
      {periods.map((period) => (
        <button
          key={period}
          onClick={() => setActive(period)}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
            active === period
              ? 'bg-accent-green/20 text-accent-green'
              : 'text-text-secondary hover:text-text-primary hover:bg-bg-surface-hover'
          }`}
        >
          {period}
        </button>
      ))}
    </div>
  );
}
