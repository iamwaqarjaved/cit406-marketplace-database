-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Term Project: Multi-Vendor E-Commerce Marketplace
-- Migration 006 - Row-level security on address (Module 7)
-- Author : Waqar Javed (250305023)
--
-- address holds each customer's saved shipping addresses: private,
-- user-specific data. Each customer database role is mapped to one
-- customer_id in app_user, and the policy shows a customer only the
-- addresses whose customer_id matches their own.
--
--   mp_customer : group role holding the shared customer privileges
--   cust_pedro  : example customer login role (customer_id 1)
--   cust_aisha  : example customer login role (customer_id 2)
-- The app_user mapping rows are loaded by seed/seed.sql (they reference
-- customers, which do not exist until the seed runs).
--
-- The table owner (the account that ran the build) is not subject to
-- RLS, so admin queries still see every row. Safe to rerun.
-- Tests: tests/03_security_tests.sql
-- =====================================================================

SET search_path TO marketplace;

-- Customer roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mp_customer') THEN
        CREATE ROLE mp_customer NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cust_pedro') THEN
        CREATE ROLE cust_pedro NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cust_aisha') THEN
        CREATE ROLE cust_aisha NOLOGIN;
    END IF;
END $$;

GRANT mp_customer TO cust_pedro, cust_aisha;
GRANT cust_pedro, cust_aisha TO CURRENT_USER;      -- for SET ROLE testing
GRANT USAGE  ON SCHEMA marketplace TO mp_customer;
GRANT SELECT ON address            TO mp_customer;

-- Map each database role to its customer
CREATE TABLE IF NOT EXISTS app_user (
    role_name   TEXT    NOT NULL,
    customer_id INTEGER NOT NULL,
    CONSTRAINT app_user_pk          PRIMARY KEY (role_name),
    CONSTRAINT app_user_customer_uq UNIQUE (customer_id),
    -- Rule: a login mapping has no meaning without its customer.
    CONSTRAINT app_user_customer_fk FOREIGN KEY (customer_id)
        REFERENCES customer (customer_id)
        ON DELETE CASCADE ON UPDATE NO ACTION
);

-- Each customer may read ONLY their own mapping row (RLS on app_user too),
-- so no customer can discover which role belongs to another customer.
GRANT SELECT ON app_user TO mp_customer;
ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_user_self ON app_user;
CREATE POLICY app_user_self ON app_user
    FOR SELECT
    TO mp_customer
    USING (role_name = current_user);

-- The policy on address
ALTER TABLE address ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS address_owner_only ON address;
CREATE POLICY address_owner_only ON address
    FOR SELECT
    TO mp_customer
    USING (customer_id = (SELECT customer_id
                          FROM   app_user
                          WHERE  role_name = current_user));
