-- =====================================================================
-- CIT 406 - Term Project: Multi-Vendor E-Commerce Marketplace
-- build.sql - rebuilds the whole database from nothing with psql:
--
--     psql "<connection string>" -f build.sql
--
-- It runs every migration in order, loads the seed data, then runs the
-- build check. Stops at the first error. Safe to rerun (migration 001
-- drops and recreates the "marketplace" schema).
--
-- No psql? Open each file below in pgAdmin or the Supabase SQL Editor
-- and run them in this same order (see README.md).
-- =====================================================================

\set ON_ERROR_STOP on
\echo '== 001 create schema and core tables'
\ir migrations/001_create_schema.sql
\echo '== 002 logic layer (views, functions, audit trigger, procedure)'
\ir migrations/002_logic_layer.sql
\echo '== 003 seller payouts and reorder levels'
\ir migrations/003_seller_payout_reorder_level.sql
\echo '== 004 indexes'
\ir migrations/004_indexes.sql
\echo '== 005 roles and privileges'
\ir migrations/005_roles_privileges.sql
\echo '== 006 row-level security'
\ir migrations/006_row_level_security.sql
\echo '== 007 data dictionary comments'
\ir migrations/007_comments.sql
\echo '== seed data'
\ir seed/seed.sql
\echo '== build check'
\ir tests/00_verify_build.sql
