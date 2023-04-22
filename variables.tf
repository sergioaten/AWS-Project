variable "overall_tags" {
    description = "All resources tags"
    default     = {
        Env     = "Prod"
        Project = "Three Tier App"
    }
}

variable "cidr_block" {
    description = "VPC CIDR Block"
    default     = "10.10.0.0/16"
}

variable "subnet" {
    description = "Subnet config"
    default = {
        public = {
            cidr_block  = [
                "10.10.0.0/25",
                "10.10.0.128/25"
            ]
            azs = [1, 2]
        }
        private = {
            cidr_block = [
                "10.10.1.0/24",
                "10.10.2.0/24",
                "10.10.3.0/24",
                "10.10.4.0/24"
                ]
            azs = [1, 2, 1, 2]
        }
    }
}

variable "keypairs_names" {
    description = "Key Pairs Names"
    default     = ["Bastion Host","App EC2 Instances"]
}

variable "ec2_iamrole" {
    description = "EC2 IAM Role name to read ssm parameters"
    default     = "Inventory-App-Role"
}

variable "bastion_instancetype" {
    description = "Bastion Host instance type"
    default     = "t2.micro"
}

variable "launchtemplate_instancetype" {
    description = "Launch Template instance type"
    default     = "t2.micro"
}

variable "db_config" {
    description = "Database configuration"
    default     = {
        username        = "admin"
        password        = "admin123"
        instance_class  = "db.t3.small"
    }
}