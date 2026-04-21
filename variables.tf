variable "vpc_cidr" {
    type = string
  
}
variable "subnet_cidr" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "azs" {
  type = list(string)
}