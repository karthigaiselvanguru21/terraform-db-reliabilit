variable "name" {
  description = "Base naming prefix for all network resources"
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of Availability Zones corresponding to subnets"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Deploy a single NAT Gateway across all private subnets (dev cost saving) vs one per AZ (prod high availability)"
  type        = bool
}
