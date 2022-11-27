variable "account_id" {
    type    = string
}
variable "current_region" {
  type      = string
}

variable "current_id" {
  type      = string
}
variable "region" {
    type    = string
}

variable "prefix" {
    type    = string
}

variable "vpc_id" {
    type    = string
}

# nlb
variable "nlb_name" {
    type    = string
}
variable "load_balancer_type" {
    type = string
  
}
variable "internal" {
    type    = bool
}
variable "subnets" {
    type    = list(string)
}
variable "enable_deletion_protection" {
    type    = bool
}
variable "enable_cross_zone_load_balancing" {
    type = bool
}
variable "ip_address_type" {
    type = string
}

# ip/alb 일 경우 모듈 수정 필요
# # Target Group
variable "tg_list" {
    type = map(any)
}

variable "add_target_list" {
    type = map(any)  
}

#Listener
variable "forward_listerner" {
    type = map(any)
}

variable "tls_listerner" {
    type = map(any)
}

variable "tags" {
    type    = map(string)
}

variable "bucket_name" {
  type      = string
  default = "dumy"
}

variable "bucket_prefix" {
  type      = string
  default = "dumy"
}

variable "bucket_access_log_enabled" {
    type = bool
    default = false
}
