# ============================================================================
# Web服务器集群模块 - 主配置文件
#
# 此模块创建一个可扩展的Web服务器集群，包括：
# - 启动模板（Launch Template）
# - 自动扩缩容组（Auto Scaling Group）
# - 弹性负载均衡器（ELB）
# - 安全组和规则
# - CloudWatch监控告警
# - 定时扩缩容计划
# ============================================================================

# 配置Terraform和所需的Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # 使用AWS Provider 5.x版本
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"  # 用于处理用户数据脚本模板
    }
  }
}

# 数据源：查询当前区域所有可用区
# 用于将资源分布在多个可用区以提高可用性
data "aws_availability_zones" "all" {}

# 数据源：获取数据库的远程状态
# 从S3存储桶中读取数据库的Terraform状态文件，获取数据库连接信息
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
	bucket = var.db_remote_state_bucket  # S3存储桶名称
	key    = var.db_remote_state_key     # 状态文件在S3中的路径
	region = "ap-east-1"                 # S3存储桶所在区域
  }
}

# 数据源：用户数据脚本模板
# 读取user-data.sh脚本模板并替换其中的变量
data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    server_port = var.server_port                              # Web服务器监听端口
  	db_address  = data.terraform_remote_state.db.outputs.address  # 数据库地址
	  db_port     = data.terraform_remote_state.db.outputs.port     # 数据库端口
    server_text = var.server_text                              # 服务器返回的文本内容
  }
}

# ============================================================================
# 安全组配置
# ============================================================================

# 创建EC2实例的安全组
# 控制进入EC2实例的网络流量
resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  lifecycle {
    create_before_destroy = true  # 在创建新资源之前销毁旧资源，避免名称冲突
  }
}

# 创建安全组规则：允许Web服务器端口的入站流量
# 允许来自任何地址的HTTP请求访问Web服务器
resource "aws_security_group_rule" "allow_server_http_inbound" {
  type = "ingress"  # 入站规则
  security_group_id = "${aws_security_group.instance.id}"

  from_port	  = "${var.server_port}"  # 起始端口（如8080）
  to_port	    = "${var.server_port}"  # 结束端口（如8080）
  protocol	  = "tcp"                 # TCP协议
  cidr_blocks = ["0.0.0.0/0"]         # 允许来自任何IP地址的访问

}

# 创建ELB（负载均衡器）的安全组
# 控制进入负载均衡器的网络流量
resource "aws_security_group" "elb" {
  name = "${var.cluster_name}-elb"

  lifecycle {
    create_before_destroy = true  # 在创建新资源之前销毁旧资源
  }
}

# 创建安全组规则：允许HTTP入站流量到ELB
# 允许用户通过80端口访问负载均衡器
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"  # 入站规则
  security_group_id = "${aws_security_group.elb.id}"

  from_port	  = 80                # HTTP标准端口
  to_port	    = 80                # HTTP标准端口
  protocol	  = "tcp"             # TCP协议
  cidr_blocks = ["0.0.0.0/0"]     # 允许来自任何IP地址的访问
}

# 创建安全组规则：允许ELB的所有出站流量
# 允许负载均衡器向后端EC2实例转发请求
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"   # 出站规则
  security_group_id = "${aws_security_group.elb.id}"

  from_port	  = 0                # 所有端口
  to_port	    = 0                # 所有端口
  protocol	  = "-1"             # 所有协议
  cidr_blocks = ["0.0.0.0/0"]     # 允许到任何IP地址的访问
}

# ============================================================================
# 启动模板和自动扩缩容组配置
# ============================================================================

# 创建启动模板
# 定义EC2实例的配置模板，用于自动扩缩容组创建新实例
resource "aws_launch_template" "example" {
  name_prefix   = "${var.cluster_name}-"        # 模板名称前缀
  image_id      = var.ami                       # AMI镜像ID
  instance_type = var.instance_type             # 实例类型（如t3.small）

  vpc_security_group_ids = [aws_security_group.instance.id]  # 关联的安全组

  user_data = base64encode(data.template_file.user_data.rendered)  # 用户数据脚本（Base64编码）

  lifecycle {
    create_before_destroy = true  # 确保零停机更新
  }
}

# 创建自动扩缩容组
# 管理EC2实例的数量，根据需求自动增加或减少实例
resource "aws_autoscaling_group" "example" {
  name = "${var.cluster_name}-${aws_launch_template.example.name}"

  # 使用启动模板配置
  launch_template {
    id      = aws_launch_template.example.id  # 启动模板ID
    version = "$Latest"                       # 使用最新版本的模板
  }

  availability_zones   = data.aws_availability_zones.all.names  # 分布在所有可用区
  load_balancers       = ["${aws_elb.example.name}"]           # 关联的负载均衡器
  health_check_type    = "ELB"                                 # 使用ELB进行健康检查

  min_size         = "${var.min_size}"      # 最小实例数量
  max_size         = "${var.max_size}"      # 最大实例数量
  min_elb_capacity = "${var.min_size}"      # ELB中最小健康实例数量

  lifecycle {
    create_before_destroy = true  # 确保零停机更新
  }

  # 为实例添加标签
  tag {
    key                 = "Name"
    value               = "${var.cluster_name}"
    propagate_at_launch = true  # 标签会传播到启动的实例
  }
}

# ============================================================================
# 弹性负载均衡器（ELB）配置
# ============================================================================

# 创建经典负载均衡器
# 在多个EC2实例之间分发传入的应用程序流量
resource "aws_elb" "example" {
  name               = "${var.cluster_name}"                    # 负载均衡器名称
  availability_zones = data.aws_availability_zones.all.names   # 部署在所有可用区
  security_groups    = ["${aws_security_group.elb.id}"]        # 关联的安全组

  # 监听器配置：定义如何处理传入请求
  listener {
    lb_port           = 80                      # 负载均衡器监听端口（HTTP标准端口）
    lb_protocol       = "http"                  # 负载均衡器协议
    instance_port     = "${var.server_port}"    # 后端实例端口（如8080）
    instance_protocol = "http"                  # 后端实例协议
  }

  # 健康检查配置：确保只有健康的实例接收流量
  health_check {
    healthy_threshold   = 2                           # 连续成功检查次数后标记为健康
    unhealthy_threshold = 2                           # 连续失败检查次数后标记为不健康
    timeout             = 3                           # 健康检查超时时间（秒）
    interval            = 30                          # 健康检查间隔时间（秒）
    target              = "HTTP:${var.server_port}/"  # 健康检查目标路径
  }

  lifecycle {
    create_before_destroy = true  # 确保零停机更新
  }
}

# ============================================================================
# 定时扩缩容计划
# ============================================================================

# 创建工作时间扩容计划
# 在工作时间（上午9点）自动增加实例数量以应对高流量
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0  # 只有启用自动扩缩容时才创建

  scheduled_action_name = "scale-out-during-business-hours"  # 计划动作名称
  min_size              = 2                                  # 最小实例数
  max_size              = 10                                 # 最大实例数
  desired_capacity      = 10                                 # 期望实例数
  recurrence            = "0 9 * * *"                        # Cron表达式：每天上午9点

  autoscaling_group_name = "${aws_autoscaling_group.example.name}"  # 目标自动扩缩容组
}

# 创建夜间缩容计划
# 在下班时间（下午5点）自动减少实例数量以节省成本
resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0  # 只有启用自动扩缩容时才创建

  scheduled_action_name = "scale-in-at-night"  # 计划动作名称
  min_size              = 2                     # 最小实例数
  max_size              = 10                    # 最大实例数
  desired_capacity      = 2                     # 期望实例数（减少到最小值）
  recurrence            = "0 17 * * *"          # Cron表达式：每天下午5点

  autoscaling_group_name = "${aws_autoscaling_group.example.name}"  # 目标自动扩缩容组
}

# ============================================================================
# CloudWatch监控告警
# ============================================================================

# 创建CPU使用率高告警
# 当CPU使用率超过阈值时触发告警，可用于自动扩容
resource "aws_cloudwatch_metric_alarm" "high_cpu_utilisation" {
  alarm_name  = "${var.cluster_name}-high-cpu-utilisation"  # 告警名称
  namespace   = "AWS/EC2"                                   # AWS服务命名空间
  metric_name = "CPUUtilization"                            # 监控指标：CPU使用率

  # 监控维度：指定要监控的自动扩缩容组
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.example.name}"
  }

  comparison_operator = "GreaterThanThreshold"  # 比较操作符：大于阈值
  evaluation_periods  = 1                       # 评估周期数：1个周期
  period              = 300                     # 统计周期：300秒（5分钟）
  statistic           = "Average"               # 统计方法：平均值
  threshold           = 90                      # 阈值：90%
  unit                = "Percent"               # 单位：百分比
}

# 创建CPU积分余额低告警
# 仅适用于T系列实例（如t2、t3），监控CPU积分余额
resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
  # 只有当实例类型以"t"开头时才创建此告警（T系列实例）
  count = "${format("%.1s", var.instance_type) == "t" ? 1 : 0}"

  alarm_name  = "${var.cluster_name}-low-cpu-credit-balance"  # 告警名称
  namespace   = "AWS/EC2"                                     # AWS服务命名空间
  metric_name = "CPUCreditBalance"                            # 监控指标：CPU积分余额

  # 监控维度：指定要监控的自动扩缩容组
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.example.name}"
  }

  comparison_operator = "LessThanThreshold"  # 比较操作符：小于阈值
  evaluation_periods  = 1                    # 评估周期数：1个周期
  period              = 300                  # 统计周期：300秒（5分钟）
  statistic           = "Minimum"            # 统计方法：最小值
  threshold           = 10                   # 阈值：10个积分
  unit                = "Count"              # 单位：计数
}
