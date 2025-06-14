package terraform.validation

import rego.v1

deny contains msg if {
  input.resource.type == "aws_s3_bucket"
  input.resource.public
  msg := "Public S3 buckets are not allowed"
}
