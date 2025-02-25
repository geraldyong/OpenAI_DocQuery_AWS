#############################
# ALB for Frontend Service
#############################

# Define the security group to restrict to laptop IP.
resource "aws_security_group" "frontend_alb_sg" {
  name        = "frontend-alb-sg"
  description = "Allow only my laptop IP to access the frontend ALB"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "Allow HTTP from laptop"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.laptop_ip]
  }

  ingress {
    description = "Allow HTTPS from laptop"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.laptop_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "frontend-alb-sg" }
}

resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  load_balancer_type = "application"
  security_groups    = [
    aws_security_group.frontend_alb_sg.id,
    aws_security_group.cloudfront_sg.id
  ]
  subnets            = [
    aws_subnet.eks_public_subnet_a.id,
    aws_subnet.eks_public_subnet_b.id
  ]
  tags               = { Name = "frontend-alb" }
}

# Target Group for Frontend Service
resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-tg"
  port        = 3003
  protocol    = "HTTP"
  vpc_id      = aws_vpc.eks_vpc.id
  target_type = "ip"  # Important for EKS pods

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher            = "200"
    path               = "/_stcore/health"  # Adjust based on your frontend service health endpoint
    port               = "traffic-port"
    protocol           = "HTTP"
    timeout            = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "frontend-target-group"
  }
}

resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}