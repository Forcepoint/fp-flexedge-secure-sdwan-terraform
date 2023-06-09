provider "aws" {
  region = var.region
}

locals {
  default_tags = {
    TTL = 2
  }
  namespace = "smc-deployment"
}

module "smc" {
  source              = "../../"
  smc_ami_id          = var.image_name
  logserver_count     = var.logserver_count
  replica_count       = 0
  namespace           = local.namespace
  vpc_id              = aws_vpc.smc.id
  subnet_ids          = aws_subnet.smc.*.id
  mgmt_vm_size        = "m5.xlarge"
  log_vm_size         = "m5.xlarge"
  sshkey              = var.sshkey # Path to a public key local file
  username            = var.username
  password            = var.password
  kms_key_arns        = var.kms_key_arns
  wait_for_logservers = var.wait_for_logservers
  package_upgrade     = false
}


#We create a VPC. Usually, you have an existing VPC where to deploy the SMC
resource "aws_vpc" "smc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  tags                 = merge(local.default_tags, { Name = "${local.namespace}-smc-vpc" })
}

resource "aws_route_table" "smc" {
  vpc_id = aws_vpc.smc.id

  #A default route to the wild internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.smc.id
  }
  tags = merge(local.default_tags, { Name = "${local.namespace}-smc-rt" })
}

resource "aws_main_route_table_association" "smc" {
  vpc_id         = aws_vpc.smc.id
  route_table_id = aws_route_table.smc.id
}

data "aws_availability_zones" "smc" {
  state = "available"
}

resource "aws_subnet" "smc" {
  count             = length(data.aws_availability_zones.smc.names)
  vpc_id            = aws_vpc.smc.id
  availability_zone = data.aws_availability_zones.smc.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.smc.cidr_block, 8, count.index)
  tags              = merge(local.default_tags, { Name = "${local.namespace}-smc-subnet-${count.index}" })
}

resource "aws_internet_gateway" "smc" {
  vpc_id = aws_vpc.smc.id
  tags   = merge(local.default_tags, { Name = "${local.namespace}-smc-igw" })
}
