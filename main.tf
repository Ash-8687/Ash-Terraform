provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_s3_bucket" "example" {
  bucket = "ash-terraform-demo-bucket-2026"
}
