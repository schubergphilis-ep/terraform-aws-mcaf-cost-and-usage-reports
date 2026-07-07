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

## Resources

| Name | Type |
|------|------|
| [aws_bcmdataexports_export.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bcmdataexports_export) | resource |
| [aws_cur_report_definition.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cur_report_definition) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.allow_access_to_curreports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The KMS key ARN used for the bucket encryption | `string` | n/a | yes |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | optional bucket name for the AWS CUR reports bucket, if not provided a bucket name will be generated | `string` | `null` | no |
| <a name="input_legacy_reporting"></a> [legacy\_reporting](#input\_legacy\_reporting) | Enable legacy reporting | `bool` | `false` | no |
| <a name="input_report_definitions"></a> [report\_definitions](#input\_report\_definitions) | AWS Cost and Usage reports definitions. Key is used as report/export name and as prefix in the s3 bucket to store the report/export files. Supports both legacy CUR (aws\_cur\_report\_definition) and modern BCM Data Exports (aws\_bcmdataexports\_export). | <pre>map(object({<br/>    additional_artifacts                  = optional(list(string), null) # Only used when legacy_reporting is `true`.<br/>    compression                           = string<br/>    format                                = string<br/>    include_capacity_reservation_data     = optional(bool, false)<br/>    include_manual_discount_compatibility = optional(bool, false)<br/>    include_resources                     = optional(bool, true)<br/>    include_split_cost_allocation_data    = optional(bool, false)<br/>    overwrite                             = optional(string, "CREATE_NEW_REPORT")<br/>    time_unit                             = string<br/>    }<br/>  ))</pre> | <pre>{<br/>  "daily-parquet": {<br/>    "additional_artifacts": [<br/>      "ATHENA"<br/>    ],<br/>    "compression": "PARQUET",<br/>    "format": "PARQUET",<br/>    "include_resources": true,<br/>    "overwrite": "OVERWRITE_REPORT",<br/>    "time_unit": "DAILY"<br/>  },<br/>  "hourly-gzip": {<br/>    "compression": "GZIP",<br/>    "format": "TEXT_OR_CSV",<br/>    "include_resources": true,<br/>    "overwrite": "CREATE_NEW_REPORT",<br/>    "time_unit": "HOURLY"<br/>  }<br/>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

## Licensing

100% Open Source and licensed under the Apache License Version 2.0. See [LICENSE](https://github.com/schubergphilis/terraform-aws-mcaf-cur-report/blob/main/LICENSE) for full details.
