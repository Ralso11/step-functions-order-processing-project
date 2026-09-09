terraform {
  backend "s3" {
    bucket = "ralso11-terraform-state-2026"
    key    = "step-functions-order-processing-project/terraform.tfstate"
    region = "eu-central-1"
  }
}