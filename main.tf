module "network_us_east_1" {
  source        = "./modules/network"
  region        = "us-east-1"
  instance_type = "t2.micro"
  cidr_block    = "172.22.0.0/20"
#  access_key    = "$ACCESSKEY"
#  secret_key    = "$SECRETKEY"
}

module "network_eu_west_2" {
  source        = "./modules/network"
  region        = "eu-west-2"
  instance_type = "t2.micro"
  cidr_block    = "172.28.0.0/20"
#  access_key    = "$ACCESSKEY"
#  secret_key    = "$SECRETKEY"
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# AWS providers for different regions
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
#  access_key    = "$ACCESSKEY"
#  secret_key    = "$SECRETKEY"  
}

provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2"
#  access_key    = "$ACCESSKEY"
#  secret_key    = "$SECRETKEY"  
}

# Create TGW Peering Connection
resource "aws_ec2_transit_gateway_peering_attachment" "peer_us_east_1_to_eu_west_2" {
  provider                  = aws.us-east-1
  transit_gateway_id        = module.network_us_east_1.transit_gateway_id
  peer_transit_gateway_id   = module.network_eu_west_2.transit_gateway_id
  peer_region               = "eu-west-2"
  peer_account_id           = data.aws_caller_identity.current.account_id

  tags = {
    Name = "InterRegion-TGW-Attachment"
  }

  depends_on = [
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

# Accept TGW Peering Connection in Peer Region
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "accepter" {
  provider                  = aws.eu-west-2
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

# Static routes to Peering attachment
resource "aws_ec2_transit_gateway_route" "route_propagation_us_east_1_rt_shared" {
  transit_gateway_route_table_id = module.network_us_east_1.tgw_rt_shared_id
  destination_cidr_block         = module.network_eu_west_2.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2,
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

resource "aws_ec2_transit_gateway_route" "route_propagation_us_east_1_rt_production" {
  transit_gateway_route_table_id = module.network_us_east_1.tgw_rt_production_id
  destination_cidr_block         = module.network_eu_west_2.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2,
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

resource "aws_ec2_transit_gateway_route" "route_propagation_us_east_1_rt_nonproduction" {
  transit_gateway_route_table_id = module.network_us_east_1.tgw_rt_nonproduction_id
  destination_cidr_block         = module.network_eu_west_2.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2,
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

resource "aws_ec2_transit_gateway_route" "route_propagation_eu_west_2_rt_shared" {
  transit_gateway_route_table_id = module.network_eu_west_2.tgw_rt_shared_id
  destination_cidr_block         = module.network_us_east_1.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2,
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

resource "aws_ec2_transit_gateway_route" "route_propagation_eu_west_2_rt_production" {
  transit_gateway_route_table_id = module.network_eu_west_2.tgw_rt_production_id
  destination_cidr_block         = module.network_us_east_1.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2,
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

resource "aws_ec2_transit_gateway_route" "route_propagation_eu_west_2_rt_nonproduction" {
  transit_gateway_route_table_id = module.network_eu_west_2.tgw_rt_nonproduction_id
  destination_cidr_block         = module.network_us_east_1.cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2.id

  depends_on = [
    aws_ec2_transit_gateway_peering_attachment.peer_us_east_1_to_eu_west_2,
    module.network_us_east_1,
    module.network_eu_west_2
  ]
}

