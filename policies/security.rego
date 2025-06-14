# OPA Security Policies for Terraform

package terraform

import rego.v1

deny[msg] {
  input.resource.type == "aws_s3_bucket"
  input.resource.public
  msg := "Public S3 buckets are not allowed"
}

