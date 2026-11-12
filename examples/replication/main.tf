provider "aws" {}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "cur" {
  providers = { aws.us-east-1 = aws.us-east-1 }

  source = "../.."

  kms_key_configuration = {
    iam_arns_administrator = ["arn:aws:iam::123456789012:role/key-admin"]
  }

  report_definitions = {
    cur2-daily-parquet = {
      compression = "PARQUET"
      format      = "PARQUET"
      overwrite   = "OVERWRITE_REPORT"
      s3_prefix   = "aws_cur" # Files are written to `aws_cur/cur2-daily-parquet/`.
      time_unit   = "DAILY"

      # Replicates `aws_cur/cur2-daily-parquet/` to the same prefix in each destination bucket. The destination bucket
      # policies and key policies must allow the role exposed in the `replication_role_arn` output.
      replications = {
        datalake = {
          dest_account_id  = "109876543210"
          dest_bucket_arn  = "arn:aws:s3:::datalake-prod-ingestion-bucket"
          dest_kms_key_arn = "arn:aws:kms:eu-central-1:109876543210:key/11111111-1111-1111-1111-111111111111"
        }
      }
    }
  }
}

output "replication_role_arn" {
  value = module.cur.replication_role_arn
}
