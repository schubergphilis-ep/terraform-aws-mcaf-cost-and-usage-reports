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

      # Replicates `aws_cur/cur2-daily-parquet/` to the same prefix in the destination bucket. The destination bucket
      # policy and key policy must allow the role exposed in the `replication_role_arn` output.
      replication = {
        destination_account_id  = "210987654321"
        destination_bucket_arn  = "arn:aws:s3:::datalake-ingestion-bucket"
        destination_kms_key_arn = "arn:aws:kms:eu-central-1:210987654321:key/00000000-0000-0000-0000-000000000000"
      }
    }
  }
}

output "replication_role_arn" {
  value = module.cur.replication_role_arn
}
