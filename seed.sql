-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Term Project: Multi-Vendor E-Commerce Marketplace
-- seed.sql  -  Sample data (run after schema.sql)
-- Author : Waqar Javed (250305023)
--
-- Explicit IDs keep the foreign keys readable; the identity sequences
-- are moved past them at the end so new rows get fresh IDs.
-- The file can be rerun: it empties every table first.
-- =====================================================================

SET search_path TO marketplace;

BEGIN;

TRUNCATE review, payment, order_item, order_header, product_variant,
         product, address, customer, seller, category
RESTART IDENTITY;

-- ---------------------------------------------------------------------
-- CATEGORY  (Books has no products yet; that is allowed)
-- ---------------------------------------------------------------------
INSERT INTO category (category_id, category_name) VALUES
    (1, 'Electronics'),
    (2, 'Home & Kitchen'),
    (3, 'Apparel'),
    (4, 'Sports & Outdoors'),
    (5, 'Books');

-- ---------------------------------------------------------------------
-- SELLER  (Metro Threads is still pending approval)
-- ---------------------------------------------------------------------
INSERT INTO seller (seller_id, business_name, contact_email, phone, approval_status) VALUES
    (1, 'Sunrise Electronics LLC', 'sales@sunrise-electronics.com', '305-555-0101', 'approved'),
    (2, 'Coastal Home Goods',      'orders@coastalhome.com',        '954-555-0144', 'approved'),
    (3, 'Peak Outfitters',         'support@peakoutfitters.com',    '786-555-0190', 'approved'),
    (4, 'Metro Threads',           'hello@metrothreads.com',        '305-555-0177', 'pending');

-- ---------------------------------------------------------------------
-- CUSTOMER  (Liam Johnson has an account but no orders yet)
-- ---------------------------------------------------------------------
INSERT INTO customer (customer_id, first_name, last_name, email, phone) VALUES
    (1, 'Pedro',  'Lopez',    'pedro.lopez@example.com',    '305-555-0111'),
    (2, 'Aisha',  'Khan',     'aisha.khan@example.com',     '954-555-0122'),
    (3, 'Daniel', 'Kim',      'daniel.kim@example.com',     '786-555-0133'),
    (4, 'Sofia',  'Martinez', 'sofia.martinez@example.com', NULL),
    (5, 'Liam',   'Johnson',  'liam.johnson@example.com',   '305-555-0155');

-- ---------------------------------------------------------------------
-- ADDRESS  (address 4 is Daniel's old address: retired, but kept
--           because order 1003 shipped there)
-- ---------------------------------------------------------------------
INSERT INTO address (address_id, customer_id, label, street, city, state, postal_code, is_active) VALUES
    (1, 1, 'Home', '1200 Brickell Ave, Apt 1504', 'Miami',            'FL', '33131',      TRUE),
    (2, 1, 'Work', '100 SE 2nd St, Suite 800',    'Miami',            'FL', '33131',      TRUE),
    (3, 2, 'Home', '8900 Pines Blvd',             'Pembroke Pines',   'FL', '33024',      TRUE),
    (4, 3, 'Home', '450 E Las Olas Blvd, Apt 12', 'Fort Lauderdale',  'FL', '33301',      FALSE),
    (5, 3, 'Home', '2100 Hollywood Blvd',         'Hollywood',        'FL', '33020-6708', TRUE),
    (6, 4, 'Home', '3300 NW 87th Ave',            'Doral',            'FL', '33172',      TRUE),
    (7, 5, 'Home', '10 Ocean Dr',                 'Miami Beach',      'FL', '33139',      TRUE);

-- ---------------------------------------------------------------------
-- PRODUCT
-- ---------------------------------------------------------------------
INSERT INTO product (product_id, seller_id, category_id, product_name, description, base_price) VALUES
    (1, 1, 1, 'Wireless Earbuds',        'Bluetooth 5.3 earbuds with charging case.',       59.99),
    (2, 1, 1, 'USB-C Fast Charger',      '65 W GaN wall charger.',                           24.99),
    (3, 2, 2, 'Ceramic Cookware Set',    'Non-stick ceramic pots and pans.',                129.00),
    (4, 2, 2, 'Bamboo Cutting Board',    'Large reversible bamboo board.',                   19.50),
    (5, 3, 3, 'Performance Running Tee', 'Moisture-wicking short-sleeve tee.',               22.00),
    (6, 3, 4, 'Trail Hiking Backpack',   'Water-resistant pack with hip belt.',              74.95),
    (7, 3, 4, 'Insulated Water Bottle',  'Double-wall stainless steel bottle.',              18.00);

-- ---------------------------------------------------------------------
-- PRODUCT_VARIANT  (NULL size/color = a product's single default variant)
-- ---------------------------------------------------------------------
INSERT INTO product_variant (product_id, sku, size, color, stock_quantity, price_override) VALUES
    (1, 'EB-BLK',     NULL,       'Black',    120, NULL),
    (1, 'EB-WHT',     NULL,       'White',     80, NULL),
    (2, 'CH-65W',     NULL,       NULL,       200, NULL),
    (3, 'CW-10PC',    '10-piece', 'Graphite',  25, NULL),
    (3, 'CW-5PC',     '5-piece',  'Graphite',  40, 89.00),
    (4, 'CB-STD',     NULL,       NULL,       150, NULL),
    (5, 'TEE-S-BLU',  'S',        'Blue',      60, NULL),
    (5, 'TEE-M-BLU',  'M',        'Blue',      75, NULL),
    (5, 'TEE-L-BLK',  'L',        'Black',     50, NULL),
    (5, 'TEE-XL-BLK', 'XL',       'Black',     30, 24.00),
    (6, 'BP-30L-GRN', '30 L',     'Green',     20, NULL),
    (6, 'BP-45L-GRY', '45 L',     'Gray',      15, 89.95),
    (7, 'WB-750-SLV', '750 ml',   'Silver',   100, NULL),
    (7, 'WB-1L-NVY',  '1 L',      'Navy',      70, 21.00);

-- ---------------------------------------------------------------------
-- ORDER_HEADER  (total_amount = SUM(quantity * unit_price) of its lines)
-- ---------------------------------------------------------------------
INSERT INTO order_header (order_id, address_id, order_date, status, total_amount) VALUES
    (1001, 1, '2026-09-01 10:15:00-04', 'delivered', 109.97),
    (1002, 3, '2026-09-03 14:40:00-04', 'delivered', 168.00),
    (1003, 4, '2026-09-05 09:05:00-04', 'delivered', 110.95),
    (1004, 6, '2026-09-12 19:22:00-04', 'shipped',    88.00),
    (1005, 2, '2026-09-18 12:30:00-04', 'refunded',   54.99),
    (1006, 5, '2026-09-26 08:50:00-04', 'pending',   110.95),
    (1007, 3, '2026-09-27 16:10:00-04', 'paid',      133.00);

-- ---------------------------------------------------------------------
-- ORDER_ITEM  (unit_price is the price at checkout: order 1005 bought
--              the white earbuds on sale at 54.99, not the 59.99 base)
-- ---------------------------------------------------------------------
INSERT INTO order_item (order_item_id, order_id, product_id, sku, quantity, unit_price) VALUES
    ( 1, 1001, 1, 'EB-BLK',     1,  59.99),
    ( 2, 1001, 2, 'CH-65W',     2,  24.99),
    ( 3, 1002, 3, 'CW-10PC',    1, 129.00),
    ( 4, 1002, 4, 'CB-STD',     2,  19.50),
    ( 5, 1003, 6, 'BP-30L-GRN', 1,  74.95),
    ( 6, 1003, 7, 'WB-750-SLV', 2,  18.00),
    ( 7, 1004, 5, 'TEE-M-BLU',  3,  22.00),
    ( 8, 1004, 5, 'TEE-L-BLK',  1,  22.00),
    ( 9, 1005, 1, 'EB-WHT',     1,  54.99),
    (10, 1006, 6, 'BP-45L-GRY', 1,  89.95),
    (11, 1006, 7, 'WB-1L-NVY',  1,  21.00),
    (12, 1007, 3, 'CW-5PC',     1,  89.00),
    (13, 1007, 5, 'TEE-S-BLU',  2,  22.00);

-- ---------------------------------------------------------------------
-- PAYMENT  (1005 was charged then refunded; 1007 was split across a
--           gift card and a card; 1006 is not paid yet)
-- ---------------------------------------------------------------------
INSERT INTO payment (payment_id, order_id, amount, payment_date, payment_method, status) VALUES
    (1, 1001, 109.97, '2026-09-01 10:16:00-04', 'card',      'completed'),
    (2, 1002, 168.00, '2026-09-03 14:41:00-04', 'paypal',    'completed'),
    (3, 1003, 110.95, '2026-09-05 09:06:00-04', 'card',      'completed'),
    (4, 1004,  88.00, '2026-09-12 19:23:00-04', 'card',      'completed'),
    (5, 1005,  54.99, '2026-09-18 12:31:00-04', 'card',      'completed'),
    (6, 1005,  54.99, '2026-09-21 11:00:00-04', 'card',      'refunded'),
    (7, 1007,  33.00, '2026-09-27 16:11:00-04', 'gift_card', 'completed'),
    (8, 1007, 100.00, '2026-09-27 16:11:30-04', 'card',      'completed');

-- ---------------------------------------------------------------------
-- REVIEW  (one review per customer per product)
-- ---------------------------------------------------------------------
INSERT INTO review (review_id, customer_id, product_id, rating, comment, review_date) VALUES
    (1, 1, 1, 5, 'Great sound and the case charges fast.',        '2026-09-06 18:00:00-04'),
    (2, 1, 2, 4, 'Charges my laptop, but it runs warm.',          '2026-09-06 18:05:00-04'),
    (3, 2, 3, 5, 'Nothing sticks. Worth the price.',              '2026-09-10 20:30:00-04'),
    (4, 2, 4, 5, NULL,                                             '2026-09-10 20:32:00-04'),
    (5, 3, 6, 4, 'Comfortable on long hikes; wish it had more pockets.', '2026-09-14 09:45:00-04'),
    (6, 4, 5, 3, 'Good fabric, but it runs a size small.',        '2026-09-20 13:15:00-04');

-- ---------------------------------------------------------------------
-- Move identity sequences past the explicit IDs used above
-- ---------------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('marketplace.category',     'category_id'),   (SELECT MAX(category_id)   FROM category));
SELECT setval(pg_get_serial_sequence('marketplace.seller',       'seller_id'),     (SELECT MAX(seller_id)     FROM seller));
SELECT setval(pg_get_serial_sequence('marketplace.customer',     'customer_id'),   (SELECT MAX(customer_id)   FROM customer));
SELECT setval(pg_get_serial_sequence('marketplace.address',      'address_id'),    (SELECT MAX(address_id)    FROM address));
SELECT setval(pg_get_serial_sequence('marketplace.product',      'product_id'),    (SELECT MAX(product_id)    FROM product));
SELECT setval(pg_get_serial_sequence('marketplace.order_header', 'order_id'),      (SELECT MAX(order_id)      FROM order_header));
SELECT setval(pg_get_serial_sequence('marketplace.order_item',   'order_item_id'), (SELECT MAX(order_item_id) FROM order_item));
SELECT setval(pg_get_serial_sequence('marketplace.payment',      'payment_id'),    (SELECT MAX(payment_id)    FROM payment));
SELECT setval(pg_get_serial_sequence('marketplace.review',       'review_id'),     (SELECT MAX(review_id)     FROM review));

COMMIT;

-- ---------------------------------------------------------------------
-- Check: row count per table
-- ---------------------------------------------------------------------
SELECT 'category' AS table_name, COUNT(*) AS row_count FROM category
UNION ALL SELECT 'seller',          COUNT(*) FROM seller
UNION ALL SELECT 'customer',        COUNT(*) FROM customer
UNION ALL SELECT 'address',         COUNT(*) FROM address
UNION ALL SELECT 'product',         COUNT(*) FROM product
UNION ALL SELECT 'product_variant', COUNT(*) FROM product_variant
UNION ALL SELECT 'order_header',    COUNT(*) FROM order_header
UNION ALL SELECT 'order_item',      COUNT(*) FROM order_item
UNION ALL SELECT 'payment',         COUNT(*) FROM payment
UNION ALL SELECT 'review',          COUNT(*) FROM review;
