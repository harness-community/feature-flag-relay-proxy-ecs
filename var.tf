variable "name" {
  type        = string
  description = "ff-proxy name"
}

variable "redis_address" {
  type        = string
  default     = ""
  description = "Address of redis server (if not specified, elasticache is used)"
}

variable "redis_db" {
  type        = string
  default     = ""
  description = "Database in the redis server to use"
}

variable "proxy_key_secret_arn" {
  type        = string
  description = "Secret manager secret that holds the proxy key"
}

variable "registry_secret_arn" {
  type        = string
  description = "Secret manager secret that holds the login for a container registry"
  default     = ""
}

variable "enable_ecs_exec" {
  type        = bool
  description = "Create policy to enable ecs execution on delegate container"
  default     = false
}

variable "cluster_id" {
  type        = string
  default     = ""
  description = "ID for an existing ECS cluster to use"
}

variable "cluster_name" {
  type        = string
  default     = "ff-proxy"
  description = "Name for the ECS cluster created by the module (if no existing cluster id given)"
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "ID for the existing VPC to use"
}

variable "security_groups" {
  type        = list(string)
  description = "VPC security groups to attach to all resources created"
}

variable "proxy_subnets" {
  type        = list(string)
  description = "VPC subnets to place the proxy pods in"
}

variable "alb_subnets" {
  type        = list(string)
  description = " VPC subnets to place the alb in"
}

variable "writer_cpu" {
  type        = number
  description = "Number of cpu units used by the writer task"
  default     = 512
}

variable "writer_memory" {
  type        = number
  description = "Amount (in MiB) of memory used by the writer task"
  default     = 1024
}

variable "read_replica_cpu" {
  type        = number
  description = "Number of cpu units used by the read replica task"
  default     = 1024
}

variable "read_replica_memory" {
  type        = number
  description = "Amount (in MiB) of memory used by the read replica task"
  default     = 2048
}

variable "tags" {
  type        = map(any)
  default     = {}
  description = "tags to add to all resources created"
}

# ff-proxy configuration

variable "ff_proxy_image" {
  type        = string
  description = "delegate image to use, eg: harness/ff-proxy:2.0.0-rc18"
}

variable "writer_environment" {
  type        = list(object({ name = string, value = string }))
  description = "Additional environment variables to add to the writer"
  default     = []
}

variable "read_replica_environment" {
  type        = list(object({ name = string, value = string }))
  description = "Additional environment variables to add to the read replica"
  default     = []
}

variable "read_replica_count" {
  type        = number
  default     = 1
  description = "How many read replicas to launch"
}
