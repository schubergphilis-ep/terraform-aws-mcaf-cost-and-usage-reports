provider "aws" {}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "cur_kms" {
  source  = "schubergphilis-ep/mcaf-kms/aws"
  version = "~> 1.0.0"

  name = "cur"
}

module "cur" {
  providers = { aws.us-east-1 = aws.us-east-1 }

  source      = "../.."
  kms_key_arn = module.cur_kms.arn
}
