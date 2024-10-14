variable "region" {
  type = object(
    {
      primary   = string
      secondary = string
    }
  )
  default = {
    primary   = "us-east-2",
    secondary = "us-west-2",
  }

  validation {
    condition     = var.region.primary != var.region.secondary
    error_message = "The value of region variable must specify two different regions."
  }
}

variable "name" {
  type    = string
  default = "AWS TGW VPC Peering"
}
