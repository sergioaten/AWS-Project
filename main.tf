terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.63.0"
        }
        ssh = {
            source = "loafoe/ssh"
            version = "2.6.0"
        }
    }
}

provider "aws" {
    default_tags {
        tags = var.overall_tags
    }
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

data "http" "myip" {
    url = "http://ipv4.icanhazip.com"
}

###########
# Get AZ's
###########

data "aws_availability_zones" "available" {
    state = "available"
}

###########
# VPC & IGW
###########

resource "aws_vpc" "prod" {
    cidr_block           = var.cidr_block
    enable_dns_hostnames = "true"

    tags = {
        Name = "Prod VPC"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.prod.id

    tags = {
        Name = "Main Internet GateWay"
    }
}

###########
# Subnets & RouteTables & Routes
###########

resource "aws_subnet" "public" {
    count               = length(var.subnet.public.cidr_block)
    vpc_id              = aws_vpc.prod.id
    cidr_block          = var.subnet.public.cidr_block[count.index]
    availability_zone   = data.aws_availability_zones.available.names[local.public_azs[count.index] - 1]

    tags = {
        Name = format("Public Subnet %s",count.index + 1)
    }
}

resource "aws_route_table" "public" {
    count   = 2
    vpc_id  = aws_vpc.prod.id

    tags = {
        Name = format("Public Route Table %s",count.index + 1)
    }
}

resource "aws_route" "public" {
    count                   = length(var.subnet.public.cidr_block)
    route_table_id          = aws_route_table.public[count.index].id
    destination_cidr_block  = "0.0.0.0/0"
    gateway_id              = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
    count           = length(var.subnet.public.cidr_block)
    subnet_id       = aws_subnet.public[count.index].id
    route_table_id  = aws_route_table.public[count.index].id
}

resource "aws_subnet" "private" {
    count               = length(var.subnet.private.cidr_block)
    vpc_id              = aws_vpc.prod.id
    cidr_block          = var.subnet.private.cidr_block[count.index]
    availability_zone   = data.aws_availability_zones.available.names[local.private_azs[count.index] - 1]

    tags = {
    Name = format("Private Subnet %s",count.index + 1)
    }
}

resource "aws_route_table" "private" {
    count   = length(var.subnet.private.cidr_block)
    vpc_id  = aws_vpc.prod.id

    tags = {
        Name = format("Private Route Table %s",count.index + 1)
    }
}

resource "aws_route" "private" {
    count                   = 2
    route_table_id          = aws_route_table.private[count.index].id
    destination_cidr_block  = "0.0.0.0/0"
    nat_gateway_id          = aws_nat_gateway.natgw[count.index].id
}

resource "aws_route_table_association" "private" {
    count           = length(var.subnet.private.cidr_block)
    subnet_id       = aws_subnet.private[count.index].id
    route_table_id  = aws_route_table.private[count.index].id
}

###########
# NAT GateWays
###########

resource "aws_eip" "eip" {
    count = length(var.subnet.public.cidr_block)

    tags = {
        Name = format("Nat GW EIP %s",count.index + 1)
    }
}

resource "aws_nat_gateway" "natgw" {
    count               = length(var.subnet.public.cidr_block)
    allocation_id       = aws_eip.eip[count.index].id
    connectivity_type   = "public"
    subnet_id           = aws_subnet.public[count.index].id

    tags = {
        Name = format("Public NatGW %s",count.index + 1)
    }
}

###########
# Bastion Host & App Key Pairs
###########

resource "tls_private_key" "pk" {
    count       = 2
    algorithm   = "RSA"
    rsa_bits    = 4096
}

resource "aws_key_pair" "kp" {
    count       = 2
    key_name    = replace(lower(var.keypairs_names[count.index])," ","")
    public_key  = tls_private_key.pk[count.index].public_key_openssh
}

resource "local_file" "ssh_key" {
    count           = 2
    filename        = replace(lower(format(".ssh/%s.pem",aws_key_pair.kp[count.index].key_name))," ","")
    content         = tls_private_key.pk[count.index].private_key_pem
    file_permission = "0400"
}

###########
# Security Groups
###########

resource "aws_security_group" "bastion" {
    name        = "Bastion-SG"
    description = "Bastion Security Group"
    vpc_id      = aws_vpc.prod.id

    ingress {
        description      = "Allow SSH from Company IP"
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = [format("%s/32",local.myip)]
    }

    egress {
        description      = "Allow all traffic"
        from_port        = 0
        to_port          = 0
        protocol         = -1
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name = "Bastion SG"
    }
}

resource "aws_security_group" "alb" {
    name        = "ALB-SG"
    description = "Application Load Balancer Security Group"
    vpc_id      = aws_vpc.prod.id

    ingress {
        description      = "Allow HTTP from Internet"
        from_port        = 80
        to_port          = 80
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    egress {
        description      = "Allow all traffic"
        from_port        = 0
        to_port          = 0
        protocol         = -1
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name = "ALB SG"
    }
}

resource "aws_security_group" "app" {
    name        = "APP-SG"
    description = "Application Security Group"
    vpc_id      = aws_vpc.prod.id

    tags = {
        Name = "APP SG"
    }
}

resource "aws_security_group_rule" "in_app_http" {
    description                 = "Allow HTTP from ALB"
    security_group_id           = aws_security_group.app.id
    type                        = "ingress"
    from_port                   = 80
    to_port                     = 80
    protocol                    = "tcp"
    source_security_group_id    = aws_security_group.alb.id
}

resource "aws_security_group_rule" "in_app_ssh" {
    description                 = "Allow outbund traffic"
    security_group_id           = aws_security_group.app.id
    type                        = "ingress"
    from_port                   = 22
    to_port                     = 22
    protocol                    = "tcp"
    source_security_group_id    = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "out_app_alltrafic" {
    description                 = "Allow SSH Acces from bastion"
    security_group_id           = aws_security_group.app.id
    type                        = "egress"
    from_port                   = 0
    to_port                     = 0
    protocol                    = -1
    cidr_blocks                 = ["0.0.0.0/0"]
}

resource "aws_security_group" "db" {
    name        = "DB-SG"
    description = "Database Security Group"
    vpc_id      = aws_vpc.prod.id

    ingress {
        description      = "Allow MySQL from APP"
        from_port        = 3306
        to_port          = 3306
        protocol         = "tcp"
        security_groups  = [aws_security_group.app.id]
    }

    egress {
        description      = "Allow all traffic"
        from_port        = 0
        to_port          = 0
        protocol         = -1
        cidr_blocks      = ["0.0.0.0/0"]
    }

    tags = {
        Name = "DB SG"
    }
}

###########
# Bastion Host
###########

resource "aws_instance" "bastion" {
    ami                         = data.aws_ami.latest.image_id
    instance_type               = var.bastion_instancetype
    availability_zone           = data.aws_availability_zones.available.names[0]
    key_name                    = aws_key_pair.kp[0].key_name

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.bastion.id
    }

    tags = {
        Name = "Bastion Host"
    }
}

resource "aws_network_interface" "bastion" {
    subnet_id   = aws_subnet.public[0].id
    security_groups = [aws_security_group.bastion.id]

    tags = {
        Name = "nic_1"
    }
}

resource "aws_eip" "bastion" {
    tags = {
        Name = format("%s EIP",aws_instance.bastion.tags.Name)
    }
}

resource "aws_eip_association" "bastion_eip" {
    instance_id   = aws_instance.bastion.id
    allocation_id = aws_eip.bastion.id
}

###########
# DB Subnet Group & DB Instance & SSM Parameters
###########

resource "aws_db_subnet_group" "db_subnet_group" {
    name            = "mysql-subnetgroup"
    subnet_ids      = [aws_subnet.private[2].id,aws_subnet.private[3].id]
}

resource "aws_db_instance" "mysql" {
    identifier              = "mysql-db"
    allocated_storage       = 10
    db_name                 = "cafe_db"
    engine                  = "mysql"
    engine_version          = "8.0.32"
    instance_class          = var.db_config.instance_class
    username                = var.db_config.username
    password                = var.db_config.password
    skip_final_snapshot     = true
    db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
    vpc_security_group_ids  = [aws_security_group.db.id]
    multi_az                = false
}

resource "aws_ssm_parameter" "db_parameters" {
    count = length(local.ssm_ps)
    name  = local.ssm_ps[count.index].name
    type  = "String"
    value = local.ssm_ps[count.index].value
}

###########
# ALB & Target Group & Listener
###########

resource "aws_lb" "app" {
    name               = "app-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb.id]
    subnets            = [aws_subnet.public[0].id,aws_subnet.public[1].id]
}

resource "aws_lb_target_group" "app" {
    name     = "app-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.prod.id
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.app.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.app.arn
    }
}

###########
# SSH Agent to import DB SQL
###########

resource "ssh_resource" "ssh_agent" {
    when = "create"

    bastion_host = aws_eip.bastion.public_ip
    host         = element(tolist(data.aws_instances.app.private_ips), 0)
    user         = "ec2-user"

    bastion_private_key = tls_private_key.pk[0].private_key_pem
    private_key         = tls_private_key.pk[1].private_key_pem
    
    timeout     = "15m"
    retry_delay = "5s"

    commands = [
        "cd ~",
        "wget https://aws-tc-largeobjects.s3-us-west-2.amazonaws.com/ILT-TF-200-ACACAD-20-EN/Module-9-Challenge-Lab/CafeDbDump.sql",
        format("mysql --host=%s --user=admin --password=admin123 cafe_db < CafeDbDump.sql",aws_db_instance.mysql.address)
    ]

    depends_on = [
        aws_security_group_rule.in_app_ssh,
        aws_key_pair.kp,
        data.aws_instances.app
    ]
}

###########
# Launch Template
###########

resource "aws_launch_template" "app" {
    name = "APP-LaunchTemplate"
    image_id = data.aws_ami.latest.image_id
    instance_type = var.launchtemplate_instancetype
    key_name = aws_key_pair.kp[1].key_name
    vpc_security_group_ids = [aws_security_group.app.id]
    user_data = filebase64("./script.sh")

    iam_instance_profile {
        name = var.ec2_iamrole
    }

    tag_specifications {
        resource_type = "instance"

        tags = {
            Name = "App-Instance"
        }
    }
}

###########
# Auto Scaling Group & Scaling Policy
###########

resource "aws_autoscaling_group" "app" {
    name                        = "asg-app"
    desired_capacity            = 2
    min_size                    = 2
    max_size                    = 4
    vpc_zone_identifier         = [aws_subnet.private[0].id,aws_subnet.private[1].id]
    health_check_grace_period   = 90
    health_check_type           = "ELB"
    target_group_arns           = [aws_lb_target_group.app.arn]
    wait_for_capacity_timeout = 0

    launch_template {
        id      = aws_launch_template.app.id
        version = "$Latest"
    }
}

# resource "aws_autoscaling_policy" "app" {
#     name                    = "cpu-scaling-policy"
#     policy_type             = "TargetTrackingScaling"
#     autoscaling_group_name  = aws_autoscaling_group.app.name

#     target_tracking_configuration {
#         predefined_metric_specification {
#             predefined_metric_type = "ASGAverageCPUUtilization"
#         }
#         target_value = 25
#     }
# }

###########
# Outputs
###########

output "rds_endpoint_address" {
    value = aws_db_instance.mysql.address
}

output "public_dns_lb" {
    value = format("%s/cafe",aws_lb.app.dns_name)
}