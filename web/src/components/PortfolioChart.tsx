'use client';

import { AreaChart, Area, ResponsiveContainer, XAxis, Tooltip } from 'recharts';

interface DataPoint {
  date: string;
  value: number;
}

export function PortfolioChart({ data }: { data: DataPoint[] }) {
  if (data.length === 0) {
    return (
      <div className="h-[200px] flex items-center justify-center text-text-tertiary text-sm">
        Add cards to see your portfolio chart
      </div>
    );
  }

  return (
    <ResponsiveContainer width="100%" height={200}>
      <AreaChart data={data} margin={{ top: 5, right: 5, left: 5, bottom: 5 }}>
        <defs>
          <linearGradient id="greenGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#22C55E" stopOpacity={0.3} />
            <stop offset="100%" stopColor="#22C55E" stopOpacity={0} />
          </linearGradient>
        </defs>
        <XAxis
          dataKey="date"
          axisLine={false}
          tickLine={false}
          tick={{ fill: '#64748B', fontSize: 11 }}
          dy={10}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: '#0D1320',
            border: '1px solid #1E293B',
            borderRadius: '8px',
            color: '#F1F5F9',
            fontSize: '13px',
          }}
          formatter={(value) => [`$${Number(value).toFixed(2)}`, 'Value']}
          labelStyle={{ color: '#64748B' }}
        />
        <Area
          type="monotone"
          dataKey="value"
          stroke="#22C55E"
          strokeWidth={2}
          fill="url(#greenGradient)"
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
