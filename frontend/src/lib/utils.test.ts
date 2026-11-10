import { test, expect } from 'vitest';
import { formatCurrency, formatDate, calculateChange, calculateProfit } from '../../lib/utils';

test('formatCurrency formats Rupiah correctly', () => {
  expect(formatCurrency(50000)).toBe('Rp 50.000');
  expect(formatCurrency(1000)).toBe('Rp 1.000');
  expect(formatCurrency(0)).toBe('Rp 0');
});

test('formatDate formats date correctly', () => {
  const date = new Date('2026-11-02T10:30:00Z');
  const formatted = formatDate(date);
  expect(formatted).toBe('2 Nov 2026');
});

test('calculateChange calculates correct change', () => {
  expect(calculateChange(50000, 100000)).toBe(50000);
  expect(calculateChange(25000, 30000)).toBe(5000);
  expect(calculateChange(10000, 10000)).toBe(0);
});

test('calculateProfit calculates correct profit', () => {
  expect(calculateProfit(10000, 5000, 2)).toBe(10000);
  expect(calculateProfit(7000, 4000, 3)).toBe(9000);
  expect(calculateProfit(5000, 5000, 1)).toBe(0);
});
