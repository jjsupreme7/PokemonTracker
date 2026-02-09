import { createClient } from '@/lib/supabase/server';
import { SignOutButton } from '@/components/auth/SignOutButton';
import { PokeballIcon, ChevronRightIcon } from '@/components/icons';

export default async function ProfilePage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user?.id)
    .single();

  return (
    <div className="space-y-6 animate-fade-in-up">
      <h1 className="text-xl font-heading font-bold text-text-primary">Profile</h1>

      <div className="space-y-3">
        {/* Profile Card */}
        <div className="p-5 bg-bg-surface rounded-xl border border-border-subtle">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-16 h-16 bg-accent-red-dim rounded-full flex items-center justify-center">
              <PokeballIcon className="w-8 h-8" filled />
            </div>
            <div>
              <p className="text-lg font-heading font-semibold text-text-primary">
                {profile?.display_name || profile?.username || 'Trainer'}
              </p>
              <p className="text-sm text-text-secondary">{user?.email}</p>
            </div>
          </div>

          <div className="space-y-0">
            <ProfileRow label="Account Tier">
              <span className="px-3 py-1 bg-accent-gold-dim text-accent-gold rounded-full text-sm font-medium capitalize">
                {profile?.tier || 'free'}
              </span>
            </ProfileRow>

            <ProfileRow label="Currency">
              <span className="text-text-primary text-sm">{profile?.preferred_currency || 'USD'}</span>
            </ProfileRow>

            <ProfileRow label="Member Since" last>
              <span className="text-text-primary text-sm">
                {profile?.created_at
                  ? new Date(profile.created_at).toLocaleDateString()
                  : 'N/A'}
              </span>
            </ProfileRow>
          </div>
        </div>

        {/* Settings Links */}
        <div className="bg-bg-surface rounded-xl border border-border-subtle overflow-hidden">
          <SettingsLink label="Notifications" />
          <SettingsLink label="Privacy" />
          <SettingsLink label="Help & Support" last />
        </div>

        {/* Sign Out */}
        <div className="p-4 bg-bg-surface rounded-xl border border-border-subtle">
          <SignOutButton />
        </div>
      </div>
    </div>
  );
}

function ProfileRow({ label, children, last }: { label: string; children: React.ReactNode; last?: boolean }) {
  return (
    <div className={`flex justify-between items-center py-3.5 ${!last ? 'border-b border-border-subtle' : ''}`}>
      <span className="text-text-secondary text-sm">{label}</span>
      {children}
    </div>
  );
}

function SettingsLink({ label, last }: { label: string; last?: boolean }) {
  return (
    <button className={`btn-press w-full flex items-center justify-between px-4 py-3.5 hover:bg-bg-surface-hover transition-colors ${!last ? 'border-b border-border-subtle' : ''}`}>
      <span className="text-text-primary text-sm">{label}</span>
      <ChevronRightIcon className="w-4 h-4 text-text-tertiary" />
    </button>
  );
}
