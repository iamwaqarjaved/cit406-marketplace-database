-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Term Project: Multi-Vendor E-Commerce Marketplace
-- Migration 004 - Indexes
-- Author : Waqar Javed (250305023)
--
-- Primary-key and UNIQUE constraints already create their own indexes
-- (migration 001). PostgreSQL does NOT index foreign keys automatically,
-- so this migration adds one index per foreign key that is not already
-- the leading column of a PK or UNIQUE index. They speed up joins and
-- the checks PostgreSQL runs for ON DELETE RESTRICT / CASCADE.
--   Already covered: product_variant.product_id (product_variant_pk),
--                    order_item.order_id (order_item_variant_uq),
--                    review.customer_id (review_customer_product_uq),
--                    seller_payout.seller_id (seller_payout_seller_order_uq),
--                    app_user.customer_id (app_user_customer_uq).
--
-- Module 7 performance pass (tests/02_performance_tests.sql):
--   Two extra indexes were tested, order_header(order_date) for portfolio
--   Queries 1-2 and product_variant(stock_quantity) for Query 6. With the
--   project's small tables the planner kept choosing a Seq Scan and the
--   indexes gave no measurable improvement, so they were NOT kept.
--   Queries 3 and 9 already use address_customer_idx,
--   order_header_address_idx and order_item_variant_idx below.
--
-- Safe to rerun.
-- =====================================================================

SET search_path TO marketplace;

CREATE INDEX IF NOT EXISTS address_customer_idx     ON address      (customer_id);
CREATE INDEX IF NOT EXISTS product_seller_idx       ON product      (seller_id);
CREATE INDEX IF NOT EXISTS product_category_idx     ON product      (category_id);
CREATE INDEX IF NOT EXISTS order_header_address_idx ON order_header (address_id);
CREATE INDEX IF NOT EXISTS order_item_variant_idx   ON order_item   (product_id, sku);
CREATE INDEX IF NOT EXISTS payment_order_idx        ON payment      (order_id);
CREATE INDEX IF NOT EXISTS review_product_idx       ON review       (product_id);
CREATE INDEX IF NOT EXISTS seller_payout_order_idx  ON seller_payout (order_id);
