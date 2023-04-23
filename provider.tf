terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.63.0"
        }
        ssh = {
            source  = "loafoe/ssh"
            version = "2.6.0"
        }
    }
}

provider "aws" {
    default_tags {
        tags = var.overall_tags
    }
}