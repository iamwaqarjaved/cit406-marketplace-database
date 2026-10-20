-- =====================================================================
-- CIT 406 - Term Project: Multi-Vendor E-Commerce Marketplace
-- tests/01_logic_layer_tests.sql - exercises the Module 6 logic layer
-- Run on a fresh build (build.sql). These tests CHANGE data (they place
-- an order and update stock); run seed/seed.sql again to reset.
-- In pgAdmin run each block on its own (highlight, F5).
-- =====================================================================

SET search_path TO marketplace;


-- T1. View: order summary (7 orders; 1006 has a balance due of 110.95)
SELECT * FROM v_order_summary ORDER BY order_id;

-- T2. View: storefront catalog (14 variants from approved sellers; backpacks show Low stock)
SELECT * FROM v_storefront_catalog ORDER BY category_name, product_name, sku;

-- T3. Functions
SELECT fn_order_total(1007) AS order_1007_total;                     -- 133.00
SELECT s.business_name,
       fn_seller_payout(s.seller_id, DATE '2026-09-01', DATE '2026-09-30')     AS payout_10pct,
       fn_seller_payout(s.seller_id, DATE '2026-09-01', DATE '2026-09-30', 15) AS payout_15pct
FROM   seller s
ORDER  BY s.seller_id;

-- T4. Audit trigger: change a price override and a stock level
UPDATE product_variant SET price_override = 79.95 WHERE product_id = 6 AND sku = 'BP-45L-GRY';
UPDATE product_variant SET stock_quantity = 40    WHERE product_id = 6 AND sku = 'BP-30L-GRN';
SELECT * FROM variant_audit ORDER BY audit_id;

-- T5. Transaction SUCCESS: two lines from two sellers -> COMMIT
BEGIN;
CALL sp_place_order(7,
     '[{"product_id":1,"sku":"EB-BLK","quantity":2},
       {"product_id":7,"sku":"WB-750-SLV","quantity":1}]',
     'card', NULL);
COMMIT;

SELECT * FROM v_order_summary WHERE order_id = (SELECT MAX(order_id) FROM order_header);
SELECT product_id, sku, stock_quantity FROM product_variant
WHERE  (product_id, sku) IN ((1,'EB-BLK'), (7,'WB-750-SLV'));      -- 118 and 99
SELECT * FROM variant_audit ORDER BY audit_id;                      -- 2 new stock rows

-- T6. Transaction FAILURE: the second line asks for 999 units.
-- The first line's INSERT and stock UPDATE already ran, but the error
-- aborts the transaction, so ROLLBACK undoes all of it.
-- In pgAdmin: run BEGIN + CALL together (the error stops execution),
-- then run ROLLBACK on its own.
SELECT COUNT(*) AS orders_before FROM order_header;                 -- 8
SELECT stock_quantity AS eb_blk_before FROM product_variant
WHERE  product_id = 1 AND sku = 'EB-BLK';                           -- 118

BEGIN;
CALL sp_place_order(7,
     '[{"product_id":1,"sku":"EB-BLK","quantity":1},
       {"product_id":3,"sku":"CW-10PC","quantity":999}]',
     'card', NULL);
-- ERROR:  Not enough stock for CW-10PC (requested 999, available 25)
ROLLBACK;

SELECT COUNT(*) AS orders_after FROM order_header;                  -- still 8
SELECT stock_quantity AS eb_blk_after FROM product_variant
WHERE  product_id = 1 AND sku = 'EB-BLK';                           -- still 118
SELECT COUNT(*) AS audit_rows FROM variant_audit;                   -- unchanged
