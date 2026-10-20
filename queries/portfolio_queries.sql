-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Module 5: Assignment 2 - Project Query Portfolio
-- Term project: Multi-Vendor E-Commerce Marketplace
-- Student : Waqar Javed (250305023)
-- Professor: Anshu Sharma
--
-- Database: the "marketplace" schema built by build.sql (migrations +
-- seed/seed.sql). Read-only: none of these queries change data.
-- Ten queries, each answering a question from the Week 2 project proposal.
-- Run the SET line once, then run each query on its own.
-- =====================================================================

SET search_path TO marketplace;


-- ---------------------------------------------------------------------
-- Q1. What is each seller's total revenue over a given date range?
--     (Range: September 1-30, 2026; paid, shipped and delivered orders)
-- Features: INNER JOIN (4 tables), WHERE with BETWEEN and IN,
--           GROUP BY, SUM aggregate
-- ---------------------------------------------------------------------
SELECT s.business_name,
       COUNT(DISTINCT o.order_id)          AS orders,
       SUM(i.quantity)                     AS units_sold,
       SUM(i.quantity * i.unit_price)      AS revenue
FROM   order_item   i
INNER  JOIN order_header o ON o.order_id   = i.order_id
INNER  JOIN product      p ON p.product_id = i.product_id
INNER  JOIN seller       s ON s.seller_id  = p.seller_id
WHERE  o.order_date::date BETWEEN DATE '2026-09-01' AND DATE '2026-09-30'
AND    o.status IN ('paid', 'shipped', 'delivered')
GROUP  BY s.seller_id, s.business_name
ORDER  BY revenue DESC;


-- ---------------------------------------------------------------------
-- Q2. What are the top-selling products (by quantity) over the past
--     month? (Month: September 2026; cancelled and refunded orders
--     excluded)
-- Features: CTE, GROUP BY, RANK() window function
-- ---------------------------------------------------------------------
WITH product_sales AS (
    SELECT p.product_id,
           p.product_name,
           SUM(i.quantity) AS units_sold
    FROM   order_item   i
    INNER  JOIN order_header o ON o.order_id   = i.order_id
    INNER  JOIN product      p ON p.product_id = i.product_id
    WHERE  o.order_date >= DATE '2026-09-01'
    AND    o.order_date <  DATE '2026-10-01'
    AND    o.status NOT IN ('cancelled', 'refunded')
    GROUP  BY p.product_id, p.product_name
)
SELECT RANK() OVER (ORDER BY units_sold DESC) AS sales_rank,
       product_name,
       units_sold
FROM   product_sales
ORDER  BY sales_rank, product_name;


-- ---------------------------------------------------------------------
-- Q3. What is a customer's complete order history, including status,
--     totals and amount actually paid? (Customer: Daniel Kim,
--     customer_id = 3)
-- Features: INNER JOIN through address (BCNF design), LEFT OUTER JOIN
--           to a derived table, conditional aggregation (FILTER),
--           COALESCE
-- ---------------------------------------------------------------------
SELECT c.first_name || ' ' || c.last_name           AS customer,
       o.order_id,
       o.order_date::date                           AS order_date,
       o.status,
       o.total_amount,
       COALESCE(pay.net_paid, 0.00)                 AS net_paid,
       a.street || ', ' || a.city                   AS shipped_to,
       a.is_active                                  AS address_still_active
FROM   customer     c
INNER  JOIN address      a ON a.customer_id = c.customer_id
INNER  JOIN order_header o ON o.address_id  = a.address_id
LEFT   OUTER JOIN (
         SELECT order_id,
                COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0)
              - COALESCE(SUM(amount) FILTER (WHERE status = 'refunded'),  0) AS net_paid
         FROM   payment
         GROUP  BY order_id
       ) pay ON pay.order_id = o.order_id
WHERE  c.customer_id = 3
ORDER  BY o.order_date;


-- ---------------------------------------------------------------------
-- Q4. Which orders contain items from more than one seller?
-- Features: INNER JOIN, GROUP BY, HAVING with COUNT(DISTINCT),
--           STRING_AGG
-- ---------------------------------------------------------------------
SELECT o.order_id,
       o.order_date::date                                   AS order_date,
       COUNT(DISTINCT p.seller_id)                          AS seller_count,
       STRING_AGG(DISTINCT s.business_name, ', ')           AS sellers
FROM   order_header o
INNER  JOIN order_item i ON i.order_id   = o.order_id
INNER  JOIN product    p ON p.product_id = i.product_id
INNER  JOIN seller     s ON s.seller_id  = p.seller_id
GROUP  BY o.order_id, o.order_date
HAVING COUNT(DISTINCT p.seller_id) > 1
ORDER  BY o.order_id;


-- ---------------------------------------------------------------------
-- Q5. What is the average customer rating for each product, how many
--     reviews does it have, and is it above the marketplace-wide
--     average rating?
-- Features: LEFT OUTER JOIN (keeps unreviewed products), GROUP BY,
--           AVG/COUNT, CASE, non-correlated scalar subquery
-- ---------------------------------------------------------------------
SELECT p.product_name,
       COUNT(r.review_id)          AS review_count,
       ROUND(AVG(r.rating), 2)     AS avg_rating,
       CASE
           WHEN COUNT(r.review_id) = 0 THEN 'No reviews yet'
           WHEN AVG(r.rating) > (SELECT AVG(rating) FROM review)
                THEN 'Above marketplace average'
           ELSE 'At or below marketplace average'
       END                         AS compared_to_marketplace
FROM   product p
LEFT   OUTER JOIN review r ON r.product_id = p.product_id
GROUP  BY p.product_id, p.product_name
ORDER  BY avg_rating DESC NULLS LAST, p.product_name;


-- ---------------------------------------------------------------------
-- Q6. Which product variants are out of stock or below a reorder
--     threshold? (The schema has no per-variant threshold, so a fixed
--     threshold of 25 units is used; see "Schema limitations".)
-- Features: INNER JOIN, WHERE, CASE
-- ---------------------------------------------------------------------
SELECT s.business_name,
       p.product_name,
       v.sku,
       v.stock_quantity,
       CASE
           WHEN v.stock_quantity = 0  THEN 'OUT OF STOCK'
           WHEN v.stock_quantity < 25 THEN 'Below reorder threshold'
       END AS stock_alert
FROM   product_variant v
INNER  JOIN product p ON p.product_id = v.product_id
INNER  JOIN seller  s ON s.seller_id  = p.seller_id
WHERE  v.stock_quantity < 25
ORDER  BY v.stock_quantity, p.product_name;


-- ---------------------------------------------------------------------
-- Q7. For each order, how does its total break down across the sellers
--     whose items it contains (for seller payouts)?
-- Features: CTE, GROUP BY, SUM() OVER (PARTITION BY) window function,
--           percentage calculation
-- ---------------------------------------------------------------------
WITH seller_lines AS (
    SELECT i.order_id,
           s.business_name,
           SUM(i.quantity * i.unit_price) AS seller_amount
    FROM   order_item i
    INNER  JOIN product p ON p.product_id = i.product_id
    INNER  JOIN seller  s ON s.seller_id  = p.seller_id
    GROUP  BY i.order_id, s.business_name
)
SELECT order_id,
       business_name                                          AS seller,
       seller_amount,
       SUM(seller_amount) OVER (PARTITION BY order_id)        AS order_total,
       ROUND(100.0 * seller_amount
             / SUM(seller_amount) OVER (PARTITION BY order_id), 1) AS pct_of_order
FROM   seller_lines
ORDER  BY order_id, seller_amount DESC;


-- ---------------------------------------------------------------------
-- Q8. Which sellers have the highest average product ratings?
--     (Sellers with no reviews must still appear.)
-- Features: RIGHT OUTER JOIN, GROUP BY, AVG/COUNT, ORDER BY NULLS LAST
-- ---------------------------------------------------------------------
SELECT s.business_name,
       s.approval_status,
       COUNT(r.review_id)       AS review_count,
       ROUND(AVG(r.rating), 2)  AS avg_rating
FROM   review r
INNER  JOIN product p ON p.product_id = r.product_id
RIGHT  OUTER JOIN seller s ON s.seller_id = p.seller_id
GROUP  BY s.seller_id, s.business_name, s.approval_status
ORDER  BY avg_rating DESC NULLS LAST, s.business_name;


-- ---------------------------------------------------------------------
-- Q9. Which product variants in each category have never been
--      ordered?
-- Features: correlated subquery with NOT EXISTS, INNER JOIN
-- ---------------------------------------------------------------------
SELECT c.category_name,
       p.product_name,
       v.sku,
       v.stock_quantity
FROM   product_variant v
INNER  JOIN product  p ON p.product_id  = v.product_id
INNER  JOIN category c ON c.category_id = p.category_id
WHERE  NOT EXISTS (
         SELECT 1
         FROM   order_item i
         WHERE  i.product_id = v.product_id
         AND    i.sku        = v.sku
       )
ORDER  BY c.category_name, p.product_name, v.sku;


-- ---------------------------------------------------------------------
-- Q10. Which orders were shipped to each address, and which customer
--      does that address belong to? (Every address and every order
--      appears, including addresses never used.)
-- Features: FULL OUTER JOIN, INNER JOIN, COALESCE, ORDER BY NULLS LAST
-- ---------------------------------------------------------------------
SELECT a.address_id,
       c.first_name || ' ' || c.last_name             AS customer,
       a.street || ', ' || a.city                     AS address,
       a.is_active,
       o.order_id,
       o.status,
       COALESCE(o.order_date::date::text, 'never used') AS shipped_on
FROM   address a
INNER  JOIN customer c ON c.customer_id = a.customer_id
FULL   OUTER JOIN order_header o ON o.address_id = a.address_id
ORDER  BY a.address_id NULLS LAST, o.order_id;
