-- =====================================================================
-- CIT 406 - Term Project: Multi-Vendor E-Commerce Marketplace
-- tests/00_verify_build.sql - checks that a rebuild is complete.
-- Run after build.sql (or after running every migration + the seed).
-- Every row should show result = PASS.
-- =====================================================================

SET search_path TO marketplace;

WITH checks (check_name, expected, actual) AS (
    VALUES
    ('tables',          13, (SELECT COUNT(*)::int FROM information_schema.tables
                             WHERE table_schema = 'marketplace' AND table_type = 'BASE TABLE')),
    ('views',            2, (SELECT COUNT(*)::int FROM information_schema.views
                             WHERE table_schema = 'marketplace')),
    ('functions + procedure', 4, (SELECT COUNT(*)::int FROM pg_proc
                             WHERE pronamespace = 'marketplace'::regnamespace)),
    ('triggers',         1, (SELECT COUNT(*)::int FROM pg_trigger t
                             JOIN pg_class c ON c.oid = t.tgrelid
                             WHERE c.relnamespace = 'marketplace'::regnamespace AND NOT t.tgisinternal)),
    ('foreign keys',    13, (SELECT COUNT(*)::int FROM pg_constraint
                             WHERE connamespace = 'marketplace'::regnamespace AND contype = 'f')),
    ('secondary indexes', 8, (SELECT COUNT(*)::int FROM pg_indexes
                             WHERE schemaname = 'marketplace' AND indexname LIKE '%\_idx')),
    ('RLS tables',       2, (SELECT COUNT(*)::int FROM pg_class
                             WHERE relnamespace = 'marketplace'::regnamespace AND relrowsecurity)),
    ('RLS policies',     2, (SELECT COUNT(*)::int FROM pg_policies WHERE schemaname = 'marketplace')),
    ('roles',            5, (SELECT COUNT(*)::int FROM pg_roles
                             WHERE rolname IN ('mp_viewer','mp_staff','mp_customer','cust_pedro','cust_aisha'))),
    ('columns without a comment', 0,
                            (SELECT COUNT(*)::int FROM pg_attribute a
                             JOIN pg_class c ON c.oid = a.attrelid
                             WHERE c.relnamespace = 'marketplace'::regnamespace
                             AND c.relkind = 'r' AND a.attnum > 0 AND NOT a.attisdropped
                             AND col_description(c.oid, a.attnum) IS NULL)),
    ('rows: customer',   5, (SELECT COUNT(*)::int FROM customer)),
    ('rows: product_variant', 14, (SELECT COUNT(*)::int FROM product_variant)),
    ('rows: order_header', 7, (SELECT COUNT(*)::int FROM order_header)),
    ('rows: order_item', 13, (SELECT COUNT(*)::int FROM order_item)),
    ('rows: payment',    8, (SELECT COUNT(*)::int FROM payment)),
    ('rows: app_user',   2, (SELECT COUNT(*)::int FROM app_user)),
    ('order totals match their lines', 0,
                            (SELECT COUNT(*)::int FROM order_header o
                             WHERE o.total_amount <> fn_order_total(o.order_id)))
)
SELECT check_name, expected, actual,
       CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM   checks;
