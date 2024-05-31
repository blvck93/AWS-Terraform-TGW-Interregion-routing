variable "region" {}
variable "instance_type" {}
variable "cidr_block" {}

locals {
  vpc_names = ["Shared", "Production", "NonProduction"]
  vpc_count = "3"
}

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  count = local.vpc_count

  cidr_block           = cidrsubnet(var.cidr_block, 2, count.index)
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.vpc_names[count.index]
  }
}

resource "aws_internet_gateway" "main" {
  count = local.vpc_count

  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "InternetGateway-${local.vpc_names[count.index]}"
  }
}

resource "aws_subnet" "public" {
  count = local.vpc_count

  vpc_id            = aws_vpc.main[count.index].id
  cidr_block        = cidrsubnet(aws_vpc.main[count.index].cidr_block, 8, 0)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "PublicSubnet-${local.vpc_names[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = local.vpc_count

  vpc_id            = aws_vpc.main[count.index].id
  cidr_block        = cidrsubnet(aws_vpc.main[count.index].cidr_block, 8, 1)
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "PrivateSubnet-${local.vpc_names[count.index]}"
  }
}

resource "aws_route_table" "public" {
  count = local.vpc_count

  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "rt-public-${local.vpc_names[count.index]}"
  }
}

resource "aws_route_table" "private" {
  count = local.vpc_count

  vpc_id = aws_vpc.main[count.index].id

  tags = {
    Name = "rt-private-${local.vpc_names[count.index]}"
  }
}

resource "aws_route" "public_default_route" {
  count = local.vpc_count

  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[count.index].id
}

resource "aws_route_table_association" "public" {
  count        = local.vpc_count
  subnet_id    = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private" {
  count        = local.vpc_count
  subnet_id    = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "main" {
  count = local.vpc_count
  name        = "lab-sg-1"
  description = "Allow ICMP and SSH traffic via Terraform"
  vpc_id = aws_vpc.main[count.index].id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-${local.vpc_names[count.index]}"
  }
}

resource "aws_instance" "public" {
  count = local.vpc_count

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.main[count.index].id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
              systemctl restart sshd
              service sshd restart
              echo "12qwaszx" | passwd --stdin ec2-user
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello World from Public Instance ${count.index + 1}" > /var/www/html/index.html
              EOF

  depends_on = [aws_security_group.main]

  tags = {
    Name = "PublicInstance-${local.vpc_names[count.index]}"
  }
}

resource "aws_ec2_transit_gateway" "tgw" {
  description = "Transit Gateway for VPC connectivity"
  tags = {
    Name = "MainTGW"
  }
}

resource "aws_ec2_transit_gateway_route_table" "tgw_rt_shared" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    Name = "tgw_rt_shared"
  }
}

resource "aws_ec2_transit_gateway_route_table" "tgw_rt_production" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    Name = "tgw_rt_production"
  }
}

resource "aws_ec2_transit_gateway_route_table" "tgw_rt_nonproduction" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    Name = "tgw_rt_nonproduction"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attachment" {
  count               = local.vpc_count
  subnet_ids          = [aws_subnet.public[count.index].id]
  transit_gateway_id  = aws_ec2_transit_gateway.tgw.id
  vpc_id              = aws_vpc.main[count.index].id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "${local.vpc_names[count.index]}-TGW-Attachment"
  }
}

# Ensure the TGW attachment is created before creating the routes
resource "aws_route" "public_tgw_route" {
  count = local.vpc_count

  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "172.27.0.0/16"
  gateway_id             = aws_ec2_transit_gateway.tgw.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

resource "aws_route" "private_tgw_route" {
  count = local.vpc_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "172.27.0.0/16"
  gateway_id             = aws_ec2_transit_gateway.tgw.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

# Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "tgw_association_shared" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_shared.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_association_production" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[1].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_production.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_association_nonproduction" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[2].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_nonproduction.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

# Route Table Propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propagation_shared_to_production" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_production.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propagation_shared_to_nonproduction" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_nonproduction.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propagation_production_to_shared" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[1].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_shared.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propagation_nonproduction_to_shared" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment[2].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_rt_shared.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tgw_attachment
  ]
}
