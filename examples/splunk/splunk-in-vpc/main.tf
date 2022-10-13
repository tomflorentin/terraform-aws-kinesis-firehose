resource "random_pet" "this" {
  length = 2
}

resource "aws_s3_bucket" "s3" {
  bucket        = "${var.name_prefix}-destination-bucket-${random_pet.this.id}"
  force_destroy = true
}

resource "aws_kms_key" "this" {
  description             = "${var.name_prefix}-kms-key"
  deletion_window_in_days = 7
}

module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "${var.name_prefix}-vpc"
  cidr            = var.vpc_cidr
  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-sg"
  description = "Security Group to kinesis firehose destination"
  vpc_id      = module.vpc.vpc_id
}

module "firehose" {
  source                                            = "../../../"
  name                                              = "${var.name_prefix}-delivery-stream"
  destination                                       = "splunk"
  buffer_interval                                   = 60
  splunk_hec_endpoint                               = var.splunk_hec_endpoint
  splunk_hec_endpoint_type                          = var.splunk_hec_endpoint_type
  splunk_hec_token                                  = var.splunk_hec_token
  splunk_hec_acknowledgment_timeout                 = 450
  splunk_retry_duration                             = 450
  s3_backup_mode                                    = "All"
  s3_backup_prefix                                  = "backup/"
  s3_backup_bucket_arn                              = aws_s3_bucket.s3.arn
  s3_backup_buffer_interval                         = 100
  s3_backup_buffer_size                             = 100
  s3_backup_compression                             = "GZIP"
  s3_backup_enable_encryption                       = true
  s3_backup_kms_key_arn                             = aws_kms_key.this.arn
  vpc_security_group_destination_configure_existing = true
  vpc_security_group_destination_ids                = [aws_security_group.this.id, module.vpc.default_security_group_id]
}
