provider "aws" {
  region     = var.region
  access_key = "put-your-access-key-here"
  secret_key = "put-your-secret-key-here"
}



resource "tls_private_key" "project_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "project_key" {
  key_name   = "project-key"
  public_key = tls_private_key.project_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.project_key.private_key_pem
  filename = "project-key.pem"
  file_permission = "0400"
}



# ---------------- VPC ----------------
resource "aws_vpc" "project_vpc" {
  cidr_block = "10.0.0.0/16"
}

# ---------------- Subnets ----------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
}

# ---------------- Internet Gateway ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project_vpc.id
}

# ---------------- Route Table ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------- NAT Gateway ----------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  depends_on = [aws_internet_gateway.igw]
}

# ---------------- Private Route Table ----------------
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}


# ---------------- Security Groups ----------------
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # restrict in real use
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------- Load Balancer ----------------
resource "aws_lb" "alb" {
  name               = "project-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

# ---------------- Target Group ----------------
resource "aws_lb_target_group" "tg" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.project_vpc.id

  health_check {
    path = "/"
  }
}

# ---------------- Listener ----------------
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ---------------- Launch Template ----------------
resource "aws_launch_template" "project-lt" {
  name_prefix   = "project-lt"
  image_id      = "ami-0931307dcdc2a28c9" # Amazon Linux 2 (update if needed)
  instance_type = var.instance_type
  key_name      = aws_key_pair.project_key.key_name

  network_interfaces {
    security_groups = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum install -y git
    sudo yum install httpd -y 
    sudo systemctl start httpd
    sudo systemctl enable httpd
    cd /home/ec2-user
    sudo git clone https://github.com/PriyeshPandey07/Throne-game.git
    cd Throne-game
    sudo rm -rvf /var/www/html/*
    sudo cp -rvf * /var/www/html/
  EOF
  )
}

# ---------------- Auto Scaling Group ----------------
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  launch_template {
    id      = aws_launch_template.project-lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

   # ✅ Health Check Configuration
  health_check_type         = "ELB"
  health_check_grace_period = 30

  # ✅ Tags
  tag {
    key                 = "Name"
    value               = "zomato-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Zomato-Clone"
    propagate_at_launch = true
  }
}

resource "aws_sns_topic" "asg_notifications" {
  name = "zomato-asg-topic"
} 

# 3️⃣ SNS Notification
resource "aws_autoscaling_notification" "asg_notifications" {
  group_names = [aws_autoscaling_group.asg.name]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE"
  ]

  topic_arn = aws_sns_topic.asg_notifications.arn
}

# 4️⃣ Email Subscription
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.asg_notifications.arn
  protocol  = "email"
  endpoint  = "vishwapandey2007@gmail.com"
}