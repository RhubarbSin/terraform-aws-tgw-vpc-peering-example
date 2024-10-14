variable "ssm_parameter_name" {
  type     = string
  nullable = false
  default  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

variable "associate_public_ip_address" {
  type    = bool
  default = null
}

variable "key_name" {
  type     = string
  nullable = false
}

variable "subnet_id" {
  type     = string
  nullable = false
}

variable "security_group_ids" {
  type     = list(string)
  nullable = false
}

variable "tags" {
  type    = map(string)
  default = null
}
