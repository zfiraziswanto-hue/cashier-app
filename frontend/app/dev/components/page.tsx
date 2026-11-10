import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from '@/components/ui/table';

export default function DevComponents() {
  return (
    <div className="p-8 space-y-12 max-w-5xl mx-auto">
      <section>
        <h1 className="text-3xl font-bold mb-4">Design System "Kertas & Tinta"</h1>
        <p className="text-gray-600">Font Default: IBM Plex Sans | Font Mono: IBM Plex Mono</p>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold border-b border-tinta pb-2">Buttons</h2>
        <div className="flex flex-wrap gap-4">
          <Button variant="primary">Primary (Aksi Utama)</Button>
          <Button variant="secondary">Secondary (Pinus)</Button>
          <Button variant="destructive">Destructive (Bata)</Button>
          <Button variant="outline">Outline (Border Tinta)</Button>
          <Button variant="ghost">Ghost</Button>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold border-b border-tinta pb-2">Status Badges</h2>
        <div className="flex flex-wrap gap-4">
          <Badge className="bg-sorot text-tinta border-tinta border">Pending</Badge>
          <Badge className="bg-lumut text-kertas border-tinta border">Selesai</Badge>
          <Badge className="bg-bata text-kertas border-tinta border">Batal/Void</Badge>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold border-b border-tinta pb-2">Cards</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Card className="bg-permukaan border-tinta/20 border">
            <CardContent className="pt-6">
              <CardTitle className="mb-2">Card Title</CardTitle>
              <p>Ini adalah tampilan card tanpa shadow dengan border halus 20% tinta.</p>
            </CardContent>
          </Card>
          <Card className="bg-permukaan border-pinus/20 border">
            <CardContent className="pt-6">
              <CardTitle className="mb-2">Pinus Card</CardTitle>
              <p>Ini adalah tampilan card dengan border halus 20% pinus.</p>
            </CardContent>
          </Card>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold border-b border-tinta pb-2">Form Inputs</h2>
        <div className="max-w-sm space-y-4">
          <Input placeholder="Input Teks" className="bg-permukaan border-tinta focus-visible:ring-pinus" />
          <div className="font-mono text-sm">
            <p>Font Mono untuk angka: Rp 1.250.000,00</p>
          </div>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold border-b border-tinta pb-2">Data Table</h2>
        <Table className="border-tinta border">
          <TableHeader className="bg-sorot">
            <TableRow>
              <TableHead className="text-tinta font-bold">Produk</TableHead>
              <TableHead className="text-tinta font-bold">Kategori</TableHead>
              <TableHead className="text-tinta font-bold text-right">Harga</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody className="bg-permukaan">
            <TableRow>
              <TableCell>Kopi Susu</TableCell>
              <TableCell>Minuman</TableCell>
              <TableCell className="text-right font-mono">Rp 15.000</TableCell>
            </TableRow>
            <TableRow>
              <TableCell>Roti Bakar</TableCell>
              <TableCell>Makanan</TableCell>
              <TableCell className="text-right font-mono">Rp 12.000</TableCell>
            </TableRow>
          </TableBody>
        </Table>
      </section>
    </div>
  );
}
