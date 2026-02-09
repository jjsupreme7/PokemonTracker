'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { PokeballIcon } from '@/components/icons';

export default function RegisterPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const supabase = createClient();

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    setLoading(true);

    const { error } = await supabase.auth.signUp({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setLoading(false);
    } else {
      router.push('/dashboard');
      router.refresh();
    }
  };

  return (
    <div className="py-16 animate-fade-in-up">
      {/* Logo/Header */}
      <div className="text-center mb-8">
        <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-accent-red-dim flex items-center justify-center sparkle-container animate-pokeball-catch">
          <PokeballIcon className="w-8 h-8" filled />
        </div>
        <h1 className="text-3xl font-heading font-bold text-text-primary mb-2">
          <span className="text-accent-red">Pokemon</span>{' '}
          <span className="text-accent-gold">Tracker</span>
        </h1>
        <p className="text-text-secondary">Create your account</p>
      </div>

      {/* Form */}
      <form onSubmit={handleRegister} className="space-y-4">
        {error && (
          <div className="bg-accent-red-dim border border-accent-red/30 text-accent-red px-4 py-3 rounded-xl text-sm">
            {error}
          </div>
        )}

        <div>
          <label className="block text-xs text-text-secondary mb-2">
            Email
          </label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-4 bg-bg-surface border border-border-subtle rounded-xl text-text-primary placeholder-text-tertiary focus:outline-none focus:border-accent-gold/50 transition-colors"
            required
          />
        </div>

        <div>
          <label className="block text-xs text-text-secondary mb-2">
            Password
          </label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-4 bg-bg-surface border border-border-subtle rounded-xl text-text-primary placeholder-text-tertiary focus:outline-none focus:border-accent-gold/50 transition-colors"
            required
          />
        </div>

        <div>
          <label className="block text-xs text-text-secondary mb-2">
            Confirm Password
          </label>
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className="w-full px-4 py-4 bg-bg-surface border border-border-subtle rounded-xl text-text-primary placeholder-text-tertiary focus:outline-none focus:border-accent-gold/50 transition-colors"
            required
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full py-4 bg-accent-red hover:bg-accent-red-bright text-white font-semibold rounded-xl btn-pokeball disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? (
            <PokeballIcon className="inline-block w-5 h-5 text-white animate-pokeball-spin" />
          ) : (
            'Create Account'
          )}
        </button>
      </form>

      <p className="mt-6 text-center text-text-secondary">
        Already have an account?{' '}
        <Link href="/login" className="text-accent-red font-semibold">
          Sign In
        </Link>
      </p>
    </div>
  );
}
