# Changelog

All notable changes to this project are listed here. Dates are in UTC.

## 2.4.0 (2026-11-20)

### Added

- `export --format csv` writes one row per order (requested in #212).
- A `--since` flag for `report`, which takes a date or a duration like `7d`.
- Dark mode for the web dashboard, following the system setting.

### Changed

- The default page size for orders is now 50 instead of 20.
- Error messages name the field that failed, for example "email is empty".

### Fixed

- Totals no longer round twice when a discount and tax both apply.
- `import` stops at the first bad order instead of skipping it (see #198).

## 2.3.1 (2026-10-02)

### Fixed

- The search box on the orders page kept its old value after a reset.
- Time zones west of UTC showed orders on the wrong day in the report.

## 2.3.0 (2026-09-15)

### Added

- Saved filters for orders, shared with everyone on the account.
- Keyboard shortcuts: `g o` for orders and `g c` for customers.
