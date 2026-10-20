# Changelog

All notable changes to the marketplace database. Each release maps to a CIT 406 project module.

## [1.0.0] - 2026-10-23 - Final release (Module 8)

### Added
- `migrations/` folder with ordered, rerunnable migrations and `build.sql` to run them all with psql.
- Logic layer (Module 6): `v_order_summary`, `v_storefront_catalog`, `fn_order_total`, `fn_seller_payout`, the `variant_audit` table with trigger `trg_variant_audit`, and procedure `sp_place_order`.
- `seller_payout` table and `product_variant.reorder_level` (migration 003).
- Roles `mp_viewer` and `mp_staff` with least-privilege grants (Module 7).
- Row-level security on `address` with customer roles, the `app_user` mapping table and policies `address_owner_only` and `app_user_self` (Module 7).
- `queries/portfolio_queries.sql`: the ten-query portfolio (Module 5).
- `tests/`: build check, logic layer tests, EXPLAIN ANALYZE performance tests and security tests.
- A description on every table and column (`COMMENT ON`), `docs/data-dictionary.md` generated from them, and `scripts/generate_data_dictionary.sql`.
- Updated ER diagram of the built schema (`docs/er-diagram.png`, `docs/er-diagram.md`).
- Step-by-step rebuild instructions in the README for psql, pgAdmin, the Supabase SQL Editor and Docker.

### Changed
- `schema.sql` moved to `migrations/001_create_schema.sql`; its foreign-key indexes moved to `migrations/004_indexes.sql`.
- `seed.sql` moved to `seed/seed.sql`; it now also resets `variant_audit` and loads the `app_user` mappings.
- Module 4 build screenshots moved to `docs/module4-build/`.
- `gitignore` renamed to `.gitignore` so Git actually uses it.

### Performance decision (Module 7)
- Candidate indexes on `order_header(order_date)` and `product_variant(stock_quantity)` were tested and not kept: the planner still chose sequential scans on the small project tables.

## [0.1.0] - 2026-09-28 - Physical schema (Module 4)

### Added
- `schema.sql`: the `marketplace` schema with 10 BCNF tables, keys, CHECK constraints, foreign keys with explicit referential actions, and foreign-key indexes.
- `seed.sql`: rerunnable sample data.
- README with setup instructions and ER diagram.
