'use client';

import { useState, useEffect, useRef } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { formatCurrency } from '@/lib/utils';
import { Search, Plus, Minus, Trash2 } from 'lucide-react';

const MOCK_PRODUCTS = [
  { id: 1, nama: 'Roti Bakar', harga: 8000, stok: 50 },
  { id: 2, nama: 'Mie Goreng', harga: 7000, stok: 50 },
  { id: 3, nama: 'Es Teh Manis', harga: 4000, stok: 100 },
  { id: 4, nama: 'Kopi Susu', harga: 6000, stok: 100 },
  { id: 5, nama: 'Nasi Goreng Spesial', harga: 15000, stok: 8 },
  { id: 6, nama: 'Totebag OSIS Limited', harga: 35000, stok: 0 },
];

export default function POSPage() {
  const [cart, setCart] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [uangDiterima, setUangDiterima] = useState<number | ''>('');
  const searchInputRef = useRef<HTMLInputElement>(null);

  const subtotal = cart.reduce((acc, item) => acc + item.harga * item.qty, 0);
  const total = subtotal;
  const kembalian = typeof uangDiterima === 'number' && uangDiterima >= total ? uangDiterima - total : 0;

  const filteredProducts = MOCK_PRODUCTS.filter(p => 
    p.nama.toLowerCase().includes(search.toLowerCase())
  );

  const addToCart = (product: any) => {
    if (product.stok === 0) return;
    setCart((prev) => {
      const existing = prev.find(item => item.id === product.id);
      if (existing) {
        if (existing.qty >= product.stok) return prev;
        return prev.map(item => item.id === product.id ? { ...item, qty: item.qty + 1 } : item);
      }
      return [...prev, { ...product, qty: 1 }];
    });
  };

  const updateQty = (id: number, delta: number) => {
    setCart(prev => prev.map(item => {
      if (item.id === id) {
        const newQty = item.qty + delta;
        return newQty > 0 && newQty <= item.stok ? { ...item, qty: newQty } : item;
      }
      return item;
    }));
  };

  const removeFromCart = (id: number) => {
    setCart(prev => prev.filter(item => item.id !== id));
  };

  const handlePay = () => {
    if (cart.length === 0) return;
    if (typeof uangDiterima !== 'number' || uangDiterima < total) {
      alert('Uang diterima tidak cukup!');
      return;
    }
    alert(`Pembayaran Sukses! Kembalian: ${formatCurrency(kembalian)}`);
    setCart([]);
    setUangDiterima('');
  };

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'F2') {
        e.preventDefault();
        searchInputRef.current?.focus();
      } else if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        handlePay();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [cart, uangDiterima, total]);

  return (
    <div className="flex h-screen bg-kertas p-4 gap-4 text-tinta font-sans">
      {/* Katalog Produk */}
      <div className="flex-1 flex flex-col gap-4">
        <div className="flex gap-2 items-center bg-permukaan p-2 border border-tinta rounded-[4px]">
          <Search size={18} className="text-tinta/70" />
          <input
            ref={searchInputRef}
            type="text"
            placeholder="Cari produk... [F2]"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="flex-1 bg-transparent border-none outline-none text-sm placeholder:text-tinta/50"
          />
        </div>

        <div className="grid grid-cols-3 gap-3 overflow-y-auto pr-1">
          {filteredProducts.map((p) => {
            const isOutOfStock = p.stok === 0;
            const isLowStock = p.stok > 0 && p.stok <= 10;
            return (
              <Card 
                key={p.id} 
                onClick={() => addToCart(p)}
                className={`cursor-pointer bg-permukaan border rounded-[4px] shadow-none transition-colors relative overflow-hidden ${
                  isOutOfStock ? 'border-bata bg-bata/5' : 'border-tinta hover:border-pinus'
                }`}
              >
                <CardContent className="p-3 space-y-2">
                  <div className="flex justify-between items-start gap-1">
                    <h3 className="font-semibold text-sm line-clamp-2 leading-snug">{p.nama}</h3>
                    {isLowStock && <span className="text-[10px] bg-sorot px-1 border border-tinta font-mono">Stok {p.stok}</span>}
                  </div>
                  <div className="flex justify-between items-end pt-2">
                    <span className="font-mono font-bold text-sm text-right w-full">{formatCurrency(p.harga)}</span>
                  </div>
                  {isOutOfStock && (
                    <div className="absolute inset-0 bg-kertas/80 backdrop-blur-[1px] flex items-center justify-center border border-bata">
                      <span className="text-bata font-bold text-xs uppercase tracking-wider bg-permukaan px-2 py-1 border border-bata">Habis</span>
                    </div>
                  )}
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>

      {/* Keranjang & Kalkulasi */}
      <div className="w-96 flex flex-col gap-4">
        {/* Table Keranjang */}
        <Card className="flex-1 bg-permukaan border-tinta border rounded-[4px] shadow-none flex flex-col overflow-hidden">
          <div className="p-3 border-b border-tinta bg-sorot/30 font-semibold text-xs uppercase tracking-wider flex justify-between">
            <span>Keranjang Belanja</span>
            <span className="font-mono text-tinta/70">{cart.length} Item</span>
          </div>
          <div className="flex-1 overflow-y-auto">
            <Table>
              <TableHeader>
                <TableRow className="border-b-tinta hover:bg-transparent">
                  <TableHead className="text-tinta font-bold text-xs">Item</TableHead>
                  <TableHead className="text-tinta font-bold text-xs text-center w-20">Qty</TableHead>
                  <TableHead className="text-tinta font-bold text-xs text-right">Total</TableHead>
                  <TableHead className="w-8"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {cart.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={4} className="text-center text-tinta/50 py-8 text-xs">
                      Keranjang kosong
                    </TableCell>
                  </TableRow>
                ) : (
                  cart.map((item) => (
                    <TableRow key={item.id} className="border-b-tinta/20 hover:bg-sorot/10">
                      <TableCell className="py-2 text-xs font-medium">{item.nama}</TableCell>
                      <TableCell className="py-2 text-center">
                        <div className="flex items-center justify-center gap-1 font-mono">
                          <button onClick={(e) => { e.stopPropagation(); updateQty(item.id, -1); }} className="hover:bg-tinta/10 p-0.5 border border-tinta/30 rounded-[2px]"><Minus size={10} /></button>
                          <span className="w-5 text-center text-xs">{item.qty}</span>
                          <button onClick={(e) => { e.stopPropagation(); updateQty(item.id, 1); }} className="hover:bg-tinta/10 p-0.5 border border-tinta/30 rounded-[2px]"><Plus size={10} /></button>
                        </div>
                      </TableCell>
                      <TableCell className="py-2 text-right font-mono text-xs tabular-nums">{formatCurrency(item.harga * item.qty)}</TableCell>
                      <TableCell className="py-2 text-center">
                        <button onClick={(e) => { e.stopPropagation(); removeFromCart(item.id); }} className="text-bata hover:opacity-80"><Trash2 size={12} /></button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </Card>

        {/* Panel Kalkulasi & Bayar */}
        <div className="bg-permukaan p-4 border border-tinta rounded-[4px] space-y-3 shadow-none">
          <div className="space-y-1.5 border-b border-tinta/20 pb-3 font-mono text-xs">
            <div className="flex justify-between">
              <span className="text-tinta/70">Subtotal:</span>
              <span className="text-right tabular-nums">{formatCurrency(subtotal)}</span>
            </div>
          </div>

          <div className="flex justify-between items-baseline font-mono text-base font-bold">
            <span>Total:</span>
            <span className="text-right text-lg tabular-nums">{formatCurrency(total)}</span>
          </div>

          <div className="space-y-1 pt-1">
            <label className="text-xs font-medium text-tinta/70 block">Uang Diterima:</label>
            <input
              type="number"
              placeholder="0"
              value={uangDiterima}
              onChange={(e) => setUangDiterima(e.target.value === '' ? '' : Number(e.target.value))}
              className="w-full bg-kertas border border-tinta rounded-[4px] px-3 py-1.5 font-mono text-right text-sm outline-none focus:border-pinus"
            />
          </div>

          <div className="flex justify-between font-mono text-xs pt-1 border-t border-tinta/20">
            <span className="text-tinta/70">Kembalian:</span>
            <span className="text-right font-bold tabular-nums text-lumut">{formatCurrency(kembalian)}</span>
          </div>

          {/* SATU-SATUNYA TOMBOL KUNING */}
          <Button 
            onClick={handlePay}
            disabled={cart.length === 0}
            className="w-full bg-lampu-struk text-tinta font-bold border border-tinta hover:bg-lampu-struk/90 rounded-[4px] shadow-none h-10 text-sm mt-2"
          >
            Bayar [Ctrl + Enter]
          </Button>
        </div>
      </div>
    </div>
  );
}
