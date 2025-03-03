provider "aws" {
  region = "us-east-1"
}

# 🚀 Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "2-teir-vpc" }
}

# 🌎 Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "172.16.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "2-Tier-Public-Subnet" }
}

# 🔒 Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "172.16.2.0/24"
  availability_zone = "us-east-1b"

  tags = { Name = "2-Tier-Private-Subnet" }
}

# 🌐 Internet Gateway (For Public Access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = { Name = "MyIGW" }
}

# 🔄 NAT Gateway (For Private EC2 to access the internet)
resource "aws_eip" "nat_eip" {}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = { Name = "MyNATGW" }
}

# 🚏 Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "2-Teir-Public-RT" }
}

# 🔗 Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 🚏 Private Route Table (Uses NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "2-Teir-Private-RT" }
}

# 🔗 Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# 🔒 Security Groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Public-SG" }
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Private-SG" }
}

# 🖥️ Public EC2 (Jenkins + Frontend)
resource "aws_instance" "public_ec2" {
  ami                    = "ami-0c55b159cbfafe1f0" # Ubuntu 22.04
  instance_type          = "t2.micro"
  subnet_id             = aws_subnet.public_subnet.id
  security_groups       = [aws_security_group.public_sg.name]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io git
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
    git clone https://github.com/Aadi-Sonwane/todo_app_docker_jenkins.git /home/ubuntu/todo_app
    cd /home/ubuntu/todo_app
    docker-compose up -d
  EOF

  tags = { Name = "Public-EC2" }
}

# 🔒 Private EC2 (Backend)
resource "aws_instance" "private_ec2" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  subnet_id             = aws_subnet.private_subnet.id
  security_groups       = [aws_security_group.private_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io git
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
    git clone https://github.com/Aadi-Sonwane/todo_app_docker_jenkins.git /home/ubuntu/todo_app
    cd /home/ubuntu/todo_app
    docker-compose up -d
  EOF

  tags = { Name = "Private-EC2" }
}

# 🔗 Output Public EC2 URL
output "public_ec2_url" {
  value = "http://${aws_instance.public_ec2.public_ip}:8080"
}
