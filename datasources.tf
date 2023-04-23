###########
# Get EC2 App Instances
###########

resource "time_sleep" "sixty_seconds" {
    create_duration = "60s"

    depends_on = [
        aws_autoscaling_group.app
    ]
}

data "aws_instances" "app" {
    filter {
        name                = "tag:Name"
        values              = ["App*"]
    }

    depends_on = [
        time_sleep.sixty_seconds
    ]
}

###########
# Get Public IP
###########

data "http" "mypublicip" {
    url = "http://ipv4.icanhazip.com"
}

###########
# Get AZ's
###########

data "aws_availability_zones" "available" {
    state = "available"
}

###########
# Get latest AMI
###########

data "aws_ami" "latest" {
    most_recent = true
    owners      = ["amazon"]

    filter {
        name   = "name"
        values = ["amzn2-ami-kernel-5.10-hvm-2.0.202*-x86_64-gp2"]
    }
}