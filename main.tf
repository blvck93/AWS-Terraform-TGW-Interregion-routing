module "network_us_east_1" {
  source        = "./modules/network"
  region        = "us-east-1"
  vpc_count     = "3"
  instance_type = "t2.micro"
  vpc_names     = ["Shared", "Production", "NonProduction"]
}

module "network_eu_west_2" {
  source        = "./modules/network"
  region        = "eu-west-2"
  vpc_count     = "3"
  instance_type = "t2.micro"
  vpc_names     = ["Shared", "Production", "NonProduction"]
}
