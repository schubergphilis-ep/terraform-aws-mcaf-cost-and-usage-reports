locals {
  cur_reports_bucket_name = var.bucket_name != null ? var.bucket_name : "aws-cur-reports-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"

  compression_map = {
    GZIP    = "GZIP"
    PARQUET = "Parquet"
  }

  format_map = {
    TEXT_OR_CSV = "textORcsv"
    PARQUET     = "Parquet"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

################################################################################
# S3 bucket to store Cost and Usage Reports
################################################################################

data "aws_iam_policy_document" "allow_access_to_curreports" {
  # Legacy CUR reporting policy
  dynamic "statement" {
    for_each = var.legacy_reporting ? { create = true } : {}

    content {
      principals {
        type        = "Service"
        identifiers = ["billingreports.amazonaws.com"]
      }

      actions = [
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy",
      ]

      resources = [
        "arn:aws:s3:::${local.cur_reports_bucket_name}"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = ["arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = var.legacy_reporting ? { create = true } : {}

    content {
      principals {
        type        = "Service"
        identifiers = ["billingreports.amazonaws.com"]
      }

      actions = [
        "s3:PutObject"
      ]

      resources = [
        "arn:aws:s3:::${local.cur_reports_bucket_name}/*"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = ["arn:aws:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  # Modern BCM Data Exports policy
  dynamic "statement" {
    for_each = var.legacy_reporting ? {} : { create = true }

    content {
      principals {
        type        = "Service"
        identifiers = ["bcm-data-exports.amazonaws.com"]
      }

      actions = [
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy",
      ]

      resources = [
        "arn:aws:s3:::${local.cur_reports_bucket_name}"
      ]

      condition {
        test     = "StringLike"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }

      condition {
        test     = "StringLike"
        variable = "aws:SourceArn"
        values   = ["arn:aws:bcm-data-exports:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:export/*"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.legacy_reporting ? {} : { create = true }

    content {
      principals {
        type        = "Service"
        identifiers = ["bcm-data-exports.amazonaws.com"]
      }

      actions = [
        "s3:PutObject"
      ]

      resources = [
        "arn:aws:s3:::${local.cur_reports_bucket_name}/*"
      ]

      condition {
        test     = "StringLike"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }

      condition {
        test     = "StringLike"
        variable = "aws:SourceArn"
        values   = ["arn:aws:bcm-data-exports:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:export/*"]
      }
    }
  }
}

module "cur_reports_bucket" {
  source  = "schubergphilis-ep/mcaf-s3/aws"
  version = "~> 2.0.0"

  name        = local.cur_reports_bucket_name
  kms_key_arn = var.kms_key_arn
  policy      = data.aws_iam_policy_document.allow_access_to_curreports.json
  tags        = var.tags

  lifecycle_rule = [
    {
      id      = "retention"
      enabled = true

      abort_incomplete_multipart_upload = {
        days_after_initiation = 14
      }

      expiration = {
        days = 730
      }

      transition = [
        {
          days          = 90
          storage_class = "INTELLIGENT_TIERING"
        }
      ]
    }
  ]
}

################################################################################
# Legacy Reporting
################################################################################

resource "aws_cur_report_definition" "default" {
  for_each = var.legacy_reporting ? var.report_definitions : {}

  provider = aws.us-east-1

  additional_artifacts   = each.value.additional_artifacts
  compression            = local.compression_map[each.value.compression]
  format                 = local.format_map[each.value.format]
  refresh_closed_reports = true
  report_name            = each.key
  report_versioning      = each.value.overwrite
  s3_bucket              = module.cur_reports_bucket.name
  s3_prefix              = each.key
  s3_region              = data.aws_region.current.region
  time_unit              = each.value.time_unit
  tags                   = var.tags

  additional_schema_elements = compact([
    each.value.include_resources ? "RESOURCES" : null,
    each.value.include_split_cost_allocation_data ? "SPLIT_COST_ALLOCATION_DATA" : null,
    each.value.include_manual_discount_compatibility ? "MANUAL_DISCOUNT_COMPATIBILITY" : null,
  ])
}

################################################################################
# Modern Reporting
################################################################################

resource "aws_bcmdataexports_export" "default" {
  for_each = var.legacy_reporting ? {} : var.report_definitions

  export {
    name = each.key

    data_query {
      query_statement = "SELECT * FROM COST_AND_USAGE_REPORT"

      table_configurations = {
        COST_AND_USAGE_REPORT = {
          INCLUDE_CAPACITY_RESERVATION_DATA     = each.value.include_capacity_reservation_data ? "TRUE" : "FALSE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = each.value.include_manual_discount_compatibility ? "TRUE" : "FALSE"
          INCLUDE_RESOURCES                     = each.value.include_resources ? "TRUE" : "FALSE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = each.value.include_split_cost_allocation_data ? "TRUE" : "FALSE"
          TIME_GRANULARITY                      = each.value.time_unit
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = module.cur_reports_bucket.name
        s3_prefix = each.key
        s3_region = data.aws_region.current.region

        s3_output_configurations {
          compression = each.value.compression
          format      = each.value.format
          output_type = "CUSTOM"
          overwrite   = each.value.overwrite
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }

  tags = var.tags
}
