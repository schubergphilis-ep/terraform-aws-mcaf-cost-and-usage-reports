# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v2.0.0

### Key Changes

- A report can now replicate to more than one destination bucket.

#### Variables

The following variables have been modified:

- `report_definitions`:
  - `replication` (object) has been replaced by `replications` (map of objects). The map key names the destination and is used in the replication rule ID `<report key>-<destination name>`. Move an existing `replication` block into the map:

    ```hcl
    # Before
    replication = {
      dest_account_id  = "210987654321"
      dest_bucket_arn  = "arn:aws:s3:::datalake-ingestion-bucket"
      dest_kms_key_arn = "arn:aws:kms:eu-central-1:210987654321:key/00000000-0000-0000-0000-000000000000"
    }

    # After
    replications = {
      datalake = {
        dest_account_id  = "210987654321"
        dest_bucket_arn  = "arn:aws:s3:::datalake-ingestion-bucket"
        dest_kms_key_arn = "arn:aws:kms:eu-central-1:210987654321:key/00000000-0000-0000-0000-000000000000"
      }
    }
    ```

    The replication rule ID changes from `<report key>` to `<report key>-<destination name>`, which updates the bucket replication configuration in place. The replication role and its permissions are kept.

## Upgrading to v1.0.0

### Key Changes

- Added support for `aws_bcmdataexports_export`, which replaces `aws_cur_report_definition` by default.
  - If you still need to use `aws_cur_report_definition`, set `legacy_reporting = true`.
  - **If you use the default reports, this is the only required change.**

- If you use these reports for **Datadog**, you must set `legacy_reporting = true`. Datadog does not yet support BCM Data Exports.

- `aws_bcmdataexports_export` is mostly backward compatible with `aws_cur_report_definition`, with the following limitations:
  - `additional_artifacts` is not supported, this means no integration with Athena or Redshift is possible only with Amazon QuickSight.
  - If Athena or Redshift integration is required, continue using CUR (`legacy_reporting = true`)

- More information: [migrating from CUR to Data Exports (CUR 2.0)](https://docs.aws.amazon.com/cur/latest/userguide/dataexports-migrate.html).

#### Variables

The following variables have been modified:

- `report_definitions`:

  - `additional_schema_elements` has been replaced by:
    - `include_resources`
    - `include_split_cost_allocation_data`
    - `include_manual_discount_compatibility`

  - `refresh_closed_reports` has been removed and is now always `true`.

  - `report_versioning` has been replaced by `overwrite`.

  - `compression` values have changed in case. Supported values: `GZIP`, `PARQUET`

  - `format` values have changed in case. Supported values: `TEXTORCSV`, `PARQUET`
