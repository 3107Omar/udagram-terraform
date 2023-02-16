resource "aws_ecs_cluster" "project_cluster" {
  name = "project-cluster"
}
resource "aws_iam_role" "iam_role" {
  name = "iam-role"
  assume_role_policy = data.aws_iam_policy_document.sts_ecs.json
}
data "aws_iam_policy_document" "sts_ecs" {
    statement {
    sid = "STSassumeRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
data "aws_iam_policy_document" "policy_doc" {
  statement {
      effect= "Allow"
      actions= ["*"] 
      resources= [
        "arn:aws:logs:*:*:*",
	"arn:aws:rds:us-east-1:639483503131:db:postgres",
	"arn:aws:s3:::mybucket-639483503131/*"
    ]
  }
}
resource "aws_iam_policy" "iam_policy" {
	name = "iam-policy"
	policy = data.aws_iam_policy_document.policy_doc.json
}
resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

resource "aws_ecs_task_definition" "backend-feed" {
  family = "backend-feed"
  container_definitions = file("./backendfeed.json")
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 2048
  cpu                      = 1024
  execution_role_arn       = aws_iam_role.iam_role.arn
}

resource "aws_ecs_service" "backend-feed" {
  name            = "backend-feed"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.backend-feed.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.vpc.public_subnets
    assign_public_ip = true
  }
}

resource "aws_ecs_task_definition" "backend-user" {
  family = "backend-user"
  container_definitions = file("backenduser.json")
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 2048
  cpu                      = 1024
  execution_role_arn       = aws_iam_role.iam_role.arn
}

resource "aws_ecs_service" "backend-user" {
  name            = "backend-user"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.backend-user.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.vpc.public_subnets
    assign_public_ip = true
  }
}

resource "aws_ecs_task_definition" "reverseproxy" {
  family = "reverseproxy"
  container_definitions = file("reverseproxy.json")
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 2048
  cpu                      = 1024
  execution_role_arn       = aws_iam_role.iam_role.arn
}

resource "aws_ecs_service" "reverseproxy" {
  name            = "reverseproxy"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.reverseproxy.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.vpc.public_subnets
    assign_public_ip = true
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family = "frontend"
  container_definitions = file("frontend.json")
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 2048
  cpu                      = 1024
  execution_role_arn       = aws_iam_role.iam_role.arn
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = "${aws_ecs_task_definition.frontend.family}"
    container_port   = 80 # Specifying the container port
  }
  network_configuration {
    subnets          = var.vpc.public_subnets
    assign_public_ip = true
  }
}

module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 8.0"
  name               = var.namespace
  load_balancer_type = "application"
  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    { name_prefix      = "nodejs"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
    }
  ]
}
