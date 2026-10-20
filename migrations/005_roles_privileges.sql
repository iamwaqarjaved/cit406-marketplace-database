-- =====================================================================
-- CIT 406 - Database Design (Fall "A" 2026)
-- Term Project: Multi-Vendor E-Commerce Marketplace
-- Migration 005 - Roles and privileges (Module 7)
-- Author : Waqar Javed (250305023)
--
--   mp_viewer : read-only catalog analyst. Can read the storefront
--               catalog; cannot change data or read customer records.
--   mp_staff  : inventory staff. Can read catalog tables and update ONLY
--               stock_quantity and price_override on product_variant.
--               Cannot delete, cannot change other columns, cannot read
--               customers or payments.
--
-- Roles belong to the whole PostgreSQL cluster, not to the schema, so
-- they survive migration 001's DROP SCHEMA. This file creates them only
-- if missing and re-applies the grants. Safe to rerun.
-- Tests: tests/03_security_tests.sql
-- =====================================================================

SET search_path TO marketplace;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mp_viewer') THEN
        CREATE ROLE mp_viewer NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mp_staff') THEN
        CREATE ROLE mp_staff NOLOGIN;
    END IF;
END $$;

-- Let the account running the build switch into the roles for testing
-- (SET ROLE). On Supabase this is "postgres".
GRANT mp_viewer, mp_staff TO CURRENT_USER;

-- Viewer: read-only catalog
GRANT USAGE  ON SCHEMA marketplace TO mp_viewer;
GRANT SELECT ON category, product, product_variant, seller,
                v_storefront_catalog
      TO mp_viewer;

-- Staff: read catalog + update stock and price only
GRANT USAGE  ON SCHEMA marketplace TO mp_staff;
GRANT SELECT ON category, product, product_variant, seller,
                v_storefront_catalog
      TO mp_staff;
GRANT UPDATE (stock_quantity, price_override) ON product_variant TO mp_staff;

-- The audit trigger (migration 002) runs as the user making the change,
-- so staff may INSERT audit rows (but cannot read, change or delete them).
GRANT INSERT ON variant_audit TO mp_staff;
