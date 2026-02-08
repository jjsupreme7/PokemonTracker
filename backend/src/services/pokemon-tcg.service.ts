import { config } from '../config/index.js';
import type { PokemonTCGCard } from '../types/index.js';

interface TCGApiResponse {
  data: PokemonTCGCard | PokemonTCGCard[];
}

export class PokemonTCGService {
  private readonly baseUrl = config.pokemonTcg.baseUrl;
  private readonly apiKey = config.pokemonTcg.apiKey;

  async getCard(id: string): Promise<PokemonTCGCard> {
    const response = await fetch(`${this.baseUrl}/cards/${id}`, {
      headers: this.getHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Pokemon TCG API error: ${response.status}`);
    }

    const data = (await response.json()) as { data: PokemonTCGCard };
    return data.data;
  }

  async searchCards(query: string, page = 1, pageSize = 20): Promise<PokemonTCGCard[]> {
    const params = new URLSearchParams({
      q: query,
      page: page.toString(),
      pageSize: pageSize.toString(),
      orderBy: '-set.releaseDate',
    });

    const response = await fetch(`${this.baseUrl}/cards?${params}`, {
      headers: this.getHeaders(),
    });

    if (!response.ok) {
      throw new Error(`Pokemon TCG API error: ${response.status}`);
    }

    const data = (await response.json()) as { data: PokemonTCGCard[] };
    return data.data;
  }

  async getCardsByIds(ids: string[]): Promise<PokemonTCGCard[]> {
    // The API supports OR queries for multiple IDs
    const query = ids.map(id => `id:${id}`).join(' OR ');
    return this.searchCards(query, 1, ids.length);
  }

  extractMarketPrice(card: PokemonTCGCard): number | null {
    const tcgPrices = card.tcgplayer?.prices;
    if (tcgPrices) {
      return (
        tcgPrices.holofoil?.market ??
        tcgPrices.reverseHolofoil?.market ??
        tcgPrices.normal?.market ??
        tcgPrices['1stEditionHolofoil']?.market ??
        null
      );
    }
    return card.cardmarket?.prices?.trendPrice ?? null;
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (this.apiKey) {
      headers['X-Api-Key'] = this.apiKey;
    }

    return headers;
  }
}
