import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { BottomNav } from '@/components/BottomNav';
import { PokeballIcon, SearchIcon, MenuIcon } from '@/components/icons';

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login');
  }

  return (
    <div className="min-h-screen bg-bg-primary flex flex-col">
      {/* Top Header Bar */}
      <header className="sticky top-0 z-40 bg-bg-primary/80 backdrop-blur-xl border-b border-accent-red/10">
        <div className="max-w-7xl mx-auto flex items-center justify-between px-4 py-3">
          <Link href="/dashboard" className="flex items-center gap-2">
            <PokeballIcon className="w-7 h-7" filled />
            <span className="text-lg font-heading font-bold text-text-primary">Pokemon Tracker</span>
          </Link>
          <div className="flex items-center gap-3">
            <Link href="/search" className="btn-press p-2 rounded-lg hover:bg-bg-surface transition-colors">
              <SearchIcon className="w-5 h-5 text-text-secondary" />
            </Link>
            <button className="btn-press p-2 rounded-lg hover:bg-bg-surface transition-colors">
              <MenuIcon className="w-5 h-5 text-text-secondary" />
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 overflow-auto pb-24">
        <div className="max-w-7xl mx-auto px-4 py-4">
          {children}
        </div>
      </main>

      {/* Bottom Tab Bar */}
      <BottomNav />
    </div>
  );
}
