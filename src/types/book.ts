export interface Book {
  id: number
  emoji: string
  title: string
  author: string
  genre: string
  status: 'done' | 'reading' | 'wish' | 'tobuy' | 'reread'
  rating: number
  review: string
  tags: string
}

export interface BookCreate {
  emoji: string
  title: string
  author: string
  genre: string
  status: 'done' | 'reading' | 'wish' | 'tobuy' | 'reread'
  rating?: number
  review?: string
  tags?: string
}

export interface Stats {
  total: number
  done: number
  reading: number
  wish: number
  tobuy: number
  reread: number
  byGenre: { genre: string; count: number }[]
}

export type SortKey = 'title' | 'rating' | 'id'
export type StatusFilter = '' | 'done' | 'reading' | 'wish' | 'tobuy' | 'reread'
