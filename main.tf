module "network_us_east_1" {
  source        = "./modules/network"
  region        = "us-east-1"
  instance_type = "t2.micro"
  cidr_block    = "172.22.0.0/20"
  access_key    = "$ACCESSKEY"
  secret_key    = "$SECRETKEY"
}

module "network_eu_west_2" {
  source        = "./modules/network"
  region        = "eu-west-2"
  instance_type = "t2.micro"
  cidr_block    = "172.28.0.0/20"
  access_key    = "$ACCESSKEY"
  secret_key    = "$SECRETKEY"
}