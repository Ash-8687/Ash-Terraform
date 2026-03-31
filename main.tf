provider "aws" {
  region = "ap-southeast-2"
}

terraform {
  backend "s3" {
    bucket = "ash-terraform-demo-bucket-2026"
    key    = "terraform.tfstate"
    region = "ap-southeast-2"
  }
}
