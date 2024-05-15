data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name = var.name

  tags = merge(var.tags, {
    source = "harness-community/feature-flag-relay-proxy-ecs"
  })
}

resource "aws_ecs_cluster" "this" {
  count = var.cluster_id != "" ? 0 : 1

  name = var.cluster_name != "" ? var.cluster_name : var.name
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      }
    }
  }

  tags = merge(var.tags, {
    source = "harness-community/feature-flag-relay-proxy-ecs"
  })
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name}-ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF

  tags = merge(var.tags, {
    source = "harness-community/feature-flag-relay-proxy-ecs",
  })
}

resource "aws_iam_policy" "task_execution" {
  name        = aws_iam_role.task_execution.name
  description = "Policy for execution of the delegate container in ecs"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Logs",
            "Effect": "Allow",
            "Action": "logs:*",
            "Resource": "${aws_cloudwatch_log_group.this.arn}:log-stream:*"
        },
        {
            "Sid": "DelegateTokenSecret",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${var.proxy_key_secret_arn}"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "task_execution_registry" {
  count = var.registry_secret_arn != "" ? 1 : 0

  name        = "${aws_iam_role.task_execution.name}_registry"
  description = "Policy for execution of the delegate container in ecs to log into image registry"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
           "Sid": "RegistryLogin",
           "Effect": "Allow",
           "Action": "secretsmanager:GetSecretValue",
           "Resource": "${var.registry_secret_arn}"
       }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_execution.arn
}

resource "aws_iam_role_policy_attachment" "task_execution_registry" {
  count = var.registry_secret_arn != "" ? 1 : 0

  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_execution_registry[0].arn
}

resource "aws_iam_role" "task" {
  name = "${var.name}-ecsTaskRole"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF

  tags = merge(var.tags, {
    source = "harness-community/feature-flag-relay-proxy-ecs",
  })
}

resource "aws_iam_policy" "task_exec" {
  count = var.enable_ecs_exec ? 1 : 0

  name        = "${aws_iam_role.task_execution.name}_task_exec"
  description = "Policy for execution of commands on the ecs containers"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  count = var.enable_ecs_exec ? 1 : 0

  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_exec[0].arn
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "Allow inbound traffic to ff proxy"
  vpc_id      = var.vpc_id

  ingress {
    description = "FF Proxy"
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name   = var.name
    source = "harness-community/feature-flag-relay-proxy-ecs",
  }
}

resource "aws_ecs_task_definition" "writer" {
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  family                   = "ff-proxy-writer"
  cpu                      = var.writer_cpu
  memory                   = var.writer_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions = jsonencode([
    {
      name      = "writer"
      image     = var.ff_proxy_image
      essential = true
      memory    = var.writer_memory
      repositoryCredentials = var.registry_secret_arn != "" ? {
        credentialsParameter = var.registry_secret_arn
      } : null,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = "ecs/ff-proxy/writer"
        }
      },
      secrets = [
        {
          name      = "PROXY_KEY",
          valueFrom = "${var.proxy_key_secret_arn}:::"
        }
      ],
      environment = concat([
        {
          name  = "READ_REPLICA",
          value = "false"
        },
        {
          name  = "REDIS_ADDRESS",
          value = var.redis_address != "" ? var.redis_address : "${aws_elasticache_cluster.this.cache_nodes[0].address}:6379"
        },
        {
          name  = "REDIS_DB",
          value = var.redis_db != "" ? var.redis_db : 0
        }], var.writer_environment
      )
    }
  ])

  tags = merge(var.tags, {
    source    = "harness-community/feature-flag-relay-proxy-ecs",
    component = "writer",
  })
}

resource "aws_ecs_service" "writer" {
  name                   = "${var.name}-writer"
  cluster                = var.cluster_id != "" ? var.cluster_id : aws_ecs_cluster.this[0].id
  task_definition        = aws_ecs_task_definition.writer.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  scheduling_strategy    = "REPLICA"
  enable_execute_command = var.enable_ecs_exec

  network_configuration {
    security_groups  = concat(var.security_groups, [aws_security_group.this.id])
    subnets          = var.proxy_subnets
    assign_public_ip = false
  }

  tags = merge(var.tags, {
    source    = "harness-community/feature-flag-relay-proxy-ecs",
    component = "writer",
  })
}

resource "aws_ecs_task_definition" "read_replica" {
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  family                   = "ff-proxy-read-replica"
  cpu                      = var.read_replica_cpu
  memory                   = var.read_replica_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions = jsonencode([
    {
      name      = "read-replica"
      image     = var.ff_proxy_image
      essential = true
      memory    = var.read_replica_memory
      repositoryCredentials = var.registry_secret_arn != "" ? {
        credentialsParameter = var.registry_secret_arn
      } : null,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name,
          awslogs-region        = data.aws_region.current.name,
          awslogs-stream-prefix = "ecs/ff-proxy/read-replica"
        }
      },
      portMappings = [
        {
          containerPort = 7000
          hostPort      = 7000
        }
      ],
      environment = concat([
        {
          name  = "READ_REPLICA",
          value = "true"
        },
        {
          name  = "REDIS_ADDRESS",
          value = var.redis_address != "" ? var.redis_address : "${aws_elasticache_cluster.this.cache_nodes[0].address}:6379"
        },
        {
          name  = "REDIS_DB",
          value = var.redis_db != "" ? var.redis_db : 0
        }], var.read_replica_environment
      )
    }
  ])

  tags = merge(var.tags, {
    source    = "harness-community/feature-flag-relay-proxy-ecs",
    component = "read-replica",
  })
}

resource "aws_ecs_service" "read_replica" {
  name                   = "${var.name}read-replica"
  cluster                = var.cluster_id != "" ? var.cluster_id : aws_ecs_cluster.this[0].id
  task_definition        = aws_ecs_task_definition.read_replica.arn
  desired_count          = var.read_replica_count
  launch_type            = "FARGATE"
  scheduling_strategy    = "REPLICA"
  enable_execute_command = var.enable_ecs_exec

  network_configuration {
    security_groups  = concat(var.security_groups, [aws_security_group.this.id])
    subnets          = var.proxy_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.read_replica.arn
    container_name   = "read-replica"
    container_port   = 7000
  }
}

resource "aws_lb" "read_replica" {
  name               = var.name
  load_balancer_type = "application"
  security_groups    = concat(var.security_groups, [aws_security_group.this.id])
  subnets            = var.alb_subnets

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_lb_listener" "read_replica" {
  load_balancer_arn = aws_lb.read_replica.arn
  port              = 7000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.read_replica.arn
  }
}

resource "aws_lb_target_group" "read_replica" {
  name        = "${var.name}read-replica"
  port        = 7000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path = "/health"
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.proxy_subnets
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.name
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  security_group_ids   = concat(var.security_groups, [aws_security_group.this.id])
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  tags = merge(var.tags, {
    source    = "harness-community/feature-flag-relay-proxy-ecs",
    component = "redis"
  })
}

