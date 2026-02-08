import { Request } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
  };
}

export interface CollectionCardInput {
  card_id: string;
  name: string;
  set_id: string;
  set_name: string;
  number: string;
  rarity?: string | null;
  image_small: string;
  image_large: string;
  quantity: number;
  purchase_price?: number | null;
  current_price?: number | null;
  date_added?: string;
  updated_at?: string;
}

export interface PriceAlertInput {
  card_id: string;
  card_name: string;
  target_price: number;
  alert_type: 'above' | 'below';
}

export interface SyncResult {
  inserted: number;
  updated: number;
  conflicts: SyncConflict[];
}

export interface SyncConflict {
  card_id: string;
  server_version: any;
  client_version: CollectionCardInput;
}

export interface PokemonTCGCard {
  id: string;
  name: string;
  set: {
    id: string;
    name: string;
  };
  number: string;
  rarity?: string;
  images: {
    small: string;
    large: string;
  };
  tcgplayer?: {
    prices?: {
      holofoil?: { market?: number };
      reverseHolofoil?: { market?: number };
      normal?: { market?: number };
      '1stEditionHolofoil'?: { market?: number };
    };
  };
  cardmarket?: {
    prices?: {
      trendPrice?: number;
    };
  };
}

export interface PushNotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

// Re-export database types
export * from './database.types.js';
