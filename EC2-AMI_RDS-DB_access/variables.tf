variable "ami_id" {
  description = "EC2 AMI Id"
  default = "ami-0bf62675211b3a5b1"
}

variable "account_ids" {
  description = "List of Account IDs"
  type = list
}