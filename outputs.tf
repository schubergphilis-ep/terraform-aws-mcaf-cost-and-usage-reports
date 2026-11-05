output "bucket_arn" {
  value       = module.cur_reports_bucket.arn
  description = "ARN of the bucket that stores the Cost and Usage Reports"
}

output "bucket_name" {
  value       = module.cur_reports_bucket.name
  description = "Name of the bucket that stores the Cost and Usage Reports"
}

output "kms_key_arn" {
  value       = local.kms_key_arn
  description = "ARN of the KMS key used to encrypt the bucket, either created by this module or passed in via 'kms_key_arn'"
}

output "replication_role_arn" {
  value       = module.cur_reports_bucket.replication_role_arn
  description = "ARN of the IAM role used for S3 replication, null when no report has 'replication' configured"
}
