resource "null_resource" "validate_account" {
  count = var.current_id == var.account_id ? 0 : "Please check that you are using the AWS account"
}

resource "null_resource" "validate_module_name" {
  count = local.module_name == var.tags["TerraformModuleName"] ? 0 : "Please check that you are using the Terraform module"
}

resource "null_resource" "validate_module_version" {
  count = local.module_version == var.tags["TerraformModuleVersion"] ? 0 : "Please check that you are using the Terraform module"
}

resource "aws_lb" "nlb" {
  name                             = "${var.prefix}-${var.nlb_name}"
  load_balancer_type               = var.load_balancer_type
  internal                         = var.internal
  subnets                          = var.subnets
  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  ip_address_type                  = var.ip_address_type                 

  access_logs {
    bucket  = var.bucket_access_log_enabled ? var.bucket_name : "dumy"
    prefix  = var.bucket_access_log_enabled ? var.bucket_prefix : "dumy"
    enabled = var.bucket_access_log_enabled
  }
    
  tags = merge(var.tags, tomap({ "Name" = "${var.prefix}-${var.nlb_name}" }))    
}

resource "aws_lb_target_group" "nlb_target_group" {
  for_each                = var.tg_list

  name                    = "${var.prefix}-${var.nlb_name}-${each.key}"
  connection_termination  = each.value.connection_termination
  deregistration_delay    = each.value.deregistration_delay

  target_type             = length(each.value.target_type) > 0 ? each.value.target_type : "instance"

  port                    = each.value.tg_port
  protocol                = each.value.tg_protocol
  
  vpc_id                  = var.vpc_id
  
  proxy_protocol_v2       = each.value.proxy_protocol_v2

  slow_start              = each.value.slow_start

  preserve_client_ip      = each.value.preserve_client_ip

  stickiness {
    enabled = each.value.stickiness_enabled
    type    = each.value.stickiness_type
  }

  health_check {
    interval            = each.value.interval
    path                = length(each.value.path) > 0 ? each.value.path : null  # health check 경로, HTTP/HTTPS 에만 적용
    protocol            = each.value.protocol
    port                = each.value.port
    healthy_threshold   = each.value.healthy_threshold
    unhealthy_threshold = each.value.unhealthy_threshold
  }

  tags = merge(var.tags, tomap({ "Name" = "${var.prefix}-${var.nlb_name}-${each.key}" }))    
}

resource "aws_lb_target_group_attachment" "add_target" {
  for_each          = var.add_target_list

  target_group_arn  = aws_lb_target_group.nlb_target_group[each.value.target_group].arn
  port              = each.value.target_port
  target_id         = each.value.target_name
}


resource "aws_lb_listener" "listener_forward" {
  for_each          = var.forward_listerner

  load_balancer_arn = aws_lb.nlb.arn
  port              = each.value.listener_port
  protocol          = each.value.listener_protocol
  
  default_action {
    target_group_arn = aws_lb_target_group.nlb_target_group["${each.value.listener_tg}"].arn
    type             = each.value.type
  }
}

resource "aws_lb_listener" "listener_tls" {
  for_each          = var.tls_listerner

  load_balancer_arn = aws_lb.nlb.arn
  port              = each.value.listener_port
  protocol          = each.value.listener_protocol
  
  # # TLS
  ssl_policy        = each.value.ssl_policy
  alpn_policy       = each.value.alpn_policy
  certificate_arn   = each.value.certificate_arn
  
  default_action {
    target_group_arn = aws_lb_target_group.nlb_target_group["${each.value.listener_tg}"].arn
    type             = each.value.type
  }
}