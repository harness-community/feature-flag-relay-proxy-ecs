variable "name" {
  type    = string
}

variable "image" {
  type    = string
}

variable "proxy_key_secret_arn" {
  type    = string
}

variable "vpc_id" {
  type    = string
}

variable "proxy_subnets" {
  type    = list
}

variable "alb_subnets" {
  type    = list
}

module "ff-proxy-ecs" {
  source               = "git::https://github.com/harness-community/feature-flag-relay-proxy-ecs.git?ref=main"
  name                 = var.name
  image                = var.image
  proxy_key_secret_arn = var.proxy_key_secret_arn

  vpc_id = var.vpc_id

  proxy_subnets = var.proxy_subnets
  alb_subnets   = var.alb_subnets
}

output "proxy_url" {
  value = module.ff-proxy-ecs.proxy_url
}
