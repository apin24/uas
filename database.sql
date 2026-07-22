-- ============================================================
-- UAS PEMROGRAMAN BASIS DATA (ST116)
-- Database: Waveneap Management System (Konversi dari MongoDB)
-- DBMS: MariaDB 10.1+ (MySQL compatible)
-- Engine: InnoDB (support FK, Trigger, Transaction)
-- ============================================================

DROP DATABASE IF EXISTS uas;
CREATE DATABASE uas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE uas;

-- ============================================================
-- TABEL 1: users
-- Menyimpan data user/karyawan (mirror MongoDB collection "users")
-- Relasi: 1:1 ke user_profiles, 1:N ke transactions
-- ============================================================
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    role ENUM('Admin', 'Kasir', 'Staff Packing') NOT NULL DEFAULT 'Staff Packing',
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 2: user_profiles
-- Menyimpan alamat lengkap user (relasi 1:1 ke users)
-- Di MongoDB: alamat embedded di document user, di SQL dipisah tabel sendiri
-- ============================================================
CREATE TABLE user_profiles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    address_street VARCHAR(200),
    address_city VARCHAR(100),
    address_province VARCHAR(100),
    address_postal_code VARCHAR(10),
    bio TEXT,
    avatar_url VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 3: categories
-- Kategori produk (di MongoDB cuma string field, di SQL jadi tabel sendiri)
-- Relasi: 1:N ke products
-- ============================================================
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 4: products
-- Menyimpan data produk (mirror MongoDB collection "products")
-- Relasi: 1:N ke product_variants, 1:N ke transactions, N:1 ke categories
-- ============================================================
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    price DECIMAL(12,2) NOT NULL,
    description TEXT,
    image VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 5: product_variants
-- Varian ukuran + stok (di MongoDB: embedded array "variants" di document products)
-- Relasi: N:1 ke products (satu produk punya banyak varian)
-- ============================================================
CREATE TABLE product_variants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    size VARCHAR(10) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 6: transactions
-- Transaksi keuangan (mirror MongoDB collection "transactions")
-- Relasi: N:1 ke products (produk yang terjual), N:1 ke users (yang input)
-- Relasi M:N: transactions ke users via transactions.user_id
-- ============================================================
CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    is_income TINYINT(1) NOT NULL DEFAULT 0,
    status ENUM('Success', 'Pending', 'Failed') NOT NULL DEFAULT 'Pending',
    transaction_date DATE NOT NULL,
    platform VARCHAR(50),
    variant_size VARCHAR(10),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 7: user_transactions (Join Table M:N)
-- Menghubungkan user dengan transaksi (many-to-many)
-- Satu user bisa punya banyak transaksi, satu transaksi bisa di-handle banyak user
-- ============================================================
CREATE TABLE user_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    transaction_id INT NOT NULL,
    role_in_transaction ENUM('Creator', 'Approver', 'Reviewer') DEFAULT 'Creator',
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_transaction (user_id, transaction_id)
) ENGINE=InnoDB;

-- ============================================================
-- TABEL 8: activity_logs (untuk trigger demo)
-- Log semua aktivitas perubahan data
-- ============================================================
CREATE TABLE activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    action ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values TEXT,
    new_values TEXT,
    changed_by VARCHAR(50),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- SEED DATA: categories
-- ============================================================
INSERT INTO categories (name, description) VALUES
('Pakaian', 'Kategori pakaian dan fashion'),
('Hewan', 'Kategori hewan peliharaan'),
('Pangan Kambing', 'Kategori pakan ternak kambing'),
('Aksesoris', 'Kategori aksesoris dan pelengkap'),
('Elektronik', 'Kategori barang elektronik'),
('Sepatu', 'Kategori sepatu dan alas kaki'),
('Tas', 'Kategori tas dan dompet'),
('Perawatan', 'Kategori produk perawatan tubuh'),
('Olahraga', 'Kategori peralatan olahraga'),
('Buku', 'Kategori buku dan literatur');

-- ============================================================
-- SEED DATA: users (10 rows)
-- ============================================================
INSERT INTO users (name, username, email, phone, role, password) VALUES
('Ilham Arifin', 'ilham_admin', 'ilham@waveneap.com', '081234567801', 'Admin', 'admin123'),
('Muh Alfin Fauzi', 'alfin_kasir', 'alfin@waveneap.com', '081234567802', 'Kasir', 'kasir123'),
('Moh Zaxlee Boneno', 'zaxlee_staff', 'zaxlee@waveneap.com', '081234567803', 'Staff Packing', 'staff123'),
('Nabil Q Ahmad', 'nabil_admin', 'nabil@waveneap.com', '081234567804', 'Admin', 'admin123'),
('Budi Santoso', 'budi_kasir', 'budi@waveneap.com', '081234567805', 'Kasir', 'kasir123'),
('Siti Rahayu', 'siti_staff', 'siti@waveneap.com', '081234567806', 'Staff Packing', 'password123'),
('Andi Wijaya', 'andi_kasir', 'andi@waveneap.com', '081234567807', 'Kasir', 'password123'),
('Dewi Lestari', 'dewi_staff', 'dewi@waveneap.com', '081234567808', 'Staff Packing', 'password123'),
('Rizky Pratama', 'rizky_kasir', 'rizky@waveneap.com', '081234567809', 'Kasir', 'password123'),
('Maya Putri', 'maya_staff', 'maya@waveneap.com', '081234567810', 'Staff Packing', 'password123');

-- ============================================================
-- SEED DATA: user_profiles (relasi 1:1 ke users)
-- ============================================================
INSERT INTO user_profiles (user_id, address_street, address_city, address_province, address_postal_code, bio) VALUES
(1, 'Jl. Padjajaran No. 123', 'Yogyakarta', 'DI Yogyakarta', '55283', 'Admin utama sistem Waveneap'),
(2, 'Jl. Gejayan No. 45', 'Yogyakarta', 'DI Yogyakarta', '55281', 'Kasir shift pagi'),
(3, 'Jl. Kaliurang KM 5 No. 12', 'Yogyakarta', 'DI Yogyakarta', '55284', 'Staff packing gudang'),
(4, 'Jl. Ring Road Utara No. 78', 'Yogyakarta', 'DI Yogyakarta', '55285', 'Admin backup'),
(5, 'Jl. Affandi No. 34', 'Yogyakarta', 'DI Yogyakarta', '55282', 'Kasir shift sore'),
(6, 'Jl. Babarsari No. 56', 'Yogyakarta', 'DI Yogyakarta', '55281', 'Staff packing'),
(7, 'Jl. Solo No. 89', 'Yogyakarta', 'DI Yogyakarta', '55284', 'Kasir weekend'),
(8, 'Jl. Maguwoharjo No. 23', 'Yogyakarta', 'DI Yogyakarta', '55282', 'Staff packing senior'),
(9, 'Jl. Seturan No. 67', 'Yogyakarta', 'DI Yogyakarta', '55281', 'Kasir part-time'),
(10, 'Jl. Depok No. 90', 'Yogyakarta', 'DI Yogyakarta', '55283', 'Staff packing baru');

-- ============================================================
-- SEED DATA: products (15 rows)
-- ============================================================
INSERT INTO products (category_id, title, price, description, image) VALUES
(1, 'Kaos Polos Premium Cotton', 89000, 'Kaos polos bahan cotton combed 30s, nyaman dan adem', 'kaos-polos.jpg'),
(1, 'Kemeja Flanel Lengan Panjang', 159000, 'Kemeja flanel motif kotak-kotak, cocok untuk casual', 'kemeja-flanel.jpg'),
(1, 'Celana Chino Slim Fit', 199000, 'Celana chino slim fit bahan stretch, nyaman dipakai', 'celana-chino.jpg'),
(2, 'Kambing Etawa Jantan', 3500000, 'Kambing etawa jantan usia 1 tahun, sehat dan terawat', 'kambing-etawa.jpg'),
(2, 'Ayam Kampung Organik', 85000, 'Ayam kampung organik, daging sehat tanpa hormon', 'ayam-kampung.jpg'),
(3, 'Pakan Kambing Fermentasi 10kg', 45000, 'Pakan kambing fermentasi kualitas premium, nutrisi lengkap', 'pakan-kambing.jpg'),
(3, 'Rumput Gajah Segar 5kg', 25000, 'Rumput gajah segar untuk pakan ternak harian', 'rumput-gajah.jpg'),
(4, 'Gelang Kulit Handmade', 55000, 'Gelang kulit asli handmade, desain unik', 'gelang-kulit.jpg'),
(4, 'Kalung Batu Alam', 75000, 'Kalung batu alam asli, energi positif', 'kalung-batu.jpg'),
(5, 'Earphone Bluetooth TWS', 299000, 'Earphone TWS dengan bass boost dan noise cancelling', 'earphone-tws.jpg'),
(6, 'Sepatu Sneakers Casual', 349000, 'Sepatu sneakers casual bahan canvas premium', 'sepatu-sneakers.jpg'),
(6, 'Sandal Gunung Outdoor', 129000, 'Sandal gunung outdoor anti slip, nyaman dipakai', 'sandal-gunung.jpg'),
(7, 'Tas Ransel Laptop 15 inch', 249000, 'Tas ransel laptop dengan banyak kompartemen', 'tas-ransel.jpg'),
(8, 'Sabun Mandi Herbal', 35000, 'Sabun mandi herbal alami, cocok untuk semua jenis kulit', 'sabun-herbal.jpg'),
(9, 'Matras Yoga Premium', 189000, 'Matras yoga tebal 8mm, anti slip, bahan TPE', 'matras-yoga.jpg');

-- ============================================================
-- SEED DATA: product_variants (relasi 1:N ke products)
-- ============================================================
INSERT INTO product_variants (product_id, size, stock) VALUES
(1, 'S', 25), (1, 'M', 50), (1, 'L', 40), (1, 'XL', 30),
(2, 'S', 15), (2, 'M', 30), (2, 'L', 25), (2, 'XL', 20),
(3, '28', 10), (3, '30', 20), (3, '32', 25), (3, '34', 15),
(4, 'All Size', 5),
(5, 'All Size', 20),
(6, 'All Size', 100),
(7, 'All Size', 150),
(8, 'All Size', 45),
(9, 'All Size', 60),
(10, 'All Size', 80),
(11, '39', 12), (11, '40', 18), (11, '41', 22), (11, '42', 15), (11, '43', 10),
(12, '39', 20), (12, '40', 25), (12, '41', 30), (12, '42', 20), (12, '43', 12),
(13, 'All Size', 35),
(14, 'All Size', 200),
(15, 'All Size', 40);

-- ============================================================
-- SEED DATA: transactions (20 rows)
-- ============================================================
INSERT INTO transactions (user_id, product_id, name, category, amount, is_income, status, transaction_date, platform, variant_size, notes) VALUES
(1, 1, 'Penjualan Kaos Polos', 'Penjualan Produk', 178000, 1, 'Success', '2026-07-01', 'Shopee', 'M', 'Terjual 2 pcs'),
(2, 2, 'Penjualan Kemeja Flanel', 'Penjualan Produk', 159000, 1, 'Success', '2026-07-01', 'Tokopedia', 'L', 'Terjual 1 pcs'),
(1, 4, 'Penjualan Kambing Etawa', 'Penjualan Produk', 3500000, 1, 'Success', '2026-07-02', 'Offline', 'All Size', 'Pembeli datang langsung'),
(3, 6, 'Penjualan Pakan Kambing', 'Penjualan Produk', 45000, 1, 'Success', '2026-07-02', 'Shopee', 'All Size', 'Repeat order'),
(2, NULL, 'Belanja Iklan Facebook', 'Jasa Iklan', 500000, 0, 'Success', '2026-07-03', 'Offline', NULL, 'Iklan FB Ads bulan Juli'),
(1, NULL, 'Gaji Karyawan Juli', 'Gaji', 8500000, 0, 'Success', '2026-07-05', 'Offline', NULL, 'Gaji 4 karyawan'),
(4, 10, 'Penjualan Earphone TWS', 'Penjualan Produk', 299000, 1, 'Success', '2026-07-05', 'Tokopedia', 'All Size', 'Best seller'),
(2, 11, 'Penjualan Sepatu Sneakers', 'Penjualan Produk', 349000, 1, 'Pending', '2026-07-06', 'Shopee', '42', 'Menunggu pembayaran'),
(3, NULL, 'Belanja Stok Kaos', 'Stok Barang', 2000000, 0, 'Success', '2026-07-07', 'Offline', NULL, 'Restock 25 pcs kaos'),
(1, 13, 'Penjualan Tas Ransel', 'Penjualan Produk', 249000, 1, 'Success', '2026-07-08', 'Tokopedia', 'All Size', 'Pembeli puas'),
(4, NULL, 'Bayar Listrik', 'Operasional', 750000, 0, 'Success', '2026-07-10', 'Offline', NULL, 'Tagihan PLN Juli'),
(2, 5, 'Penjualan Ayam Kampung', 'Penjualan Produk', 170000, 1, 'Success', '2026-07-10', 'Offline', 'All Size', 'Terjual 2 ekor'),
(3, 7, 'Penjualan Rumput Gajah', 'Penjualan Produk', 25000, 1, 'Success', '2026-07-11', 'Offline', 'All Size', 'Pelanggan tetap'),
(1, NULL, 'Belanja Kemasan', 'Stok Barang', 350000, 0, 'Success', '2026-07-12', 'Offline', NULL, 'Kardus + bubble wrap'),
(4, 8, 'Penjualan Gelang Kulit', 'Penjualan Produk', 55000, 1, 'Success', '2026-07-13', 'Shopee', 'All Size', 'Pembeli kasih review bagus'),
(2, 9, 'Penjualan Kalung Batu', 'Penjualan Produk', 75000, 1, 'Failed', '2026-07-14', 'Tokopedia', 'All Size', 'Pembayaran gagal'),
(3, NULL, 'Servis Mesin Jahit', 'Operasional', 250000, 0, 'Success', '2026-07-15', 'Offline', NULL, 'Servis rutin bulanan'),
(1, 14, 'Penjualan Sabun Herbal', 'Penjualan Produk', 70000, 1, 'Success', '2026-07-16', 'Shopee', 'All Size', 'Terjual 2 pcs'),
(2, NULL, 'Belanja Iklan Instagram', 'Jasa Iklan', 400000, 0, 'Success', '2026-07-17', 'Offline', NULL, 'Iklan IG Ads'),
(4, 15, 'Penjualan Matras Yoga', 'Penjualan Produk', 189000, 1, 'Success', '2026-07-18', 'Tokopedia', 'All Size', 'Pembeli baru');

-- ============================================================
-- SEED DATA: user_transactions (relasi M:N)
-- ============================================================
INSERT INTO user_transactions (user_id, transaction_id, role_in_transaction) VALUES
(1, 1, 'Creator'), (2, 1, 'Approver'),
(2, 2, 'Creator'), (1, 2, 'Reviewer'),
(1, 3, 'Creator'), (4, 3, 'Approver'),
(3, 4, 'Creator'), (1, 4, 'Reviewer'),
(2, 5, 'Creator'), (1, 5, 'Approver'),
(1, 6, 'Creator'), (4, 6, 'Approver'),
(4, 7, 'Creator'), (2, 7, 'Reviewer'),
(2, 8, 'Creator'), (1, 8, 'Approver'),
(3, 9, 'Creator'), (1, 9, 'Reviewer'),
(1, 10, 'Creator'), (2, 10, 'Approver'),
(4, 11, 'Creator'), (1, 11, 'Reviewer'),
(2, 12, 'Creator'), (3, 12, 'Approver'),
(3, 13, 'Creator'), (1, 13, 'Reviewer'),
(1, 14, 'Creator'), (4, 14, 'Approver'),
(4, 15, 'Creator'), (2, 15, 'Reviewer'),
(2, 16, 'Creator'), (1, 16, 'Approver'),
(3, 17, 'Creator'), (1, 17, 'Reviewer'),
(1, 18, 'Creator'), (4, 18, 'Approver'),
(2, 19, 'Creator'), (1, 19, 'Reviewer'),
(4, 20, 'Creator'), (1, 20, 'Approver');

-- ============================================================
-- SEED DATA BESAR: 5000 rows untuk indexing demo
-- Data dummy di-generate oleh Python dan disimpan di seed_large.sql
-- Import secara terpisah: mysql -u root uas < seed_large.sql
-- Atau source dari dalam MySQL: source seed_large.sql;
-- ============================================================
-- File seed_large.sql berisi 5000 INSERT ke tabel transactions
-- Tujuan: untuk demonstrasi INDEX dan EXPLAIN pada soal 2d

-- ============================================================
-- VERIFIKASI: Tampilkan jumlah rows per tabel
-- ============================================================
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'user_profiles', COUNT(*) FROM user_profiles
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'product_variants', COUNT(*) FROM product_variants
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'user_transactions', COUNT(*) FROM user_transactions
UNION ALL
SELECT 'activity_logs', COUNT(*) FROM activity_logs;