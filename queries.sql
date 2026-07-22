-- ============================================================
-- UAS PEMROGRAMAN BASIS DATA (ST116)
-- File: queries.sql
-- Database: uas
-- Berisi: Function, Procedure, Trigger, Index, View, Security
-- ============================================================

USE uas;

-- ============================================================
-- SOAL 2a: FUNCTION (2 buah)
-- ============================================================

-- FUNCTION 1: Tanpa parameter
-- Menghitung total pemasukan (income) dari semua transaksi
-- Menggunakan JOIN ke tabel users untuk menampilkan siapa yang input
DELIMITER //
CREATE FUNCTION GetTotalIncome()
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(12,2);
    SELECT COALESCE(SUM(t.amount), 0) INTO total
    FROM transactions t
    JOIN users u ON t.user_id = u.id
    WHERE t.is_income = 1 AND t.status = 'Success';
    RETURN total;
END //
DELIMITER ;

-- FUNCTION 2: Dengan 2 parameter
-- Menghitung total pengeluaran berdasarkan user_id dan bulan
-- Menggunakan subquery untuk filter
DELIMITER //
CREATE FUNCTION GetExpenseByUserAndMonth(p_user_id INT, p_month VARCHAR(7))
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(12,2);
    SELECT COALESCE(SUM(amount), 0) INTO total
    FROM transactions
    WHERE user_id = p_user_id
    AND is_income = 0
    AND status = 'Success'
    AND DATE_FORMAT(transaction_date, '%Y-%m') = p_month;
    RETURN total;
END //
DELIMITER ;

-- Eksekusi Function 1 (tanpa parameter) dengan JOIN 2 tabel
SELECT
    u.name AS user_name,
    u.role,
    COUNT(t.id) AS total_transactions,
    SUM(t.amount) AS total_amount
FROM transactions t
JOIN users u ON t.user_id = u.id
WHERE t.is_income = 1
GROUP BY u.id, u.name, u.role
ORDER BY total_amount DESC;

-- Tampilkan total income menggunakan function
SELECT GetTotalIncome() AS total_income_all;

-- Eksekusi Function 2 (dengan 2 parameter) dengan subquery
SELECT
    u.name AS user_name,
    GetExpenseByUserAndMonth(u.id, '2026-07') AS expense_juli
FROM users u
WHERE u.id IN (SELECT DISTINCT user_id FROM transactions WHERE is_income = 0)
ORDER BY expense_juli DESC;

-- Tampilkan daftar function
SELECT
    ROUTINE_NAME AS function_name,
    ROUTINE_TYPE AS type,
    DATA_TYPE AS return_type,
    ROUTINE_DEFINITION AS definition
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'uas' AND ROUTINE_TYPE = 'FUNCTION';

-- ============================================================
-- SOAL 2b: PROCEDURE (2 buah)
-- ============================================================

-- PROCEDURE 1: Tanpa parameter, dengan OUT
-- Mengambil ringkasan keuangan: total income, total expense, profit
DELIMITER //
CREATE PROCEDURE GetFinancialSummary(OUT p_total_income DECIMAL(12,2), OUT p_total_expense DECIMAL(12,2), OUT p_profit DECIMAL(12,2))
BEGIN
    -- Hitung total pemasukan
    SELECT COALESCE(SUM(amount), 0) INTO p_total_income
    FROM transactions
    WHERE is_income = 1 AND status = 'Success';

    -- Hitung total pengeluaran
    SELECT COALESCE(SUM(amount), 0) INTO p_total_expense
    FROM transactions
    WHERE is_income = 0 AND status = 'Success';

    -- Hitung profit
    SET p_profit = p_total_income - p_total_expense;
END //
DELIMITER ;

-- Eksekusi Procedure 1
CALL GetFinancialSummary(@income, @expense, @profit);
SELECT @income AS total_income, @expense AS total_expense, @profit AS profit;

-- PROCEDURE 2: Dengan 2 parameter (IN), dengan control flow IF + cursor
-- Generate laporan transaksi per user dengan kategori
DELIMITER //
CREATE PROCEDURE GenerateUserReport(IN p_user_id INT, IN p_month VARCHAR(7))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_id INT;
    DECLARE v_name VARCHAR(200);
    DECLARE v_amount DECIMAL(12,2);
    DECLARE v_is_income TINYINT;
    DECLARE v_date DATE;
    DECLARE v_user_name VARCHAR(100);
    DECLARE v_total_income DECIMAL(12,2) DEFAULT 0;
    DECLARE v_total_expense DECIMAL(12,2) DEFAULT 0;

    -- Cursor untuk ambil transaksi user di bulan tertentu
    DECLARE cur CURSOR FOR
        SELECT t.id, t.name, t.amount, t.is_income, t.transaction_date
        FROM transactions t
        WHERE t.user_id = p_user_id
        AND DATE_FORMAT(t.transaction_date, '%Y-%m') = p_month
        ORDER BY t.transaction_date;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Ambil nama user
    SELECT name INTO v_user_name FROM users WHERE id = p_user_id;

    -- Buat temporary table untuk kumpulin hasil cursor
    -- (phpMyAdmin tidak support multiple result sets dari SELECT di loop)
    DROP TEMPORARY TABLE IF EXISTS tmp_report;
    CREATE TEMPORARY TABLE tmp_report (
        id INT,
        transaction_name VARCHAR(200),
        amount DECIMAL(12,2),
        type VARCHAR(10),
        trans_date DATE
    );

    -- Buka cursor
    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_id, v_name, v_amount, v_is_income, v_date;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Control flow IF untuk pisah income/expense
        IF v_is_income = 1 THEN
            SET v_total_income = v_total_income + v_amount;
            INSERT INTO tmp_report VALUES (v_id, v_name, v_amount, 'INCOME', v_date);
        ELSE
            SET v_total_expense = v_total_expense + v_amount;
            INSERT INTO tmp_report VALUES (v_id, v_name, v_amount, 'EXPENSE', v_date);
        END IF;
    END LOOP;
    CLOSE cur;

    -- Return single result set (phpMyAdmin-friendly)
    SELECT
        id,
        transaction_name,
        amount,
        type,
        trans_date,
        v_user_name AS user_name,
        p_month AS report_month,
        v_total_income AS total_income,
        v_total_expense AS total_expense,
        (v_total_income - v_total_expense) AS net_profit
    FROM tmp_report;

    DROP TEMPORARY TABLE IF EXISTS tmp_report;
END //
DELIMITER ;

-- Eksekusi Procedure 2
CALL GenerateUserReport(1, '2026-07');

-- Tampilkan daftar procedure
SELECT
    ROUTINE_NAME AS procedure_name,
    ROUTINE_TYPE AS type,
    ROUTINE_DEFINITION AS definition
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'uas' AND ROUTINE_TYPE = 'PROCEDURE';

-- ============================================================
-- SOAL 2c: TRIGGER (2 buah)
-- ============================================================

-- TRIGGER 1: AFTER INSERT pada transactions
-- Log setiap transaksi baru ke activity_logs
DELIMITER //
CREATE TRIGGER trg_after_insert_transaction
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    INSERT INTO activity_logs (table_name, record_id, action, new_values, changed_by)
    VALUES (
        'transactions',
        NEW.id,
        'INSERT',
        CONCAT('name=', NEW.name, ', amount=', NEW.amount, ', is_income=', NEW.is_income, ', status=', NEW.status),
        CURRENT_USER()
    );
END //
DELIMITER ;

-- TRIGGER 2: BEFORE UPDATE pada products
-- Validasi harga tidak boleh negatif dan log perubahan harga
DELIMITER //
CREATE TRIGGER trg_before_update_product
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    -- Control flow: validasi harga
    IF NEW.price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Harga tidak boleh negatif';
    END IF;

    -- Log perubahan harga ke activity_logs
    IF OLD.price != NEW.price THEN
        INSERT INTO activity_logs (table_name, record_id, action, old_values, new_values, changed_by)
        VALUES (
            'products',
            NEW.id,
            'UPDATE',
            CONCAT('price=', OLD.price),
            CONCAT('price=', NEW.price),
            CURRENT_USER()
        );
    END IF;
END //
DELIMITER ;

-- Eksekusi TRIGGER 1: INSERT transaksi baru
INSERT INTO transactions (user_id, product_id, name, category, amount, is_income, status, transaction_date, platform, variant_size, notes)
VALUES (1, 1, 'Penjualan Kaos Test Trigger', 'Penjualan Produk', 89000, 1, 'Success', '2026-07-20', 'Shopee', 'M', 'Test trigger insert');

-- Cek log
SELECT * FROM activity_logs WHERE table_name = 'transactions' ORDER BY changed_at DESC LIMIT 5;

-- Eksekusi TRIGGER 2: UPDATE harga produk
UPDATE products SET price = 95000 WHERE id = 1;

-- Cek log
SELECT * FROM activity_logs WHERE table_name = 'products' ORDER BY changed_at DESC LIMIT 5;

-- Test validasi harga negatif (harus error)
-- UPDATE products SET price = -1000 WHERE id = 1;
-- Error: Harga tidak boleh negatif

-- Tampilkan daftar trigger
SELECT
    TRIGGER_NAME AS trigger_name,
    EVENT_MANIPULATION AS event,
    EVENT_OBJECT_TABLE AS table_name,
    ACTION_TIMING AS timing,
    ACTION_STATEMENT AS definition
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'uas';

-- ============================================================
-- SOAL 2d: INDEX (3 buah)
-- ============================================================

-- INDEX 1: Composite key pada transactions (user_id + transaction_date)
-- Untuk mempercepat query yang filter berdasarkan user dan tanggal
CREATE INDEX idx_transactions_user_date ON transactions (user_id, transaction_date);

-- INDEX 2: Composite key pada transactions (is_income + status + transaction_date)
-- Untuk mempercepat query yang filter berdasarkan income/expense + status + tanggal
CREATE INDEX idx_transactions_income_status_date ON transactions (is_income, status, transaction_date);

-- INDEX 3: Composite key pada products (category_id + price)
-- Untuk mempercepat query yang filter berdasarkan kategori dan harga
ALTER TABLE products ADD INDEX idx_products_category_price (category_id, price);

-- Test EXPLAIN tanpa index (simulasi: disable index sementara)
-- MySQL/MariaDB tidak bisa disable index per query, jadi kita bandingkan dengan FORCE INDEX

-- Query dengan index (menggunakan idx_transactions_user_date)
EXPLAIN
SELECT * FROM transactions
WHERE user_id = 1 AND transaction_date BETWEEN '2026-07-01' AND '2026-07-31';

-- Query dengan index (menggunakan idx_transactions_income_status_date)
EXPLAIN
SELECT * FROM transactions
WHERE is_income = 1 AND status = 'Success' AND transaction_date >= '2026-07-01';

-- Query dengan index (menggunakan idx_products_category_price)
EXPLAIN
SELECT * FROM products
WHERE category_id = 1 AND price > 100000;

-- Query tanpa index (full table scan, untuk perbandingan)
EXPLAIN
SELECT * FROM transactions IGNORE INDEX (idx_transactions_user_date, idx_transactions_income_status_date)
WHERE user_id = 1 AND transaction_date BETWEEN '2026-07-01' AND '2026-07-31';

-- Tampilkan daftar index
SELECT
    TABLE_NAME AS table_name,
    INDEX_NAME AS index_name,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns,
    INDEX_TYPE AS type,
    NON_UNIQUE AS non_unique
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'uas'
GROUP BY TABLE_NAME, INDEX_NAME, INDEX_TYPE, NON_UNIQUE;

-- ============================================================
-- SOAL 2e: VIEW (3 buah)
-- ============================================================

-- VIEW 1: Horizontal View (filter baris)
-- Menampilkan hanya transaksi yang sukses
CREATE VIEW v_success_transactions AS
SELECT
    t.id,
    t.name AS transaction_name,
    t.amount,
    t.transaction_date,
    t.platform,
    u.name AS user_name,
    p.title AS product_title
FROM transactions t
JOIN users u ON t.user_id = u.id
LEFT JOIN products p ON t.product_id = p.id
WHERE t.status = 'Success';

-- VIEW 2: Vertical View (filter kolom)
-- Menampilkan hanya kolom tertentu dari users
CREATE VIEW v_user_summary AS
SELECT
    id,
    name,
    username,
    email,
    role,
    created_at
FROM users;

-- VIEW 3: View inside View dengan WITH CHECK OPTION
-- View ini select dari v_user_summary (view 2), dengan filter role Admin
-- Karena base view (v_user_summary) updatable (single table), WITH CHECK OPTION bisa dipakai
CREATE VIEW v_admin_users AS
SELECT
    id,
    name,
    username,
    email,
    role,
    created_at
FROM v_user_summary
WHERE role = 'Admin'
WITH CHECK OPTION;

-- Eksekusi VIEW 1
SELECT * FROM v_success_transactions LIMIT 10;

-- Eksekusi VIEW 2
SELECT * FROM v_user_summary;

-- Eksekusi VIEW 3
SELECT * FROM v_admin_users;

-- Test UPDATE via VIEW 1 (harus bisa)
UPDATE v_success_transactions SET platform = 'Shopee' WHERE id = 1;

-- Test INSERT via VIEW 2 (harus bisa)
INSERT INTO v_user_summary (name, username, email, role) VALUES ('Test User', 'test_user', 'test@waveneap.com', 'Staff Packing');

-- Test INSERT via VIEW 3 dengan WITH CHECK OPTION
-- Insert role Admin (harus berhasil, karena memenuhi check option)
INSERT INTO v_admin_users (name, username, email, role) VALUES ('Admin Baru', 'admin_baru', 'adminbaru@waveneap.com', 'Admin');

-- Test INSERT via VIEW 3 dengan role non-Admin (harus error karena CHECK OPTION)
-- INSERT INTO v_admin_users (name, username, email, role) VALUES ('Kasir Baru', 'kasir_baru', 'kasirbaru@waveneap.com', 'Kasir');
-- Error: CHECK OPTION failed 'uas.v_admin_users'

-- Tampilkan daftar view
SELECT
    TABLE_NAME AS view_name,
    VIEW_DEFINITION AS definition,
    CHECK_OPTION AS check_option,
    IS_UPDATABLE AS is_updatable
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'uas';

-- ============================================================
-- SOAL 2f: DATABASE SECURITY (3 user + 3 role)
-- ============================================================

-- Buat 3 user baru
CREATE USER IF NOT EXISTS 'admin_waveneap'@'localhost' IDENTIFIED BY 'admin123';
CREATE USER IF NOT EXISTS 'kasir_waveneap'@'localhost' IDENTIFIED BY 'kasir123';
CREATE USER IF NOT EXISTS 'staff_waveneap'@'localhost' IDENTIFIED BY 'staff123';

-- Buat 3 role
CREATE ROLE IF NOT EXISTS role_admin, role_kasir, role_staff;

-- Grant privilege ke role_admin (full access)
GRANT SELECT, INSERT, UPDATE, DELETE ON uas.* TO role_admin;
GRANT EXECUTE ON PROCEDURE uas.GetFinancialSummary TO role_admin;
GRANT EXECUTE ON PROCEDURE uas.GenerateUserReport TO role_admin;

-- Grant privilege ke role_kasir (select + insert transactions, select products)
GRANT SELECT ON uas.products TO role_kasir;
GRANT SELECT ON uas.categories TO role_kasir;
GRANT SELECT ON uas.product_variants TO role_kasir;
GRANT SELECT, INSERT ON uas.transactions TO role_kasir;
GRANT SELECT ON uas.v_success_transactions TO role_kasir;
GRANT SELECT ON uas.v_admin_users TO role_kasir;
GRANT EXECUTE ON PROCEDURE uas.GetFinancialSummary TO role_kasir;

-- Grant privilege ke role_staff (select only)
GRANT SELECT ON uas.products TO role_staff;
GRANT SELECT ON uas.categories TO role_staff;
GRANT SELECT ON uas.product_variants TO role_staff;
GRANT SELECT ON uas.v_user_summary TO role_staff;

-- Assign role ke user
GRANT role_admin TO 'admin_waveneap'@'localhost';
GRANT role_kasir TO 'kasir_waveneap'@'localhost';
GRANT role_staff TO 'staff_waveneap'@'localhost';

-- Set default role
SET DEFAULT ROLE role_admin FOR 'admin_waveneap'@'localhost';
SET DEFAULT ROLE role_kasir FOR 'kasir_waveneap'@'localhost';
SET DEFAULT ROLE role_staff FOR 'staff_waveneap'@'localhost';

-- Tampilkan daftar user
SELECT
    User AS user_name,
    Host AS host,
    Select_priv AS can_select,
    Insert_priv AS can_insert,
    Update_priv AS can_update,
    Delete_priv AS can_delete
FROM mysql.user
WHERE User LIKE '%waveneap%';

-- Tampilkan daftar role (MariaDB 10.1 uses roles_mapping: Host, User, Role)
SELECT
    CONCAT(User, '@', Host) AS assigned_to,
    Role AS role_name
FROM mysql.roles_mapping
WHERE User LIKE '%waveneap%';

-- Test privilege: login sebagai kasir dan coba akses
-- (Ini harus dijalankan di session terpisah sebagai kasir_waveneap)
-- mysql -u kasir_waveneap -p kasir123 uas

-- Query yang diizinkan untuk kasir:
-- SELECT * FROM products; -- OK
-- SELECT * FROM transactions; -- OK
-- INSERT INTO transactions (...) VALUES (...); -- OK

-- Query yang DITOLAK untuk kasir:
-- DELETE FROM products; -- ERROR: access denied
-- UPDATE users SET ...; -- ERROR: access denied

-- Tampilkan privilege detail per user/role
SELECT
    grantee AS user_or_role,
    table_schema AS db_name,
    table_name AS table_name,
    privilege_type AS privilege
FROM information_schema.TABLE_PRIVILEGES
WHERE table_schema = 'uas'
ORDER BY grantee, table_name, privilege_type;

-- Tampilkan privilege routine (procedure/function) via SHOW GRANTS
SHOW GRANTS FOR 'admin_waveneap'@'localhost';
SHOW GRANTS FOR 'kasir_waveneap'@'localhost';
SHOW GRANTS FOR 'staff_waveneap'@'localhost';

-- ============================================================
-- VERIFIKASI AKHIR: Tampilkan semua objek database
-- ============================================================

-- Semua tabel
SELECT 'TABLE' AS object_type, TABLE_NAME AS object_name
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'uas'
UNION ALL
-- Semua view
SELECT 'VIEW', TABLE_NAME
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'uas'
UNION ALL
-- Semua function
SELECT 'FUNCTION', ROUTINE_NAME
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'uas' AND ROUTINE_TYPE = 'FUNCTION'
UNION ALL
-- Semua procedure
SELECT 'PROCEDURE', ROUTINE_NAME
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'uas' AND ROUTINE_TYPE = 'PROCEDURE'
UNION ALL
-- Semua trigger
SELECT 'TRIGGER', TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'uas'
UNION ALL
-- Semua index
SELECT 'INDEX', CONCAT(TABLE_NAME, '.', INDEX_NAME)
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'uas'
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY object_type, object_name;