provider "aws" {}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "cur" {
  providers = { aws.us-east-1 = aws.us-east-1 }

  source           = "../.."
  legacy_reporting = true

  kms_key_configuration = {
    iam_arns_administrator = ["arn:aws:iam::123456789012:role/key-admin"]
  }
}
