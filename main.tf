terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Create a VPC
resource "aws_vpc" "practice_webserver" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.practice_webserver.id

  tags = {
    Name = "main"
  }
}
# create a route table 
resource "aws_route_table" "practice_webserver" {
  vpc_id = aws_vpc.practice_webserver.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main"
  }
}

#create a subnet
resource "aws_subnet" "practice_webserver" {
  vpc_id     = aws_vpc.practice_webserver.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Main"
  }
}

#create a route table association
resource "aws_route_table_association" "practice_project" {
  subnet_id      = aws_subnet.practice_webserver.id
  route_table_id = aws_route_table.practice_webserver.id
}


#create a security group
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.practice_webserver.id

  tags = {
    Name = "main"
  }
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS" {
  security_group_id = aws_security_group.allow_web_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "HTTP" {
  security_group_id = aws_security_group.allow_web_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.allow_web_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web_traffic.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#create a network interface
resource "aws_network_interface" "practice_webserver" {
  subnet_id       = aws_subnet.practice_webserver.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
}

#create a public ip
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.practice_webserver.id
  associate_with_private_ip = "10.0.1.50"

  depends_on = [ aws_internet_gateway.gw, aws_instance.practice_project ]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}
#create an instance and launch apache2 on it

resource "aws_instance" "practice_project" {
  ami           = "ami-04b70fa74e45c3917"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "no-confusion"

  network_interface {
    network_interface_id = aws_network_interface.practice_webserver.id
    device_index         = 0
  }

  user_data = <<-EOF
                #!/bin/bash
                 sudo apt update -y
                 sudo apt install apache2 -y
                 sudo systemctl start apache2
                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                 EOF
  
  tags = {
    Name = "main"
  }
}