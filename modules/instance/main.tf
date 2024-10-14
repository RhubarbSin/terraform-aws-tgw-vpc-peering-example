terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_ssm_parameter" "this" {
  name = var.ssm_parameter_name

  with_decryption = false
}

data "aws_ami" "this" {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.this.value]
  }
}

data "aws_ec2_instance_types" "this" {
  filter {
    name   = "burstable-performance-supported"
    values = ["true"]
  }

  filter {
    name   = "current-generation"
    values = ["true"]
  }

  filter {
    name   = "memory-info.size-in-mib"
    values = ["512"]
  }

  filter {
    name   = "processor-info.supported-architecture"
    values = [data.aws_ami.this.architecture]
  }
}

data "aws_ec2_instance_type" "this" {
  instance_type = data.aws_ec2_instance_types.this.instance_types.0
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.this.id
  associate_public_ip_address = var.associate_public_ip_address
  instance_type               = data.aws_ec2_instance_type.this.id
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  volume_tags                 = var.tags
  vpc_security_group_ids      = var.security_group_ids

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = var.tags
}
