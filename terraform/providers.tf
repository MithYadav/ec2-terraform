terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }

  backend "s3" {
    bucket         = "ec2-terraform-state-bucket-373447294485"
    key            = "ec2/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ec2-terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}
