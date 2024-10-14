provider "aws" {
  region = var.region.primary
}

provider "aws" {
  region = var.region.secondary
  alias  = "secondary"
}

resource "random_integer" "this" {
  min = 0
  max = 253
}

locals {
  cidr_block = {
    primary : "192.168.${random_integer.this.result}.0/24",
    primary_peer : "192.168.${random_integer.this.result + 1}.0/24"
    secondary_peer : "192.168.${random_integer.this.result + 2}.0/24"
  }
}

resource "aws_vpc" "primary" {
  for_each = {
    for k, v in local.cidr_block :
    k => v
    if startswith(k, "primary")
  }

  cidr_block = each.value

  tags = { Name : format("${var.name} %s", title(replace(each.key, "_", " "))) }
}

resource "aws_default_security_group" "primary" {
  for_each = aws_vpc.primary

  vpc_id = each.value.id

  tags = each.value.tags
}

resource "aws_vpc_security_group_egress_rule" "primary" {
  for_each = aws_vpc.primary

  security_group_id = aws_default_security_group.primary[each.key].id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1

  tags = each.value.tags

  depends_on = [aws_default_security_group.primary]
}

resource "aws_vpc_security_group_ingress_rule" "primary_ssh" {
  for_each = aws_vpc.primary

  security_group_id = aws_default_security_group.primary[each.key].id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  description = "${each.value.tags.Name} SSH"

  tags = { Name : "${each.value.tags.Name} SSH" }

  depends_on = [aws_default_security_group.primary]
}

resource "aws_default_route_table" "primary" {
  for_each = aws_vpc.primary

  default_route_table_id = aws_vpc.primary[each.key].default_route_table_id

  tags = each.value.tags
}

resource "aws_internet_gateway" "primary" {
  for_each = aws_vpc.primary

  tags = each.value.tags
}

resource "aws_internet_gateway_attachment" "primary" {
  for_each = aws_vpc.primary

  internet_gateway_id = aws_internet_gateway.primary[each.key].id
  vpc_id              = each.value.id
}

resource "aws_route" "primary_default" {
  for_each = aws_vpc.primary

  route_table_id         = aws_default_route_table.primary[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.primary[each.key].id

  depends_on = [aws_internet_gateway_attachment.primary]
}

data "aws_availability_zones" "primary" {
  state = "available"
}

resource "random_shuffle" "primary" {
  input = data.aws_availability_zones.primary.names

  result_count = 1
}

resource "aws_subnet" "primary" {
  for_each = aws_vpc.primary

  vpc_id = each.value.id

  cidr_block                          = each.value.cidr_block
  availability_zone                   = random_shuffle.primary.result.0
  map_public_ip_on_launch             = true
  private_dns_hostname_type_on_launch = "resource-name"

  tags = each.value.tags
}

resource "aws_route_table_association" "primary" {
  for_each = aws_vpc.primary

  subnet_id      = aws_subnet.primary[each.key].id
  route_table_id = aws_default_route_table.primary[each.key].id
}

resource "aws_vpc" "secondary" {
  cidr_block = local.cidr_block.secondary_peer

  tags = { Name : "${var.name} Secondary" }

  provider = aws.secondary
}

resource "aws_default_security_group" "secondary" {
  vpc_id = aws_vpc.secondary.id

  tags = aws_vpc.secondary.tags

  provider = aws.secondary
}

resource "aws_vpc_security_group_egress_rule" "secondary" {
  security_group_id = aws_default_security_group.secondary.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1

  tags = aws_vpc.secondary.tags

  depends_on = [aws_default_security_group.secondary]

  provider = aws.secondary
}

resource "aws_vpc_security_group_ingress_rule" "secondary_ssh" {
  security_group_id = aws_default_security_group.secondary.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  description = "${aws_vpc.secondary.tags.Name} SSH"

  tags = { Name : "${aws_vpc.secondary.tags.Name} SSH" }

  depends_on = [aws_default_security_group.secondary]

  provider = aws.secondary
}

resource "aws_default_route_table" "secondary" {
  default_route_table_id = aws_vpc.secondary.default_route_table_id

  tags = aws_vpc.secondary.tags

  provider = aws.secondary
}

resource "aws_internet_gateway" "secondary" {
  tags = aws_vpc.secondary.tags

  provider = aws.secondary
}

resource "aws_internet_gateway_attachment" "secondary" {
  internet_gateway_id = aws_internet_gateway.secondary.id
  vpc_id              = aws_vpc.secondary.id

  provider = aws.secondary
}

resource "aws_route" "secondary_default" {
  route_table_id         = aws_default_route_table.secondary.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.secondary.id

  depends_on = [aws_internet_gateway_attachment.secondary]

  provider = aws.secondary
}

data "aws_availability_zones" "secondary" {
  state = "available"

  provider = aws.secondary
}

resource "random_shuffle" "secondary" {
  input = data.aws_availability_zones.secondary.names

  result_count = 1
}

resource "aws_subnet" "secondary" {
  vpc_id = aws_vpc.secondary.id

  cidr_block                          = aws_vpc.secondary.cidr_block
  availability_zone                   = random_shuffle.secondary.result.0
  map_public_ip_on_launch             = true
  private_dns_hostname_type_on_launch = "resource-name"

  tags = aws_vpc.secondary.tags

  provider = aws.secondary
}

resource "aws_route_table_association" "secondary" {
  subnet_id      = aws_subnet.secondary.id
  route_table_id = aws_default_route_table.secondary.id

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway" "primary" {
  description                        = "${var.name} Primary"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  security_group_referencing_support = "enable"

  tags = { Name : "${var.name} Primary" }
}

resource "aws_ec2_transit_gateway_route_table" "primary" {
  transit_gateway_id = aws_ec2_transit_gateway.primary.id

  tags = aws_ec2_transit_gateway.primary.tags
}

resource "aws_ec2_transit_gateway_vpc_attachment" "primary" {
  for_each = aws_vpc.primary

  subnet_ids         = [aws_subnet.primary[each.key].id]
  transit_gateway_id = aws_ec2_transit_gateway.primary.id
  vpc_id             = each.value.id

  security_group_referencing_support = "enable"

  tags = { Name : each.value.tags.Name }
}

resource "aws_ec2_transit_gateway_route_table_propagation" "primary" {
  for_each = aws_vpc.primary

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.primary[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary.id
}

resource "aws_ec2_transit_gateway_route_table_association" "primary" {
  for_each = aws_vpc.primary

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.primary[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary.id
}

resource "aws_ec2_transit_gateway_route" "primary" {
  for_each = aws_vpc.primary

  destination_cidr_block         = each.value.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.primary[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary.id
}

resource "aws_ec2_transit_gateway" "secondary" {
  description                        = "${var.name} Secondary"
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  security_group_referencing_support = "enable"

  tags = { Name : "${var.name} Secondary" }

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_route_table" "secondary" {
  transit_gateway_id = aws_ec2_transit_gateway.secondary.id

  tags = aws_ec2_transit_gateway.secondary.tags

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_vpc_attachment" "secondary" {
  subnet_ids         = [aws_subnet.secondary.id]
  transit_gateway_id = aws_ec2_transit_gateway.secondary.id
  vpc_id             = aws_vpc.secondary.id

  security_group_referencing_support = "enable"

  tags = { Name : aws_vpc.secondary.tags.Name }

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_route_table_propagation" "secondary" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secondary.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary.id

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_route_table_association" "secondary" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.secondary.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary.id

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  peer_region             = var.region.secondary
  peer_transit_gateway_id = aws_ec2_transit_gateway.secondary.id
  transit_gateway_id      = aws_ec2_transit_gateway.primary.id

  tags = aws_vpc.secondary.tags
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.this.id

  tags = aws_vpc.secondary.tags

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_route_table_association" "primary_secondary" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.this]
}

resource "aws_ec2_transit_gateway_route_table_association" "secondary_primary" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.this]

  provider = aws.secondary
}

resource "aws_ec2_transit_gateway_route" "primary_secondary" {
  destination_cidr_block         = aws_vpc.secondary.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.primary.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.this]
}

resource "aws_ec2_transit_gateway_route" "secondary_primary" {
  for_each = aws_vpc.primary

  destination_cidr_block         = aws_vpc.primary[each.key].cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.secondary.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.this]

  provider = aws.secondary
}

resource "aws_route" "primary_tgw" {
  for_each = {
    for k, v in zipmap(keys(aws_vpc.primary), reverse(keys(aws_vpc.primary))) :
    k => {
      route_table_id : aws_default_route_table.primary[k].id,
      destination_cidr_block : aws_vpc.primary[v].cidr_block,
    }
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.primary.id
}

resource "aws_route" "primary_tgw_secondary" {
  for_each = aws_vpc.primary

  route_table_id = aws_default_route_table.primary[each.key].id

  destination_cidr_block = aws_vpc.secondary.cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.primary.id
}

resource "aws_route" "secondary_tgw_primary" {
  for_each = aws_vpc.primary

  route_table_id = aws_default_route_table.secondary.id

  destination_cidr_block = aws_vpc.primary[each.key].cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.secondary.id

  provider = aws.secondary
}

resource "aws_vpc_security_group_ingress_rule" "primary_tgw" {
  for_each = zipmap(keys(aws_vpc.primary), reverse(keys(aws_vpc.primary)))

  security_group_id = aws_default_security_group.primary[each.key].id

  referenced_security_group_id = aws_default_security_group.primary[each.value].id
  ip_protocol                  = -1
  description                  = aws_vpc.primary[each.value].tags.Name

  tags = aws_vpc.primary[each.value].tags

  depends_on = [aws_ec2_transit_gateway_route_table_association.primary]
}

resource "aws_vpc_security_group_ingress_rule" "primary_tgw_secondary" {
  for_each = aws_vpc.primary

  security_group_id = aws_default_security_group.secondary.id

  cidr_ipv4   = aws_vpc.primary[each.key].cidr_block
  ip_protocol = -1
  description = aws_vpc.primary[each.key].tags.Name

  tags = aws_vpc.primary[each.key].tags

  provider = aws.secondary
}

resource "aws_vpc_security_group_ingress_rule" "secondary_tgw_primary" {
  for_each = aws_vpc.primary

  security_group_id = aws_default_security_group.primary[each.key].id

  cidr_ipv4   = aws_vpc.secondary.cidr_block
  ip_protocol = -1
  description = aws_vpc.secondary.tags.Name

  tags = aws_vpc.secondary.tags
}

resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "random_pet" "this" {}

resource "local_sensitive_file" "this" {
  filename = "${path.module}/${random_pet.this.id}"

  content         = tls_private_key.this.private_key_openssh
  file_permission = "0600"
}

resource "aws_key_pair" "primary" {
  key_name   = random_pet.this.id
  public_key = tls_private_key.this.public_key_openssh
}

module "primary_instance" {
  for_each = aws_vpc.primary

  source = "./modules/instance"

  key_name           = aws_key_pair.primary.key_name
  subnet_id          = aws_subnet.primary[each.key].id
  security_group_ids = [aws_default_security_group.primary[each.key].id]
  tags               = each.value.tags
}

resource "aws_key_pair" "secondary" {
  key_name   = random_pet.this.id
  public_key = tls_private_key.this.public_key_openssh

  provider = aws.secondary
}

module "secondary_instance" {
  source = "./modules/instance"

  key_name           = aws_key_pair.secondary.key_name
  subnet_id          = aws_subnet.secondary.id
  security_group_ids = [aws_default_security_group.secondary.id]
  tags               = aws_vpc.secondary.tags

  providers = {
    aws = aws.secondary
  }
}
