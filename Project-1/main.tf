provider "aws" {
  region  = "us-east-1"
  access_key = ""
  secret_key = ""
}

/*resource "aws_networkfirewall_rule_group" "example" {
  capacity    = 50
  description = "Permits http traffic from source"
  name        = "example"
  type        = "STATEFUL"
  rule_group {
    rules_source {
      dynamic "stateful_rule" {
        for_each = local.ips
        content {
          action = "PASS"
          header {
            destination      = "ANY"
            destination_port = "ANY"
            protocol         = "HTTP"
            direction        = "ANY"
            source_port      = "ANY"
            source           = stateful_rule.value
          }
          rule_option {
            keyword = "sid:1"
          }
        }
      }
    }
  }

  tags = {
    Name = "permit HTTP from source"
  }
}

locals {
  ips = ["1.1.1.1/32", "1.0.0.1/32"]
}
*/

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod"
  }
}

resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  tags = {
    Name = "prod"
  }
}

resource "aws_subnet" "prod-subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

resource "aws_route_table_association" "prod-route-table" {
  subnet_id      = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "prod-web-server-nic" {
  subnet_id       = aws_subnet.prod-subnet-1.id
  private_ips     = ["10.0.1.50"]  
  security_groups = [aws_security_group.allow_web.id]
} 

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.prod-web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.prod-gw]
}

resource "aws_instance" "prod-web-server-instance" {
  ami           = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "Pers-Proj-Pem"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.prod-web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "ubuntu-web-server"
    Environment = "Prod"
  }
}


/* resource "<provider>_<resource_type>" "name" {
    config options....
    
    key = "value"
    Key2 = ""
} */
