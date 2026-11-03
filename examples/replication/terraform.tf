terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.19.0"
      configuration_aliases = [aws.us-east-1]
    }
  }
  required_version = ">= 1.9.0"
}
