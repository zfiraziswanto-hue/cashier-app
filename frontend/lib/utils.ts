import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(amount: number): string {
  // Use manual formatting to avoid non-breaking space issues in tests
  const parts = amount.toString().split('').reverse();
  let result = '';
  for (let i = 0; i < parts.length; i++) {
    if (i > 0 && i % 3 === 0) result = '.' + result;
    result = parts[i] + result;
  }
  return 'Rp ' + result;
}

export function formatDate(date: string | Date): string {
  const d = new Date(date);
  return d.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

export function formatDateTime(date: string | Date): string {
  const d = new Date(date);
  return d.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

export function calculateChange(total: number, received: number): number {
  return received - total;
}

export function calculateProfit(hargaJual: number, hargaModal: number, qty: number): number {
  return (hargaJual - hargaModal) * qty;
}
