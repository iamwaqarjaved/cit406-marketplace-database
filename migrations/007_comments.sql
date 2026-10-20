-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Term Project: Multi-Vendor E-Commerce Marketplace
-- Migration 007 - Data dictionary comments
-- Author : Waqar Javed (250305023)
--
-- Stores a description of every table, view and column in the database
-- itself (COMMENT ON), so tools such as pgAdmin, Supabase and \d+ show
-- them. docs/data-dictionary.md is generated from these comments plus
-- the system catalog by scripts/generate_data_dictionary.sql.
-- Safe to rerun.
-- =====================================================================

SET search_path TO marketplace;

COMMENT ON SCHEMA marketplace IS 'Multi-vendor e-commerce marketplace (CIT 406 term project).';

-- CATEGORY ------------------------------------------------------------
COMMENT ON TABLE  category IS 'Product categories used to organize the catalog.';
COMMENT ON COLUMN category.category_id   IS 'Surrogate key.';
COMMENT ON COLUMN category.category_name IS 'Display name of the category; unique.';

-- SELLER ---------------------------------------------------------------
COMMENT ON TABLE  seller IS 'Businesses that list products on the marketplace.';
COMMENT ON COLUMN seller.seller_id       IS 'Surrogate key.';
COMMENT ON COLUMN seller.business_name   IS 'Legal or trading name shown to customers.';
COMMENT ON COLUMN seller.contact_email   IS 'Seller contact email; unique.';
COMMENT ON COLUMN seller.phone           IS 'Seller contact phone number (optional).';
COMMENT ON COLUMN seller.approval_status IS 'pending, approved, suspended or rejected. Only approved sellers appear in the storefront.';

-- CUSTOMER -------------------------------------------------------------
COMMENT ON TABLE  customer IS 'People with a shopping account.';
COMMENT ON COLUMN customer.customer_id IS 'Surrogate key.';
COMMENT ON COLUMN customer.first_name  IS 'Customer first name.';
COMMENT ON COLUMN customer.last_name   IS 'Customer last name.';
COMMENT ON COLUMN customer.email       IS 'Login and contact email; unique.';
COMMENT ON COLUMN customer.phone       IS 'Contact phone number (optional).';

-- ADDRESS --------------------------------------------------------------
COMMENT ON TABLE  address IS 'Saved shipping addresses of a customer. Rows used by an order are never edited or deleted; they are retired with is_active = FALSE. Protected by row-level security.';
COMMENT ON COLUMN address.address_id  IS 'Surrogate key.';
COMMENT ON COLUMN address.customer_id IS 'Customer who owns the address (FK to customer).';
COMMENT ON COLUMN address.label       IS 'Customer''s name for the address, e.g. Home or Work (optional).';
COMMENT ON COLUMN address.street      IS 'Street line, including apartment or suite.';
COMMENT ON COLUMN address.city        IS 'City.';
COMMENT ON COLUMN address.state       IS 'Two-letter US state code.';
COMMENT ON COLUMN address.postal_code IS 'ZIP code: 5 digits or ZIP+4.';
COMMENT ON COLUMN address.is_active   IS 'FALSE once the address is retired; retired addresses cannot be used for new orders.';

-- PRODUCT --------------------------------------------------------------
COMMENT ON TABLE  product IS 'A product listed by one seller in one category.';
COMMENT ON COLUMN product.product_id   IS 'Surrogate key.';
COMMENT ON COLUMN product.seller_id    IS 'Seller who lists the product (FK to seller).';
COMMENT ON COLUMN product.category_id  IS 'Category the product belongs to (FK to category).';
COMMENT ON COLUMN product.product_name IS 'Product name shown in the catalog.';
COMMENT ON COLUMN product.description  IS 'Long description (optional).';
COMMENT ON COLUMN product.base_price   IS 'Default selling price in USD for all variants.';

-- PRODUCT_VARIANT ------------------------------------------------------
COMMENT ON TABLE  product_variant IS 'A sellable size/color version of a product (weak entity identified by product and SKU).';
COMMENT ON COLUMN product_variant.product_id     IS 'Product this variant belongs to (FK to product); part of the primary key.';
COMMENT ON COLUMN product_variant.sku            IS 'Stock keeping unit, unique within the product; part of the primary key.';
COMMENT ON COLUMN product_variant.size           IS 'Size, e.g. M or 45 L (NULL when the product has no sizes).';
COMMENT ON COLUMN product_variant.color          IS 'Color (NULL when the product has no colors).';
COMMENT ON COLUMN product_variant.stock_quantity IS 'Units in stock; never negative. Changes are logged in variant_audit.';
COMMENT ON COLUMN product_variant.price_override IS 'Variant price in USD that replaces product.base_price; NULL means use the base price. Changes are logged in variant_audit.';
COMMENT ON COLUMN product_variant.reorder_level  IS 'Stock level at or below which the variant should be reordered (default 10).';

-- ORDER_HEADER ---------------------------------------------------------
COMMENT ON TABLE  order_header IS 'A customer order. The customer is reached through the shipping address (BCNF).';
COMMENT ON COLUMN order_header.order_id     IS 'Surrogate key (order number).';
COMMENT ON COLUMN order_header.address_id   IS 'Shipping address (FK to address); also identifies the customer.';
COMMENT ON COLUMN order_header.order_date   IS 'Date and time the order was placed.';
COMMENT ON COLUMN order_header.status       IS 'pending, paid, shipped, delivered, cancelled or refunded.';
COMMENT ON COLUMN order_header.total_amount IS 'Order total in USD = SUM(quantity * unit_price) of its lines (see fn_order_total).';

-- ORDER_ITEM -----------------------------------------------------------
COMMENT ON TABLE  order_item IS 'One line of an order: a variant, a quantity and the price paid.';
COMMENT ON COLUMN order_item.order_item_id IS 'Surrogate key.';
COMMENT ON COLUMN order_item.order_id      IS 'Order the line belongs to (FK to order_header).';
COMMENT ON COLUMN order_item.product_id    IS 'Product of the variant bought (FK to product_variant with sku).';
COMMENT ON COLUMN order_item.sku           IS 'SKU of the variant bought (FK to product_variant with product_id).';
COMMENT ON COLUMN order_item.quantity      IS 'Units bought; greater than zero.';
COMMENT ON COLUMN order_item.unit_price    IS 'Price per unit in USD at checkout (kept even if the catalog price changes later).';

-- PAYMENT --------------------------------------------------------------
COMMENT ON TABLE  payment IS 'Payments and refunds against an order. An order can have several (split payment, refund).';
COMMENT ON COLUMN payment.payment_id     IS 'Surrogate key.';
COMMENT ON COLUMN payment.order_id       IS 'Order paid for (FK to order_header).';
COMMENT ON COLUMN payment.amount         IS 'Amount in USD; greater than zero.';
COMMENT ON COLUMN payment.payment_date   IS 'Date and time of the payment.';
COMMENT ON COLUMN payment.payment_method IS 'card, paypal, bank_transfer or gift_card.';
COMMENT ON COLUMN payment.status         IS 'pending, completed, failed or refunded.';

-- REVIEW ---------------------------------------------------------------
COMMENT ON TABLE  review IS 'A customer''s rating of a product; at most one per customer per product.';
COMMENT ON COLUMN review.review_id   IS 'Surrogate key.';
COMMENT ON COLUMN review.customer_id IS 'Customer who wrote the review (FK to customer).';
COMMENT ON COLUMN review.product_id  IS 'Product reviewed (FK to product).';
COMMENT ON COLUMN review.rating      IS 'Star rating from 1 to 5.';
COMMENT ON COLUMN review.comment     IS 'Review text (optional).';
COMMENT ON COLUMN review.review_date IS 'Date and time the review was posted.';

-- SELLER_PAYOUT --------------------------------------------------------
COMMENT ON TABLE  seller_payout IS 'Money the marketplace pays a seller for their items on one order; at most one payout per seller per order.';
COMMENT ON COLUMN seller_payout.payout_id    IS 'Surrogate key.';
COMMENT ON COLUMN seller_payout.seller_id    IS 'Seller being paid (FK to seller).';
COMMENT ON COLUMN seller_payout.order_id     IS 'Order the payout is for (FK to order_header).';
COMMENT ON COLUMN seller_payout.gross_amount IS 'Seller''s sales on the order in USD, before commission.';
COMMENT ON COLUMN seller_payout.commission   IS 'Marketplace commission kept, in USD.';
COMMENT ON COLUMN seller_payout.net_amount   IS 'Amount paid to the seller in USD = gross_amount - commission.';
COMMENT ON COLUMN seller_payout.paid_at      IS 'Date and time the payout was sent; NULL while it is still owed.';

-- VARIANT_AUDIT --------------------------------------------------------
COMMENT ON TABLE  variant_audit IS 'Audit log written by trigger trg_variant_audit for every change to a variant''s stock or price override. No foreign keys, so history survives deletes.';
COMMENT ON COLUMN variant_audit.audit_id           IS 'Surrogate key, in the order the changes happened.';
COMMENT ON COLUMN variant_audit.product_id         IS 'Product of the changed variant.';
COMMENT ON COLUMN variant_audit.sku                IS 'SKU of the changed variant.';
COMMENT ON COLUMN variant_audit.old_stock_quantity IS 'Stock before the change.';
COMMENT ON COLUMN variant_audit.new_stock_quantity IS 'Stock after the change.';
COMMENT ON COLUMN variant_audit.old_price_override IS 'Price override before the change.';
COMMENT ON COLUMN variant_audit.new_price_override IS 'Price override after the change.';
COMMENT ON COLUMN variant_audit.changed_by         IS 'Database role that made the change (current_user).';
COMMENT ON COLUMN variant_audit.changed_at         IS 'Date and time of the change.';

-- APP_USER -------------------------------------------------------------
COMMENT ON TABLE  app_user IS 'Maps each customer database login role to its customer, for the row-level security policy on address. Protected by its own policy.';
COMMENT ON COLUMN app_user.role_name   IS 'PostgreSQL role name of the customer login, e.g. cust_pedro.';
COMMENT ON COLUMN app_user.customer_id IS 'Customer the role belongs to (FK to customer); unique.';

-- VIEWS ----------------------------------------------------------------
COMMENT ON VIEW v_order_summary IS 'One row per order: customer, ship-to city, line and unit counts, sellers involved, total, net paid and balance due.';
COMMENT ON VIEW v_storefront_catalog IS 'Every variant from approved sellers with its selling price, stock status and product rating.';
