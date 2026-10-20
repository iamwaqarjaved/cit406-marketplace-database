-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Term Project: Multi-Vendor E-Commerce Marketplace
-- Migration 002 - Logic layer (Module 6)
-- Author : Waqar Javed (250305023)
--
-- Views         : v_order_summary, v_storefront_catalog
-- Functions     : fn_order_total, fn_seller_payout
-- Audit trigger : variant_audit table + trg_variant_audit on product_variant
-- Transaction   : sp_place_order procedure
-- Safe to rerun. Tests for these objects are in tests/01_logic_layer_tests.sql.
-- =====================================================================

SET search_path TO marketplace;


-- =====================================================================
-- 1. VIEWS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1a. v_order_summary
-- One row per order with its customer, shipping city, item counts,
--     sellers involved, order total, amount actually paid (payments
--     minus refunds) and the balance still due.
-- Used by: customer service, order history pages, payment follow-up.
-- Replaces a 5-table join + payment aggregation written in many queries.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.order_id,
       o.order_date::date                                   AS order_date,
       o.status,
       c.customer_id,
       c.first_name || ' ' || c.last_name                   AS customer_name,
       c.email                                              AS customer_email,
       a.city || ', ' || a.state                            AS ship_to,
       COALESCE(li.line_count, 0)                           AS line_count,
       COALESCE(li.units, 0)                                AS units,
       COALESCE(li.seller_count, 0)                         AS seller_count,
       o.total_amount,
       COALESCE(pay.net_paid, 0.00)                         AS net_paid,
       o.total_amount - COALESCE(pay.net_paid, 0.00)        AS balance_due
FROM   order_header o
JOIN   address  a ON a.address_id  = o.address_id
JOIN   customer c ON c.customer_id = a.customer_id
LEFT   JOIN (
         SELECT i.order_id,
                COUNT(*)                    AS line_count,
                SUM(i.quantity)             AS units,
                COUNT(DISTINCT p.seller_id) AS seller_count
         FROM   order_item i
         JOIN   product p ON p.product_id = i.product_id
         GROUP  BY i.order_id
       ) li  ON li.order_id = o.order_id
LEFT   JOIN (
         SELECT order_id,
                COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0)
              - COALESCE(SUM(amount) FILTER (WHERE status = 'refunded'),  0) AS net_paid
         FROM   payment
         GROUP  BY order_id
       ) pay ON pay.order_id = o.order_id;


-- ---------------------------------------------------------------------
-- 1b. v_storefront_catalog
-- Every sellable variant from APPROVED sellers, with the price the
--     customer actually pays (price_override if set, otherwise the
--     product's base_price), a stock status, and the product's rating.
-- Used by: the storefront product pages and the low-stock dashboard.
-- Hides pending/suspended sellers so they can never appear for sale.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_storefront_catalog AS
SELECT p.product_id,
       v.sku,
       p.product_name,
       cat.category_name,
       s.business_name                                   AS seller,
       v.size,
       v.color,
       COALESCE(v.price_override, p.base_price)          AS selling_price,
       v.stock_quantity,
       CASE
           WHEN v.stock_quantity = 0  THEN 'Out of stock'
           WHEN v.stock_quantity < 25 THEN 'Low stock'
           ELSE 'In stock'
       END                                               AS stock_status,
       r.avg_rating,
       COALESCE(r.review_count, 0)                       AS review_count
FROM   product_variant v
JOIN   product  p   ON p.product_id   = v.product_id
JOIN   seller   s   ON s.seller_id    = p.seller_id
JOIN   category cat ON cat.category_id = p.category_id
LEFT   JOIN (
         SELECT product_id,
                ROUND(AVG(rating), 2) AS avg_rating,
                COUNT(*)              AS review_count
         FROM   review
         GROUP  BY product_id
       ) r ON r.product_id = p.product_id
WHERE  s.approval_status = 'approved';


-- =====================================================================
-- 2. FUNCTIONS (PL/pgSQL)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2a. fn_order_total(order_id)
-- Returns SUM(quantity * unit_price) of an order's lines (0 if none).
-- Used when an order is placed (Section 4) to set total_amount, and
-- to check that a stored total still matches its lines.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_order_total(p_order_id INTEGER)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO   v_total
    FROM   order_item
    WHERE  order_id = p_order_id;

    RETURN v_total;
END;
$$;


-- ---------------------------------------------------------------------
-- 2b. fn_seller_payout(seller_id, from_date, to_date, commission_pct)
-- Calculates what the marketplace owes a seller for a period:
--     gross sales of the seller's items on paid/shipped/delivered
--     orders, minus the platform commission (default 10%).
-- Returns the net payout rounded to cents.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_seller_payout(
    p_seller_id      INTEGER,
    p_from           DATE,
    p_to             DATE,
    p_commission_pct NUMERIC DEFAULT 10
)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_gross NUMERIC(12,2);
BEGIN
    IF p_commission_pct < 0 OR p_commission_pct > 100 THEN
        RAISE EXCEPTION 'Commission must be between 0 and 100, got %', p_commission_pct;
    END IF;

    SELECT COALESCE(SUM(i.quantity * i.unit_price), 0)
    INTO   v_gross
    FROM   order_item   i
    JOIN   order_header o ON o.order_id   = i.order_id
    JOIN   product      p ON p.product_id = i.product_id
    WHERE  p.seller_id = p_seller_id
    AND    o.status IN ('paid', 'shipped', 'delivered')
    AND    o.order_date::date BETWEEN p_from AND p_to;

    RETURN ROUND(v_gross * (1 - p_commission_pct / 100.0), 2);
END;
$$;


-- =====================================================================
-- 3. AUDIT TRIGGER
-- Monitors product_variant: every change to a variant's stock level or
-- price override is logged. Stock and price decide what customers can
-- buy and what they pay, so every change must be traceable to a user
-- and a time (overselling, pricing disputes, stock reconciliation).
-- =====================================================================
DROP TABLE IF EXISTS variant_audit CASCADE;

CREATE TABLE variant_audit (
    audit_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id         INTEGER       NOT NULL,          -- which record
    sku                VARCHAR(40)   NOT NULL,          -- which record
    old_stock_quantity INTEGER,                         -- what changed
    new_stock_quantity INTEGER,
    old_price_override NUMERIC(10,2),
    new_price_override NUMERIC(10,2),
    changed_by         TEXT          NOT NULL DEFAULT current_user,  -- who
    changed_at         TIMESTAMPTZ   NOT NULL DEFAULT now()          -- when
);

CREATE OR REPLACE FUNCTION trg_fn_variant_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO variant_audit
        (product_id, sku,
         old_stock_quantity, new_stock_quantity,
         old_price_override, new_price_override,
         changed_by, changed_at)
    VALUES
        (OLD.product_id, OLD.sku,
         OLD.stock_quantity, NEW.stock_quantity,
         OLD.price_override, NEW.price_override,
         current_user, now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_variant_audit ON product_variant;

CREATE TRIGGER trg_variant_audit
AFTER UPDATE OF stock_quantity, price_override ON product_variant
FOR EACH ROW
WHEN (OLD.stock_quantity IS DISTINCT FROM NEW.stock_quantity
   OR OLD.price_override IS DISTINCT FROM NEW.price_override)
EXECUTE FUNCTION trg_fn_variant_audit();


-- =====================================================================
-- 4. TRANSACTION: place an order as one unit
-- Placing an order is several statements that must all succeed or all
-- fail together:
--   1) create the order header,
--   2) add each order line at the current selling price,
--   3) take each line's quantity out of stock,
--   4) set the order total (fn_order_total),
--   5) record the payment.
-- If any step fails (address retired, seller not approved, not enough
-- stock), RAISE EXCEPTION aborts the transaction and PostgreSQL rolls
-- back every earlier step, so there is never an order without lines,
-- stock taken without an order, or a payment for a missing order.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_place_order(
    p_address_id     INTEGER,
    p_items          JSONB,        -- [{"product_id":1,"sku":"EB-BLK","quantity":2}, ...]
    p_payment_method VARCHAR,
    INOUT p_order_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item   JSONB;
    v_qty    INTEGER;
    v_stock  INTEGER;
    v_price  NUMERIC(10,2);
    v_status VARCHAR(12);
    v_total  NUMERIC(12,2);
BEGIN
    -- Validate the shipping address
    IF NOT EXISTS (SELECT 1 FROM address WHERE address_id = p_address_id AND is_active) THEN
        RAISE EXCEPTION 'Address % does not exist or is retired', p_address_id;
    END IF;

    -- Step 1: order header
    INSERT INTO order_header (address_id, status, total_amount)
    VALUES (p_address_id, 'paid', 0)
    RETURNING order_id INTO p_order_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_qty := (v_item->>'quantity')::INTEGER;

        -- Lock the variant row so two orders cannot sell the same stock
        SELECT v.stock_quantity, COALESCE(v.price_override, p.base_price), s.approval_status
        INTO   v_stock, v_price, v_status
        FROM   product_variant v
        JOIN   product p ON p.product_id = v.product_id
        JOIN   seller  s ON s.seller_id  = p.seller_id
        WHERE  v.product_id = (v_item->>'product_id')::INTEGER
        AND    v.sku        =  v_item->>'sku'
        FOR UPDATE OF v;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Variant %/% does not exist', v_item->>'product_id', v_item->>'sku';
        END IF;
        IF v_status <> 'approved' THEN
            RAISE EXCEPTION 'Seller of %/% is not approved', v_item->>'product_id', v_item->>'sku';
        END IF;
        IF v_stock < v_qty THEN
            RAISE EXCEPTION 'Not enough stock for % (requested %, available %)',
                            v_item->>'sku', v_qty, v_stock;
        END IF;

        -- Step 2: order line at the current selling price
        INSERT INTO order_item (order_id, product_id, sku, quantity, unit_price)
        VALUES (p_order_id, (v_item->>'product_id')::INTEGER, v_item->>'sku', v_qty, v_price);

        -- Step 3: take the quantity out of stock (fires the audit trigger)
        UPDATE product_variant
        SET    stock_quantity = stock_quantity - v_qty
        WHERE  product_id = (v_item->>'product_id')::INTEGER
        AND    sku        =  v_item->>'sku';
    END LOOP;

    -- Step 4: order total
    v_total := fn_order_total(p_order_id);
    UPDATE order_header SET total_amount = v_total WHERE order_id = p_order_id;

    -- Step 5: payment
    INSERT INTO payment (order_id, amount, payment_method, status)
    VALUES (p_order_id, v_total, p_payment_method, 'completed');
END;
$$;
