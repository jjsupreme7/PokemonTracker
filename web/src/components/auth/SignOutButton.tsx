'use client';

import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export function SignOutButton() {
  const router = useRouter();
  const supabase = createClient();

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  };

  return (
    <button
      onClick={handleSignOut}
      className="w-full py-3 text-[#EF4444] font-medium rounded-xl hover:bg-[#EF4444]/10 transition-colors"
    >
      Sign Out
    </button>
  );
}
