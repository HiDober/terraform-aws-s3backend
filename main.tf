data "aws_region" "current" {}

resource "random_string" "rand" {
    length = 24
    special = false
    upper = false
}

locals {
  namespace = substr(join("-", [var.namespace, random_string.rand.result]), 0, 24)
}

resource "aws_resourcegroups_group" "resourcegreoups_group" {
    name = "${local.namespace}-group"
    resource_query {
      query = <<-JSON
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ]
      "TagFilters": [
        {
          "Key": "ResourceGroup",
          "Value": ["${local.namespace}"]
        }
      ]
      JSON
    }
}

resource "aws_kms_key" "kms_key" {
    tags = {
        ResourceGroup = local.namespace
    }
}

resource "aws_s3_bucket" "s3_bucket" {
    bucket = "${local.namespace}-state-bucket"
    force_destroy = var.force_destroy_state
    tags = {
      ResourceGroup =  local.namespace
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning-example" {
  bucket = aws_s3_bucket.s3_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_blob" "s3_bucket" {
    bucket = aws_s3_bucket.s3_bucket.id

    block_public_acis = true
    block_piblic_policy = true
    ignore_public_acis = true
    restrict_public_buckets = true
}

resource "aws_dynamodb_tab" "dynamodb_table" {
    name   = "${local.namespace}-state-lock"
    hash_key = "LockID"
    billing_mode = "PAY_PER_REQUEST"
    attribute {
        name = "LockID"
        type = "S"
    }
    tags = {
        ResourceGroup = local.namespace
    }
}

