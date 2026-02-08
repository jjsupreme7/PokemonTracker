import { Request, Response } from 'express';
import { z } from 'zod';
import { supabase, supabaseAdmin } from '../config/supabase.js';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  username: z.string().min(3).max(30).optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export class AuthController {
  // POST /api/auth/register
  async register(req: Request, res: Response): Promise<void> {
    const validation = registerSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const { email, password, username } = validation.data;

    // Check if username is taken (if provided)
    if (username) {
      const { data: existingUser } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();

      if (existingUser) {
        res.status(409).json({ error: 'Username already taken' });
        return;
      }
    }

    // Create user in Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
    });

    if (authError) {
      res.status(400).json({ error: authError.message });
      return;
    }

    if (!authData.user) {
      res.status(500).json({ error: 'Failed to create user' });
      return;
    }

    // Create profile
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .insert({
        id: authData.user.id,
        username: username || null,
        display_name: username || email.split('@')[0],
      });

    if (profileError) {
      console.error('Profile creation error:', profileError);
      // Don't fail the registration - profile will be created on first access
    }

    res.status(201).json({
      user: {
        id: authData.user.id,
        email: authData.user.email,
      },
      session: authData.session,
    });
  }

  // POST /api/auth/login
  async login(req: Request, res: Response): Promise<void> {
    const validation = loginSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({ error: 'Validation error', details: validation.error.errors });
      return;
    }

    const { email, password } = validation.data;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    res.json({
      user: {
        id: data.user.id,
        email: data.user.email,
      },
      session: data.session,
    });
  }

  // POST /api/auth/logout
  async logout(req: Request, res: Response): Promise<void> {
    const authHeader = req.headers.authorization;

    if (authHeader?.startsWith('Bearer ')) {
      // Sign out in Supabase
      await supabase.auth.signOut();
    }

    res.status(204).send();
  }

  // POST /api/auth/refresh
  async refresh(req: Request, res: Response): Promise<void> {
    const { refresh_token } = req.body;

    if (!refresh_token) {
      res.status(400).json({ error: 'refresh_token required' });
      return;
    }

    const { data, error } = await supabase.auth.refreshSession({
      refresh_token,
    });

    if (error) {
      res.status(401).json({ error: 'Invalid refresh token' });
      return;
    }

    res.json({
      session: data.session,
    });
  }
}
