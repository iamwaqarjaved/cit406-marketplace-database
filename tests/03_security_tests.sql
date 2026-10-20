-- =====================================================================
-- CIT 406 - Term Project: Multi-Vendor E-Commerce Marketplace
-- tests/03_security_tests.sql - proves the roles (migration 005) and the
-- row-level security policy (migration 006) work.
--
-- In pgAdmin: highlight SET ROLE together with the statement under it and
-- run them; then run RESET ROLE; ON ITS OWN before the next test.
-- "DENIED" tests are expected to fail with: permission denied for table ...
-- T4 changes one stock level (audit trigger logs mp_staff); rerun
-- seed/seed.sql to reset.
-- =====================================================================

SET search_path TO marketplace;

-- R. Privileges granted to the two staff roles
SELECT grantee, table_name, privilege_type
FROM   information_schema.role_table_grants
WHERE  grantee IN ('mp_viewer', 'mp_staff')
ORDER  BY grantee, table_name, privilege_type;

SELECT grantee, table_name, column_name, privilege_type
FROM   information_schema.column_privileges
WHERE  grantee = 'mp_staff' AND privilege_type = 'UPDATE'
ORDER  BY column_name;


-- ---- Tests as mp_viewer -------------------------------------------------
-- T1. ALLOWED: viewer reads the catalog
SET ROLE mp_viewer;
SELECT current_user, product_name, sku, selling_price, stock_status
FROM   v_storefront_catalog
ORDER  BY product_name, sku
LIMIT  5;

RESET ROLE;   -- run on its own after every test

-- T2. DENIED: viewer tries to change a price
--     expect ERROR: permission denied for table product_variant
SET ROLE mp_viewer;
UPDATE product_variant SET price_override = 1.00
WHERE  product_id = 1 AND sku = 'EB-BLK';

RESET ROLE;

-- T3. DENIED: viewer tries to read customer records
--     expect ERROR: permission denied for table customer
SET ROLE mp_viewer;
SELECT * FROM customer;

RESET ROLE;


-- ---- Tests as mp_staff --------------------------------------------------
-- T4. ALLOWED: staff restocks a variant (audit trigger logs mp_staff)
SET ROLE mp_staff;
UPDATE product_variant SET stock_quantity = 50
WHERE  product_id = 6 AND sku = 'BP-45L-GRY';
SELECT current_user, product_id, sku, stock_quantity
FROM   product_variant
WHERE  product_id = 6 AND sku = 'BP-45L-GRY';

RESET ROLE;

-- T5. Proof from the admin side: the audit log recorded mp_staff
SELECT audit_id, sku, old_stock_quantity, new_stock_quantity, changed_by, changed_at
FROM   variant_audit
ORDER  BY audit_id DESC
LIMIT  3;

-- T6. DENIED: staff tries to change a column it was not granted
--     expect ERROR: permission denied for table product_variant
SET ROLE mp_staff;
UPDATE product_variant SET color = 'Red'
WHERE  product_id = 6 AND sku = 'BP-45L-GRY';

RESET ROLE;

-- T7. DENIED: staff tries to delete a variant
--     expect ERROR: permission denied for table product_variant
SET ROLE mp_staff;
DELETE FROM product_variant WHERE product_id = 6 AND sku = 'BP-45L-GRY';

RESET ROLE;

-- T8. DENIED: staff tries to read payments
--     expect ERROR: permission denied for table payment
SET ROLE mp_staff;
SELECT * FROM payment;

RESET ROLE;


-- ---- Row-level security on address ------------------------------------
-- S1. Show the policy
SELECT policyname, roles, cmd, qual
FROM   pg_policies
WHERE  schemaname = 'marketplace' AND tablename IN ('address', 'app_user');

-- S2. Admin view (table owner, not subject to the policy): all 7 addresses
SELECT current_user, address_id, customer_id, street, city
FROM   address
ORDER  BY address_id;

-- S3. User A: cust_pedro sees only Pedro's rows (customer_id 1)
SET ROLE cust_pedro;
SELECT current_user, address_id, customer_id, street, city
FROM   address
ORDER  BY address_id;

RESET ROLE;

-- S4. User B: cust_aisha sees only Aisha's rows (customer_id 2)
SET ROLE cust_aisha;
SELECT current_user, address_id, customer_id, street, city
FROM   address
ORDER  BY address_id;

RESET ROLE;

-- S5. Even an explicit filter for another customer returns nothing
SET ROLE cust_aisha;
SELECT current_user, COUNT(*) AS pedro_rows_visible_to_aisha
FROM   address
WHERE  customer_id = 1;

RESET ROLE;
