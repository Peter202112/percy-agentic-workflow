# Restricted Migration Tables

Enforced by `lib/rubocop/cop/custom/migration_table_restrictions.rb`.

## RESTRICTED_TABLES

These tables have millions of rows. Direct DDL causes extended locks in MySQL 8.0.

| Table | Description |
|-------|-------------|
| snapshots | Build snapshots — core entity |
| comparisons | Visual comparisons — highest volume |
| builds | CI build records |
| screenshots | Screenshot images |
| snapshot_resources | Resources per snapshot |
| master_snapshots | Baseline snapshots |
| resource_manifests | Resource manifest metadata |
| resources | Uploaded resources (images, DOM) |
| images | Processed image data |
| base_build_strategies | Build baseline selection |
| subscriptions | Billing subscriptions |

## Checked Operations

The RuboCop cop flags these operations on restricted tables:
1. `execute` with ALTER TABLE
2. `add_column`
3. `rename_column`
4. `add_index`
5. `remove_index`
6. `remove_column`
7. `change_column`

## Override

Use `# rubocop:disable Custom/MigrationTableRestrictions` with a comment explaining the gh-ost plan.
