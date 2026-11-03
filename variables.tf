variable "bucket_name" {
  type        = string
  default     = null
  description = "optional bucket name for the AWS CUR reports bucket, if not provided a bucket name will be generated"
}

variable "kms_key_arn" {
  type        = string
  description = "The KMS key ARN used for the bucket encryption. When set and a report uses 'replication', the key policy must allow the replication role (see the 'replication_role_arn' output) to use kms:Decrypt."
  default     = null
}

variable "kms_key_configuration" {
  type = object({
    iam_arns_administrator = list(string)
    name                   = optional(string, "cost-and-usage-reports")
  })
  default     = null
  description = "Access configuration for the KMS key created by this module. Only applicable when 'kms_key_arn' is null. 'iam_arns_administrator' grants permissions to manage the key (no cryptographic use). 'name' sets the alias/name of the created key."

  validation {
    condition     = var.kms_key_arn == null || var.kms_key_configuration == null
    error_message = "'kms_key_arn' and 'kms_key_configuration' are mutually exclusive; provide 'kms_key_arn' to use an existing key, or 'kms_key_configuration' to have the module create one, but not both."
  }

  validation {
    condition     = var.kms_key_arn != null || try(length(var.kms_key_configuration.iam_arns_administrator) > 0, false)
    error_message = "When 'kms_key_arn' is not provided, 'kms_key_configuration.iam_arns_administrator' must contain at least one IAM ARN to administer the KMS key created by this module."
  }
}

variable "legacy_reporting" {
  type        = bool
  default     = false
  description = "Enable legacy reporting"
}

variable "report_definitions" {
  type = map(object({
    additional_artifacts                  = optional(list(string), null) # Only used when legacy_reporting is `true`.
    compression                           = string
    format                                = string
    include_capacity_reservation_data     = optional(bool, false)
    include_iam_principal_data            = optional(bool, false) # Only used when legacy_reporting is `false`.
    include_manual_discount_compatibility = optional(bool, false)
    include_resources                     = optional(bool, true)
    include_split_cost_allocation_data    = optional(bool, false)
    overwrite                             = optional(string, "CREATE_NEW_REPORT")
    s3_prefix                             = optional(string, null)
    time_unit                             = string
    replication = optional(object({
      destination_account_id  = string
      destination_bucket_arn  = string
      destination_kms_key_arn = string
      storage_class           = optional(string, null)
    }), null)
    }
  ))
  default = {
    hourly-gzip = {
      compression       = "GZIP"
      format            = "TEXT_OR_CSV"
      include_resources = true
      overwrite         = "CREATE_NEW_REPORT"
      time_unit         = "HOURLY"
    },
    daily-parquet = {
      additional_artifacts = ["ATHENA"]
      compression          = "PARQUET"
      format               = "PARQUET"
      include_resources    = true
      overwrite            = "OVERWRITE_REPORT"
      time_unit            = "DAILY"
    }
  }
  description = "AWS Cost and Usage reports definitions. Key is used as report/export name. Files are stored under `<s3_prefix>/<key>/` in the bucket, where 's3_prefix' defaults to the key. Set 'replication' to replicate the files under that prefix to a bucket in another account. Supports both legacy CUR (aws_cur_report_definition) and modern BCM Data Exports (aws_bcmdataexports_export)."

  validation {
    condition = alltrue([
      for k, v in var.report_definitions : contains(["GZIP", "PARQUET"], v.compression)
    ])
    error_message = "Compression must be one of: GZIP, or PARQUET."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions : contains(["TEXT_OR_CSV", "PARQUET"], v.format)
    ])
    error_message = "Format must be one of: TEXT_OR_CSV or PARQUET."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions : contains(["CREATE_NEW_REPORT", "OVERWRITE_REPORT"], v.overwrite)
    ])
    error_message = "Overwrite must be either CREATE_NEW_REPORT or OVERWRITE_REPORT."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions : contains(["HOURLY", "DAILY", "MONTHLY"], v.time_unit)
    ])
    error_message = "Time unit must be one of: HOURLY, DAILY, or MONTHLY."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions :
      v.compression == "PARQUET" ? v.format == "PARQUET" : true
    ])
    error_message = "When compression is PARQUET, format must also be PARQUET."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions :
      v.s3_prefix == null ? true : can(regex("^[^/].*[^/]$|^[^/]$", v.s3_prefix))
    ])
    error_message = "s3_prefix must not be empty and must not start or end with a '/'."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions : v.replication == null ? true : alltrue([
        can(regex("^[0-9]{12}$", v.replication.destination_account_id)),
        startswith(v.replication.destination_bucket_arn, "arn:aws:s3:::"),
        startswith(v.replication.destination_kms_key_arn, "arn:aws:kms:"),
      ])
    ])
    error_message = "replication.destination_account_id must be a 12-digit AWS account ID, replication.destination_bucket_arn an S3 bucket ARN and replication.destination_kms_key_arn a KMS key ARN."
  }

  validation {
    condition = alltrue([
      for k, v in var.report_definitions : try(v.replication.storage_class, null) == null ? true : contains(
        ["DEEP_ARCHIVE", "GLACIER", "GLACIER_IR", "INTELLIGENT_TIERING", "ONEZONE_IA", "REDUCED_REDUNDANCY", "STANDARD", "STANDARD_IA"],
        v.replication.storage_class
      )
    ])
    error_message = "replication.storage_class must be one of: DEEP_ARCHIVE, GLACIER, GLACIER_IR, INTELLIGENT_TIERING, ONEZONE_IA, REDUCED_REDUNDANCY, STANDARD or STANDARD_IA."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Map of tags"
}
