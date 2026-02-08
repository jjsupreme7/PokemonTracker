// Database types for Supabase
// These match the schema defined in supabase/migrations/20250122000000_initial_schema.sql

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: Profile;
        Insert: ProfileInsert;
        Update: ProfileUpdate;
      };
      collection_cards: {
        Row: CollectionCard;
        Insert: CollectionCardInsert;
        Update: CollectionCardUpdate;
      };
      price_history: {
        Row: PriceHistoryRecord;
        Insert: PriceHistoryInsert;
        Update: PriceHistoryUpdate;
      };
      price_alerts: {
        Row: PriceAlert;
        Insert: PriceAlertInsert;
        Update: PriceAlertUpdate;
      };
      device_tokens: {
        Row: DeviceToken;
        Insert: DeviceTokenInsert;
        Update: DeviceTokenUpdate;
      };
    };
  };
}

// Profiles
export interface Profile {
  id: string;
  username: string | null;
  display_name: string | null;
  tier: string;
  preferred_currency: string;
  created_at: string;
  updated_at: string;
}

export interface ProfileInsert {
  id: string;
  username?: string | null;
  display_name?: string | null;
  tier?: string;
  preferred_currency?: string;
}

export interface ProfileUpdate {
  username?: string | null;
  display_name?: string | null;
  tier?: string;
  preferred_currency?: string;
}

// Collection Cards
export interface CollectionCard {
  id: string;
  user_id: string;
  card_id: string;
  name: string;
  set_id: string | null;
  set_name: string | null;
  number: string | null;
  rarity: string | null;
  image_small: string | null;
  image_large: string | null;
  quantity: number;
  purchase_price: number | null;
  current_price: number | null;
  date_added: string;
  updated_at: string;
}

export interface CollectionCardInsert {
  user_id: string;
  card_id: string;
  name: string;
  set_id?: string | null;
  set_name?: string | null;
  number?: string | null;
  rarity?: string | null;
  image_small?: string | null;
  image_large?: string | null;
  quantity?: number;
  purchase_price?: number | null;
  current_price?: number | null;
}

export interface CollectionCardUpdate {
  name?: string;
  set_id?: string | null;
  set_name?: string | null;
  number?: string | null;
  rarity?: string | null;
  image_small?: string | null;
  image_large?: string | null;
  quantity?: number;
  purchase_price?: number | null;
  current_price?: number | null;
}

// Price History
export interface PriceHistoryRecord {
  id: string;
  card_id: string;
  price: number;
  price_source: string;
  recorded_at: string;
}

export interface PriceHistoryInsert {
  card_id: string;
  price: number;
  price_source?: string;
}

export interface PriceHistoryUpdate {
  price?: number;
  price_source?: string;
}

// Price Alerts
export interface PriceAlert {
  id: string;
  user_id: string;
  card_id: string;
  card_name: string;
  target_price: number;
  alert_type: 'above' | 'below';
  is_active: boolean;
  triggered_at: string | null;
  created_at: string;
}

export interface PriceAlertInsert {
  user_id: string;
  card_id: string;
  card_name: string;
  target_price: number;
  alert_type: 'above' | 'below';
  is_active?: boolean;
}

export interface PriceAlertUpdate {
  card_name?: string;
  target_price?: number;
  alert_type?: 'above' | 'below';
  is_active?: boolean;
  triggered_at?: string | null;
}

// Device Tokens
export interface DeviceToken {
  id: string;
  user_id: string;
  token: string;
  platform: 'ios' | 'android';
  is_active: boolean;
  created_at: string;
}

export interface DeviceTokenInsert {
  user_id: string;
  token: string;
  platform: 'ios' | 'android';
  is_active?: boolean;
}

export interface DeviceTokenUpdate {
  token?: string;
  platform?: 'ios' | 'android';
  is_active?: boolean;
}
