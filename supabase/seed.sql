INSERT INTO store_settings (nama_toko, alamat, kontak, footer_struk)
VALUES ('Kantin OSIS', 'Jl. Sekolah No. 1', '081234567890', 'Terima kasih telah berbelanja!');

INSERT INTO categories (nama) VALUES ('Makanan'), ('Minuman'), ('Merchandise');

INSERT INTO products (category_id, nama, harga_modal, harga_jual, stok, stok_minimum)
VALUES (1, 'Roti Bakar', 5000, 8000, 50, 10),
       (1, 'Mie Goreng', 4000, 7000, 50, 10),
       (2, 'Es Teh', 2000, 4000, 100, 20),
       (2, 'Kopi Susu', 3000, 6000, 100, 20),
       (3, 'Gantungan Kunci', 5000, 10000, 20, 5),
       (3, 'Stiker', 1000, 3000, 100, 50),
       (1, 'Siomay', 5000, 9000, 50, 10),
       (2, 'Air Mineral', 2000, 3000, 200, 50),
       (3, 'Kaos OSIS', 50000, 85000, 10, 2),
       (1, 'Batagor', 6000, 10000, 40, 10);
