# feature-flag-relay-proxy-ecs

Example architecture for running the harness relay proxy using aws ecs.

This repo can be used as a Terraform module, or a starting point for your own project.

Public:
![image](https://github.com/harness-community/feature-flag-relay-proxy-ecs/assets/7338312/2ee78f96-34f4-400d-bb31-9102fc4d041f)
Private:
![image](https://github.com/harness-community/feature-flag-relay-proxy-ecs/assets/7338312/6709eebf-6da5-4864-9266-dcf93498f30e)
*everything in blue is covered by this module

## example usage

```terraform
module "ff-proxy-ecs" {
  source               = "git::https://github.com/harness-community/feature-flag-relay-proxy-ecs.git?ref=main"
  name                 = "hrns-ff-proxy"
  ff_proxy_image       = "harness/ff-proxy:2.0.0-rc.24"
  proxy_key_secret_arn = "arn:aws:secretsmanager:us-west-2:759984737373:secret:riley/ff-proxy-key-EHPGoR"

  vpc_id = data.aws_vpc.sa-lab.id
  security_groups = [
    data.aws_security_group.sa-lab-default.id
  ]

  # these should almost always be private subnets
  proxy_subnets = data.aws_subnets.sa-lab-private.ids
  # these could be public or private, depending on your use case
  alb_subnets  = data.aws_subnets.sa-lab-public.ids

  tags = {
    "app" : "ff-relay-proxy-rssnyder"
  }
}
```

Once deployed you can grab the ALB URL from the output `proxy_url` and check its health endpoint:
```
➜  curl hrns-ff-proxy-826020824.us-west-2.elb.amazonaws.com:7000/health
{"configStatus":{"state":"READ_REPLICA","since":1715781538871},"streamStatus":{"state":"CONNECTED","since":1715781541093},"cacheStatus":"healthy"}
```

## Requirements

You must have an existing VPC with subnets.

There must also be an AWS Secrets Manager secret with your proxy key as the value.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_service.writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_task_definition.writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_elasticache_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_cluster) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_policy.task_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.task_execution_registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.task_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution_registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_subnets"></a> [alb\_subnets](#input\_alb\_subnets) | VPC subnets to place the alb in | `list(string)` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ID for an existing ECS cluster to use | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name for the ECS cluster created by the module (if no existing cluster id given) | `string` | `"ff-proxy"` | no |
| <a name="input_enable_ecs_exec"></a> [enable\_ecs\_exec](#input\_enable\_ecs\_exec) | Create policy to enable ecs execution on delegate container | `bool` | `false` | no |
| <a name="input_ff_proxy_image"></a> [ff\_proxy\_image](#input\_ff\_proxy\_image) | delegate image to use, eg: harness/ff-proxy:2.0.0-rc18 | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | ff-proxy name | `string` | n/a | yes |
| <a name="input_proxy_key_secret_arn"></a> [proxy\_key\_secret\_arn](#input\_proxy\_key\_secret\_arn) | Secret manager secret that holds the proxy key | `string` | n/a | yes |
| <a name="input_proxy_subnets"></a> [proxy\_subnets](#input\_proxy\_subnets) | VPC subnets to place the proxy pods in | `list(string)` | n/a | yes |
| <a name="input_read_replica_count"></a> [read\_replica\_count](#input\_read\_replica\_count) | How many read replicas to launch | `number` | `1` | no |
| <a name="input_read_replica_cpu"></a> [read\_replica\_cpu](#input\_read\_replica\_cpu) | Number of cpu units used by the read replica task | `number` | `1024` | no |
| <a name="input_read_replica_environment"></a> [read\_replica\_environment](#input\_read\_replica\_environment) | Additional environment variables to add to the read replica | `list(object({ name = string, value = string }))` | `[]` | no |
| <a name="input_read_replica_memory"></a> [read\_replica\_memory](#input\_read\_replica\_memory) | Amount (in MiB) of memory used by the read replica task | `number` | `2048` | no |
| <a name="input_redis_address"></a> [redis\_address](#input\_redis\_address) | Address of redis server (if not specified, elasticache is used) | `string` | `""` | no |
| <a name="input_redis_db"></a> [redis\_db](#input\_redis\_db) | Database in the redis server to use | `string` | `""` | no |
| <a name="input_registry_secret_arn"></a> [registry\_secret\_arn](#input\_registry\_secret\_arn) | Secret manager secret that holds the login for a container registry | `string` | `""` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | VPC security groups to attach to all resources created | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags to add to all resources created | `map(any)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID for the existing VPC to use | `string` | `""` | no |
| <a name="input_writer_cpu"></a> [writer\_cpu](#input\_writer\_cpu) | Number of cpu units used by the writer task | `number` | `512` | no |
| <a name="input_writer_environment"></a> [writer\_environment](#input\_writer\_environment) | Additional environment variables to add to the writer | `list(object({ name = string, value = string }))` | `[]` | no |
| <a name="input_writer_memory"></a> [writer\_memory](#input\_writer\_memory) | Amount (in MiB) of memory used by the writer task | `number` | `1024` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_proxy_url"></a> [proxy\_url](#output\_proxy\_url) | DNS name for the lb that fronts the read replicas |
