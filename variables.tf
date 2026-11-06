variable "bucket_name" {
  type        = string
  default     = null
  description = "optional bucket name for the AWS CUR reports bucket, if not provided a bucket name will be generated"
}

variable "kms_key_arn" {
  type        = string
  description = "The KMS key ARN used for the bucket encryption. When a report uses 'replication', the replication role gets a KMS grant to decrypt the objects, so the key must be in the same account."
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
      dest_account_id    = string
      dest_bucket_arn    = string
      dest_kms_key_arn   = string
      dest_storage_class = optional(string, null)
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
  description = "AWS Cost and Usage reports definitions. Key is used as report/export name. Files are stored under '<s3_prefix>/<key>/' in the bucket, where 's3_prefix' defaults to the key; set it to an empty string to store them under '<key>/'. Set 'replication' to replicate the files under that prefix to a bucket in another account. Supports both legacy CUR (aws_cur_report_definition) and modern BCM Data Exports (aws_bcmdataexports_export)."

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
      v.s3_prefix == null ? true : trim(v.s3_prefix, "/") == v.s3_prefix
    ])
    error_message = "s3_prefix must not start or end with a '/'."
  }

  validation {
    condition = !var.legacy_reporting || alltrue([
      for k, v in var.report_definitions : v.s3_prefix != "" || !try(contains(v.additional_artifacts, "ATHENA"), false)
    ])
    error_message = "s3_prefix must not be empty for a legacy report with the ATHENA additional artifact."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Map of tags"
}
