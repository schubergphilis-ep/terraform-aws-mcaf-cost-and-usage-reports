# terraform-aws-mcaf-cost-and-usage-reports

Terraform module to setup and manage AWS Cost and Usage reports.

> [!IMPORTANT]
> The AWS Cost and Usage Report service is only available in us-east-1 currently. The `aws_cur_report_definition` resource does not support a configurable region, so an aliased provider is still required to target us-east-1, even when using the AWS provider v6.
>
> If AWS Organizations is enabled, only the management / payer account can use this resource.
>
> By default, two commonly configured reports will be created. The costs related to these reports is around 5 to 10 dollars per month.

> [!TIP]
> We do not pin modules to versions in our examples. We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable.

## S3 prefix and cross-account replication

Report/export files are written to `<s3_prefix>/<key>/` in the bucket. `s3_prefix` defaults to the report key, so by default files land under `<key>/<key>/`. Changing `s3_prefix` of an existing BCM Data Export replaces the export (the provider forces replacement); a legacy CUR report definition is updated in place. Existing files are not moved.

Set `replication` on a report to replicate its files to a bucket in another account. S3 replication keeps object keys, so files land under the same `<s3_prefix>/<key>/` in the destination bucket. The module then creates:

- an IAM role `<bucket_name>-replication` (see the `replication_role_arn` output) that S3 uses to replicate the objects;
- an `aws_s3_bucket_replication_configuration` with one rule per replicated report, which transfers object ownership to the destination account and re-encrypts the replicas with the destination KMS key;
- a KMS grant that lets the role decrypt objects with the KMS key created by this module. When you pass in your own key via `kms_key_arn`, you must allow the role to use `kms:Decrypt` in that key's policy yourself.

The destination account must allow the replication role in its bucket policy (`s3:ReplicateObject`, `s3:ReplicateDelete`, `s3:ReplicateTags`, `s3:ObjectOwnerOverrideToBucketOwner`) and in its KMS key policy (`kms:Encrypt`, `kms:GenerateDataKey`). See [examples/replication](examples/replication).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.19.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.19.0 |
| <a name="provider_aws.us-east-1"></a> [aws.us-east-1](#provider\_aws.us-east-1) | >= 6.19.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cur_reports_bucket"></a> [cur\_reports\_bucket](#module\_cur\_reports\_bucket) | schubergphilis-ep/mcaf-s3/aws | ~> 2.0.0 |
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | schubergphilis-ep/mcaf-kms/aws | ~> 3.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_bcmdataexports_export.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bcmdataexports_export) | resource |
| [aws_cur_report_definition.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cur_report_definition) | resource |
| [aws_iam_role.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_grant.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_grant) | resource |
| [aws_s3_bucket_replication_configuration.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.allow_access_to_curreports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.replication_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | optional bucket name for the AWS CUR reports bucket, if not provided a bucket name will be generated | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The KMS key ARN used for the bucket encryption. When set and a report uses 'replication', the key policy must allow the replication role (see the 'replication\_role\_arn' output) to use kms:Decrypt. | `string` | `null` | no |
| <a name="input_kms_key_configuration"></a> [kms\_key\_configuration](#input\_kms\_key\_configuration) | Access configuration for the KMS key created by this module. Only applicable when 'kms\_key\_arn' is null. 'iam\_arns\_administrator' grants permissions to manage the key (no cryptographic use). 'name' sets the alias/name of the created key. | <pre>object({<br/>    iam_arns_administrator = list(string)<br/>    name                   = optional(string, "cost-and-usage-reports")<br/>  })</pre> | `null` | no |
| <a name="input_legacy_reporting"></a> [legacy\_reporting](#input\_legacy\_reporting) | Enable legacy reporting | `bool` | `false` | no |
| <a name="input_report_definitions"></a> [report\_definitions](#input\_report\_definitions) | AWS Cost and Usage reports definitions. Key is used as report/export name. Files are stored under `<s3_prefix>/<key>/` in the bucket, where 's3\_prefix' defaults to the key. Set 'replication' to replicate the files under that prefix to a bucket in another account. Supports both legacy CUR (aws\_cur\_report\_definition) and modern BCM Data Exports (aws\_bcmdataexports\_export). | <pre>map(object({<br/>    additional_artifacts                  = optional(list(string), null) # Only used when legacy_reporting is `true`.<br/>    compression                           = string<br/>    format                                = string<br/>    include_capacity_reservation_data     = optional(bool, false)<br/>    include_iam_principal_data            = optional(bool, false) # Only used when legacy_reporting is `false`.<br/>    include_manual_discount_compatibility = optional(bool, false)<br/>    include_resources                     = optional(bool, true)<br/>    include_split_cost_allocation_data    = optional(bool, false)<br/>    overwrite                             = optional(string, "CREATE_NEW_REPORT")<br/>    s3_prefix                             = optional(string, null)<br/>    time_unit                             = string<br/>    replication = optional(object({<br/>      destination_account_id  = string<br/>      destination_bucket_arn  = string<br/>      destination_kms_key_arn = string<br/>      storage_class           = optional(string, null)<br/>    }), null)<br/>    }<br/>  ))</pre> | <pre>{<br/>  "daily-parquet": {<br/>    "additional_artifacts": [<br/>      "ATHENA"<br/>    ],<br/>    "compression": "PARQUET",<br/>    "format": "PARQUET",<br/>    "include_resources": true,<br/>    "overwrite": "OVERWRITE_REPORT",<br/>    "time_unit": "DAILY"<br/>  },<br/>  "hourly-gzip": {<br/>    "compression": "GZIP",<br/>    "format": "TEXT_OR_CSV",<br/>    "include_resources": true,<br/>    "overwrite": "CREATE_NEW_REPORT",<br/>    "time_unit": "HOURLY"<br/>  }<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the bucket that stores the Cost and Usage Reports |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the bucket that stores the Cost and Usage Reports |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used to encrypt the bucket, either created by this module or passed in via 'kms\_key\_arn' |
| <a name="output_replication_role_arn"></a> [replication\_role\_arn](#output\_replication\_role\_arn) | ARN of the IAM role used for S3 replication, null when no report has 'replication' configured |
<!-- END_TF_DOCS -->

## Licensing

100% Open Source and licensed under the Apache License Version 2.0. See [LICENSE](https://github.com/schubergphilis/terraform-aws-mcaf-cur-report/blob/main/LICENSE) for full details.
