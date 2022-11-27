output "nlb_id" {
    value = aws_lb.nlb.id
}

output "nlb_dns_name" {
    value = aws_lb.nlb.dns_name
}

output "nlb_tg_name" {
    value = {for k, v in aws_lb_target_group.nlb_target_group: k => v.arn}
}

output "nlb_tg_id" {
    value = {for k, v in aws_lb_target_group.nlb_target_group: k => v.id}
}

output "nlb_tg_port" {
    value = {for k, v in aws_lb_target_group.nlb_target_group: k => v.port}
}

output "nlb_listener_arn" {
    value = {for k, v in aws_lb_listener.listener_forward: k => v.arn}
}

output "nlb_listener_id" {
    value = {for k, v in aws_lb_listener.listener_forward: k => v.id}
}

output "nlb_listener_port" {
    value = {for k, v in aws_lb_listener.listener_forward: k => v.port}
}

output "nlb_listener_protocol" {
    value = {for k, v in aws_lb_listener.listener_forward: k => v.protocol}
}

output "nlb_tls_listener_arn" {
    value = {for k, v in aws_lb_listener.listener_tls: k => v.arn}
}

output "nlb_tls_listener_id" {
    value = {for k, v in aws_lb_listener.listener_tls: k => v.id}
}

output "nlb_tls_listener_port" {
    value = {for k, v in aws_lb_listener.listener_tls: k => v.port}
}

output "nlb_tls_listener_protocol" {
    value = {for k, v in aws_lb_listener.listener_tls: k => v.protocol}
}
