'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { HomeIcon, SearchIcon, ScanIcon, FolderIcon, UserIcon } from './icons';

const tabs = [
  { href: '/dashboard', icon: HomeIcon, label: 'Home' },
  { href: '/search', icon: SearchIcon, label: 'Search' },
  { href: '/collection', icon: FolderIcon, label: 'Collection' },
  { href: '/profile', icon: UserIcon, label: 'Profile' },
];

export function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-bg-surface border-t border-border-subtle safe-area-pb z-50">
      <div className="max-w-lg mx-auto flex items-center justify-around py-2">
        {/* First two tabs */}
        {tabs.slice(0, 2).map((tab) => {
          const isActive = pathname === tab.href;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`flex flex-col items-center gap-1 px-3 py-1 transition-colors ${
                isActive ? 'text-accent-green' : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              <tab.icon className="w-6 h-6" />
              <span className="text-[10px] font-medium">{tab.label}</span>
            </Link>
          );
        })}

        {/* Center Scan Button */}
        <Link href="/scan" className="relative -mt-6 flex flex-col items-center">
          <div className="w-14 h-14 rounded-full bg-accent-green flex items-center justify-center shadow-lg shadow-accent-green/30">
            <ScanIcon className="w-6 h-6 text-white" />
          </div>
          <span className="text-[10px] font-medium text-text-secondary mt-1">Scan</span>
        </Link>

        {/* Last two tabs */}
        {tabs.slice(2).map((tab) => {
          const isActive = pathname === tab.href;
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`flex flex-col items-center gap-1 px-3 py-1 transition-colors ${
                isActive ? 'text-accent-green' : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              <tab.icon className="w-6 h-6" />
              <span className="text-[10px] font-medium">{tab.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
