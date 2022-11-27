# terraform-aws-module-nlb

- AWS NLB를 생성하는 공통 모듈

## Usage

### `terraform.tfvars`

- 모든 변수는 적절하게 변경하여 사용

```plaintext
account_id = "12345443" # 아이디 변경 필수
region     = "ap-northeast-2"
prefix     = "dev"
vpc_name   = "eks-test-vpc"

# nlb
nlb_name            = "terraform-nlb"
load_balancer_type  = "network"
internal            = false # true == 내부 LB

# subnet 생성 후 변경 불가. 변경 시 강제로 NLB 재생성
subnet_filters = {
  "Name" = ["eks-test-vpc-subnet-public1-2a", "eks-test-vpc-subnet-public2-2c"]
}

enable_deletion_protection       = true   # 삭제 방지 활성화
enable_cross_zone_load_balancing = true
ip_address_type                  = "ipv4" # ipv4/dualstack

# NLB Access Logs
bucket_name                 = "pefox-test"
bucket_prefix               = "webwas_nlb"
bucket_access_log_enabled   = true

# target group
tg_list = {
  web-tg = {
    target_type            = "instance"     # instance(default), alb, ip, lambda
    
    connection_termination = false          # 등록 취소 시간 초과 끝날 때 연결 종료 여부
    deregistration_delay   = 300            # 등록 취소 대상의 상태를 미사용으로 변경하기 전에 Elastic Load Balancing이 대기하는 시간
    
    tg_port                = 80
    tg_protocol            = "HTTP"
    
    proxy_protocol_v2      = false
    
    slow_start             = 0              # 전체 공유 요청 전 워밍업 시간(초) range: 30-900 비활성화: 0
    
    preserve_client_ip     = true           # 사용자 IP 보존 옵션(기본: true)
    
    stickiness_enabled     = true
    stickiness_type        = "source_ip"    # nlb => source_ip
    
    interval               = 30             # health check 초 range: 5-300  default: 30  
    #path                  = "/"            # health check 경로  HTTP/HTTPS에만 적용
    protocol               = "TCP"
    port                   = "traffic-port" # "traffic-port" or 1-65535 
    healthy_threshold      = 3              # health check success num
    unhealthy_threshold    = 3              # nlb는 healthy_threshold와 값이 같아야함
  }, 
  was-tg = {
    target_type            = "instance" 

    connection_termination = false
    deregistration_delay   = 300

    tg_port                = 80
    tg_protocol            = "TCP"

    proxy_protocol_v2      = false
    
    slow_start             = 0

    preserve_client_ip     = false

    stickiness_enabled     = true
    stickiness_type        = "source_ip"

    interval               = 30
    #path                  = "/"
    protocol               = "TCP"
    port                   = "5600"
    healthy_threshold      = 3
    unhealthy_threshold    = 3
  }
}

# target_group_attachment
tag_name = "Name" # EC2Instance를 찾을 tag의 key 값

# target_group_attachment   locals.tf 에서 설정합니다.
# attach 할 인스턴스들을 data.tf에서 정의합니다.

# TLS를 사용하는 Listener 부분은 locals에 따로 만들어 두었습니다.
# Key값은 중복 될 수 없습니다.

# None TLS
forward_listerner   = {
  tcp-80 = {
    listener_port     = 80
    listener_protocol = "TCP"     # TCP/TLS/UDP/TCP_UDP
    type              = "forward"
    alpn_policy       = ""        # None/HTTP1Only/HTTP2Only/HTTP2Optional/HTTP2Preferred
    listener_tg       = "web-tg"
  },       
  tcp-81 = {
    listener_port     = 81
    listener_protocol = "TCP"     # TCP/TLS/UDP/TCP_UDP
    type              = "forward"
    alpn_policy       = "None"    # None/HTTP1Only/HTTP2Only/HTTP2Optional/HTTP2Preferred
    listener_tg       = "was-tg"
  }
}

# TLS Listener는 locals에서 정의합니다.

tags = {
  "CreatedByTerraform"     = "true"
  "TerraformModuleName"    = "terraform-aws-module-nlb"
  "TerraformModuleVersion" = "v1.0.5"
}
```

------

### `main.tf`

```plaintext
module "nlb" {
  source = "git::https://github.com/aws-nlb-module.git?ref=v1.0.5"

  current_id     = data.aws_caller_identity.current.account_id
  current_region = data.aws_region.current.name

  account_id = var.account_id
  region     = var.region
  prefix     = var.prefix
  vpc_id     = data.aws_vpc.vpc.id

  # nlb
  nlb_name                         = var.nlb_name
  load_balancer_type               = var.load_balancer_type
  internal                         = var.internal
  subnets                          = data.aws_subnets.subnet_list.ids
  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  ip_address_type                  = var.ip_address_type

  bucket_name               = var.bucket_name
  bucket_prefix             = var.bucket_prefix
  bucket_access_log_enabled = var.bucket_access_log_enabled
    
  # target group
  tg_list = var.tg_list

  # target_attachment
  add_target_list = local.add_target_list

  # listener 
  forward_listerner = var.forward_listerner
  tls_listerner     = local.tls_listerner
    
  tags = var.tags
} 
```

------

### `provider.tf`

```plaintext
provider "aws" {
  region = var.region
}
```

------

### `terraform.tf`

```plaintext
terraform {
  required_version = ">= 1.1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.39"
    }
  }

  backend "s3" {
    bucket         = "mzc-dev-tf-state-backend"
    key            = "012345678912/nlb/terraform.state"
    region         = "ap-northeast-2
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

------

### `data.tf`

```plaintext
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}"]
  }
}

data "aws_subnets" "subnet_list" {
  dynamic "filter" {
    for_each = var.subnet_filters
    iterator = tag
    content {
      name   = "tag:${tag.key}"
      values = "${tag.value}"
    }
  }
}

# 사용 할 인스턴스 만큼 data source를 만들어 줍니다.
data "aws_instance" "test-2a" {
  filter {
    name   = "tag:${var.tag_name}"
    values = ["test-2a"]
  }
}

data "aws_instance" "test-2c" {
  filter {
    name   = "tag:${var.tag_name}"
    values = ["test-2c"]
  }
}

# 사용할 SSL 인증서 도메인 만큼 data source를 만들어 줍니다.
data "aws_acm_certificate" "zzerii-site" {
  domain   = "zzerii.site"
  statuses = ["ISSUED"]
}
```

------

### **`locals.tf`**

```
locals {
  # target_name = data.aws_instance.[data.tf의 data source 이름].id
  # Key값은 중복 될 수 없다
  add_target_list = {
    web-tg-test-2a = {
      target_name  = "${data.aws_instance.test-2a.id}"
      target_port  = 80
      target_group = "web-tg"
    },
    web-tg-test-2c = {
      target_name  = "${data.aws_instance.test-2c.id}"
      target_port  = 80
      target_group = "web-tg"
    },
    was-tg-test-2a = {
      target_name  = "${data.aws_instance.test-2a.id}"
      target_port  = 80
      target_group = "was-tg"
    },
    was-tg-test-2c = {
      target_name  = "${data.aws_instance.test-2c.id}"
      target_port  = 80
      target_group = "was-tg"
    },
  }
}

locals {
  tls_listerner   = {
    tls-443 = {
      listener_port     = 443
      listener_protocol = "TLS"       # TCP/TLS/UDP/TCP_UDP
      type              = "forward"
      alpn_policy       = "HTTP1Only" # None/HTTP1Only/HTTP2Only/HTTP2Optional/HTTP2Preferred
      listener_tg       = "was-tg"

      # TLS사용 시 값 입력 
      ssl_policy        = "ELBSecurityPolicy-2016-08"
      certificate_arn   = "${data.aws_acm_certificate.zzerii-site.arn}"
    },
  }
}
```

<hr>

### `variables.tf`

```plaintext
variable "account_id" {
  type    = string
  default = ""
}

variable "region" {
  type    = string
  default = ""
}

variable "prefix" {
  type    = string
  default = ""
}

variable "vpc_name" {
  type    = string
  default = ""
}

#nlb
variable "nlb_name" {
  type    = string
  default = ""
}
variable "load_balancer_type" {
  type = string
}
variable "internal" {
  type    = bool
  default = false
}

variable "subnet_filters" {
  type    = map(list(string))
}

variable "enable_deletion_protection" {
  type    = bool
  default = true
}

variable "enable_cross_zone_load_balancing" {
  type    = bool
  default = true
}

variable "ip_address_type" {
  type    = string
  default = ""
}

variable "bucket_name" {
  type    = string
}

variable "bucket_prefix" {
  type    = string
}

variable "bucket_access_log_enabled" {
  type    = bool
  default = false
}

#TargetGroup
variable "tg_list" {
  type    = map(any)
  default = {}
}

variable "tag_name" {
  type    = string
  default = ""
}

variable "add_target_list" {
  type    = map(any)
  default = {}
}


#Listener
variable "forward_listerner" {
  type    = map(any)
  default = {}
}

variable "tls_listerner" {
  type    = map(any)
  default = {}
}


variable "tags" {
  type    = map(string)
  default = {}
}
```

------

### `outputs.tf`

```plaintext
output "result" {
  value = module.nlb
}
```

## 실행방법

```plaintext
terraform init -get=true -upgrade -reconfigure
terraform validate (option)
terraform plan -var-file=terraform.tfvars -refresh=false -out=planfile
terraform apply planfile
```

- "Objects have changed outside of Terraform" 때문에 `-refresh=false`를 사용
- 실제 UI에서 리소스 변경이 없어보이는 것과 low-level Terraform에서 Object 변경을 감지하는 것에 차이가 있는 것 같음, 다음 링크 참고
  - https://github.com/hashicorp/terraform/issues/28776
- 위 이슈로 변경을 감지하고 리소스를 삭제하는 케이스가 발생 할 수 있음