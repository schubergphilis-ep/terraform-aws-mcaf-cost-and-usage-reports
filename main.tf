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

  # Data Exports does not support `SELECT *`, so all CUR 2.0 columns are listed explicitly. Columns that are
  # added or removed by a table configuration are kept separate and only selected when they exist in the table.
  # https://docs.aws.amazon.com/cur/latest/userguide/table-dictionary-cur2.html
  cur2_columns = [
    "bill_bill_type",
    "bill_billing_entity",
    "bill_billing_period_end_date",
    "bill_billing_period_start_date",
    "bill_invoice_id",
    "bill_invoicing_entity",
    "bill_payer_account_id",
    "bill_payer_account_name",
    "cost_category",
    "discount_bundled_discount",
    "identity_line_item_id",
    "identity_time_interval",
    "line_item_availability_zone",
    "line_item_blended_cost",
    "line_item_blended_rate",
    "line_item_currency_code",
    "line_item_legal_entity",
    "line_item_line_item_description",
    "line_item_line_item_type",
    "line_item_net_unblended_cost",
    "line_item_net_unblended_rate",
    "line_item_normalization_factor",
    "line_item_normalized_usage_amount",
    "line_item_operation",
    "line_item_product_code",
    "line_item_tax_type",
    "line_item_unblended_cost",
    "line_item_unblended_rate",
    "line_item_usage_account_id",
    "line_item_usage_account_name",
    "line_item_usage_amount",
    "line_item_usage_end_date",
    "line_item_usage_start_date",
    "line_item_usage_type",
    "line_item_user_identifier",
    "pricing_currency",
    "pricing_lease_contract_length",
    "pricing_offering_class",
    "pricing_public_on_demand_cost",
    "pricing_public_on_demand_rate",
    "pricing_purchase_option",
    "pricing_rate_code",
    "pricing_rate_id",
    "pricing_term",
    "pricing_unit",
    "product_comment",
    "product_fee_code",
    "product_fee_description",
    "product_from_location_type",
    "product_from_location",
    "product_from_region_code",
    "product_instance_family",
    "product_instance_type",
    "product_instancesku",
    "product_location_type",
    "product_location",
    "product_operation",
    "product_pricing_unit",
    "product_product_family",
    "product_region_code",
    "product_servicecode",
    "product_sku",
    "product_to_location_type",
    "product_to_location",
    "product_to_region_code",
    "product_usagetype",
    "product",
    "reservation_amortized_upfront_cost_for_usage",
    "reservation_amortized_upfront_fee_for_billing_period",
    "reservation_availability_zone",
    "reservation_effective_cost",
    "reservation_end_time",
    "reservation_modification_status",
    "reservation_net_amortized_upfront_cost_for_usage",
    "reservation_net_amortized_upfront_fee_for_billing_period",
    "reservation_net_effective_cost",
    "reservation_net_recurring_fee_for_usage",
    "reservation_net_unused_amortized_upfront_fee_for_billing_period",
    "reservation_net_unused_recurring_fee",
    "reservation_net_upfront_value",
    "reservation_normalized_units_per_reservation",
    "reservation_number_of_reservations",
    "reservation_recurring_fee_for_usage",
    "reservation_reservation_a_r_n",
    "reservation_start_time",
    "reservation_subscription_id",
    "reservation_total_reserved_normalized_units",
    "reservation_total_reserved_units",
    "reservation_units_per_reservation",
    "reservation_unused_amortized_upfront_fee_for_billing_period",
    "reservation_unused_normalized_unit_quantity",
    "reservation_unused_quantity",
    "reservation_unused_recurring_fee",
    "reservation_upfront_value",
    "resource_tags",
    "savings_plan_amortized_upfront_commitment_for_billing_period",
    "savings_plan_end_time",
    "savings_plan_instance_type_family",
    "savings_plan_net_amortized_upfront_commitment_for_billing_period",
    "savings_plan_net_recurring_commitment_for_billing_period",
    "savings_plan_net_savings_plan_effective_cost",
    "savings_plan_offering_type",
    "savings_plan_payment_option",
    "savings_plan_purchase_term",
    "savings_plan_recurring_commitment_for_billing_period",
    "savings_plan_region",
    "savings_plan_savings_plan_a_r_n",
    "savings_plan_savings_plan_effective_cost",
    "savings_plan_savings_plan_rate",
    "savings_plan_start_time",
    "savings_plan_total_commitment_to_date",
    "savings_plan_used_commitment",
    "tags",
  ]

  # Added by INCLUDE_CAPACITY_RESERVATION_DATA.
  cur2_capacity_reservation_columns = [
    "capacity_reservation_capacity_reservation_arn",
    "capacity_reservation_capacity_reservation_status",
    "capacity_reservation_capacity_reservation_type",
  ]

  # Removed by INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY.
  cur2_discount_columns = [
    "discount_total_discount",
    "discount",
  ]

  # Added by INCLUDE_SPLIT_COST_ALLOCATION_DATA.
  cur2_split_line_item_columns = [
    "split_line_item_actual_usage",
    "split_line_item_net_split_cost",
    "split_line_item_net_unused_cost",
    "split_line_item_parent_resource_id",
    "split_line_item_public_on_demand_split_cost",
    "split_line_item_public_on_demand_unused_cost",
    "split_line_item_reserved_usage",
    "split_line_item_split_cost",
    "split_line_item_split_usage_ratio",
    "split_line_item_split_usage",
    "split_line_item_unused_cost",
  ]

  cur2_query_statements = {
    for name, definition in var.report_definitions : name => format("SELECT %s FROM COST_AND_USAGE_REPORT", join(", ", concat(
      local.cur2_columns,
      definition.include_capacity_reservation_data ? local.cur2_capacity_reservation_columns : [],
      definition.include_iam_principal_data ? ["line_item_iam_principal"] : [],
      definition.include_manual_discount_compatibility ? [] : local.cur2_discount_columns,
      definition.include_resources ? ["line_item_resource_id"] : [],
      definition.include_split_cost_allocation_data ? local.cur2_split_line_item_columns : [],
    )))
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

################################################################################
# KMS key for the S3 bucket to store Cost and Usage Reports
################################################################################
module "kms_key" {
  count = var.kms_key_arn == null ? 1 : 0

  source  = "schubergphilis-ep/mcaf-kms/aws"
  version = "~> 3.0.0"

  name        = var.kms_key_configuration.name
  description = "KMS key used for encrypting s3 bucket to store Cost and Usage Reports"
  tags        = var.tags

  default_policy = {
    iam_arns_administrator = var.kms_key_configuration.iam_arns_administrator
  }
}

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
        values   = ["arn:aws:bcm-data-exports:us-east-1:${data.aws_caller_identity.current.account_id}:export/*"]
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
        values   = ["arn:aws:bcm-data-exports:us-east-1:${data.aws_caller_identity.current.account_id}:export/*"]
      }
    }
  }
}

module "cur_reports_bucket" {
  source  = "schubergphilis-ep/mcaf-s3/aws"
  version = "~> 2.0.0"

  name        = local.cur_reports_bucket_name
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : module.kms_key[0].arn
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
      query_statement = local.cur2_query_statements[each.key]

      table_configurations = {
        COST_AND_USAGE_REPORT = {
          INCLUDE_CAPACITY_RESERVATION_DATA     = each.value.include_capacity_reservation_data ? "TRUE" : "FALSE"
          INCLUDE_IAM_PRINCIPAL_DATA            = each.value.include_iam_principal_data ? "TRUE" : "FALSE"
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
