data "aws_region" "current" {}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

locals {
  sgroup_ingress_cidrlist = concat(
    var.sgroup_ingress_cidrlist,
    [data.aws_vpc.vpc.cidr_block]
  )
}

resource "aws_key_pair" "smc" {
  key_name_prefix = var.namespace
  public_key      = file(var.sshkey)
  tags            = merge(var.default_tags, { Name = join("-", [var.namespace, "keypair"]) })
}

locals {
  smc_port_ranges = [
    {
      type        = "ingress"
      from_port   = 22
      to_port     = 22
      cidr_blocks = local.sgroup_ingress_cidrlist
      protocol    = "TCP"
    },
    {
      type        = "ingress"
      from_port   = 3020
      to_port     = 3023
      cidr_blocks = local.sgroup_ingress_cidrlist
      protocol    = "TCP"
    },
    {
      type        = "ingress"
      from_port   = 5000
      to_port     = 5000
      cidr_blocks = local.sgroup_ingress_cidrlist
      protocol    = "TCP"
    },
    {
      type        = "ingress"
      from_port   = 8080
      to_port     = 8085
      cidr_blocks = local.sgroup_ingress_cidrlist
      protocol    = "TCP"
    },
    {
      type        = "ingress"
      from_port   = 8902
      to_port     = 8931
      cidr_blocks = local.sgroup_ingress_cidrlist
      protocol    = "TCP"
    },
    {
      type        = "ingress"
      from_port   = 1 #https://www.terraform.io/docs/providers/aws/r/security_group.html#from_port
      to_port     = 8
      protocol    = "ICMP"
      cidr_blocks = local.sgroup_ingress_cidrlist
    },
    {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "smc" {
  name_prefix = join("-", [var.namespace, "smc-sg"])
  description = "Allow smc ports"
  vpc_id      = var.vpc_id
  tags        = var.default_tags
}

resource "aws_security_group_rule" "smc" {
  count             = length(local.smc_port_ranges)
  type              = local.smc_port_ranges[count.index].type
  from_port         = local.smc_port_ranges[count.index].from_port
  to_port           = local.smc_port_ranges[count.index].to_port
  protocol          = local.smc_port_ranges[count.index].protocol
  cidr_blocks       = local.smc_port_ranges[count.index].cidr_blocks
  security_group_id = aws_security_group.smc.id
}

resource "aws_secretsmanager_secret" "api_key" {
  count                   = var.primary_hostname != "" ? 0 : 1
  name_prefix             = join("-", [var.namespace, "api-key"])
  recovery_window_in_days = 0
  tags                    = var.default_tags
}
resource "aws_secretsmanager_secret" "api_certificate" {
  count                   = var.primary_hostname != "" ? 0 : 1
  name_prefix             = join("-", [var.namespace, "api-certificate"])
  recovery_window_in_days = 0
  tags                    = var.default_tags
}

locals {
  #conditional values whether we deploy primary mgmt or not
  primary_hostname   = var.primary_hostname != "" ? var.primary_hostname : aws_instance.mgmt_primary[0].public_dns
  primary_instance   = var.primary_hostname != "" ? "" : aws_instance.mgmt_primary[0].id
  primary_private_ip = var.primary_hostname != "" ? "" : aws_instance.mgmt_primary[0].private_ip
  primary_public_ip  = data.dns_a_record_set.primary.addrs[0]
}

data "dns_a_record_set" "primary" {
  host = local.primary_hostname
}

resource "aws_instance" "mgmt_primary" {
  depends_on = [
    aws_iam_role_policy_attachment.mgmt_primary,
    null_resource.aws_iam_instance_profile_poll
  ]
  #do not deploy if primary_hostname is set
  count         = var.primary_hostname != "" ? 0 : 1
  ami           = var.smc_ami_id
  instance_type = var.mgmt_vm_size
  subnet_id     = var.subnet_ids[0]
  user_data     = data.template_cloudinit_config.mgmt_primary.rendered
  key_name      = aws_key_pair.smc.key_name
  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = var.premium_storage ? "io1" : "gp3"
    iops        = var.premium_storage ? var.disk_size_gb * 50 : 0
  }
  iam_instance_profile        = aws_iam_instance_profile.mgmt_primary.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.smc.id]
  tags = merge(var.default_tags, {
    Name = join("-", [var.namespace, "smc-vm"])
  })
  lifecycle {
    ignore_changes = [
      tags,
      root_block_device["tags"],
    ]
  }
  private_ip = var.static_private_ips["mgmt"]
}

resource "aws_instance" "mgmt_replica" {
  depends_on = [
    aws_iam_role_policy_attachment.mgmt_replica,
    null_resource.aws_iam_instance_profile_poll,
    null_resource.wait_for_logservers
  ]
  count         = var.replica_count
  ami           = var.smc_ami_id
  instance_type = var.mgmt_vm_size
  subnet_id     = element(var.subnet_ids, count.index + 1)
  user_data     = data.template_cloudinit_config.mgmt_replica[count.index].rendered
  key_name      = aws_key_pair.smc.key_name
  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = var.premium_storage ? "io1" : "gp3"
    iops        = var.premium_storage ? var.disk_size_gb * 50 : 0
  }
  iam_instance_profile        = aws_iam_instance_profile.mgmt_replica.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.smc.id]
  tags = merge(var.default_tags, {
    Name = join("-", [var.namespace, "smc-vm-${count.index + 1}"])
  })
  lifecycle {
    ignore_changes = [
      tags,
      root_block_device["tags"],
    ]
  }
}

resource "aws_instance" "log" {
  depends_on = [
    aws_iam_role_policy_attachment.log,
    null_resource.aws_iam_instance_profile_poll
  ]
  count         = var.logserver_count
  ami           = var.smc_ami_id
  instance_type = var.log_vm_size
  subnet_id     = element(var.subnet_ids, count.index)
  user_data     = data.template_cloudinit_config.log[count.index].rendered
  key_name      = aws_key_pair.smc.key_name
  root_block_device {
    volume_size = var.disk_size_gb
    volume_type = var.premium_storage ? "io1" : "gp3"
    iops        = var.premium_storage ? var.disk_size_gb * 50 : 0
  }
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.log.id
  vpc_security_group_ids      = [aws_security_group.smc.id]
  tags = merge(var.default_tags,
    {
      Name = join("-", [var.namespace, "log-vm", count.index])
  })
  lifecycle {
    ignore_changes = [
      tags,
      root_block_device["tags"],
    ]
  }
  private_ip = count.index == 0 ? var.static_private_ips["log"] : null
}

resource "null_resource" "wait_for_mgmt_primary" {
  depends_on = [aws_instance.mgmt_primary]
  count         = var.primary_hostname != "" ? 0 : 1

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.sshkeypriv)
      host        = aws_instance.mgmt_primary[count.index].public_ip
    }
    inline = [
      "sudo cloud-init status --wait | tr -s '.'",
    ]
  }
}

resource "null_resource" "wait_for_logservers" {
  depends_on = [aws_instance.log]
  count      = var.wait_for_logservers ? var.logserver_count : 0

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.sshkeypriv)
      host        = aws_instance.log[count.index].public_ip
    }
    inline = [
      "sudo cloud-init status --wait | tr -s '.'",
    ]
  }
}

resource "null_resource" "create_smc_backup" {
  depends_on = [
    null_resource.wait_for_mgmt_primary,
    null_resource.wait_for_logservers
  ]
  count = var.create_smc_backup == true ? 1 : 0

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.sshkeypriv)
      host        = aws_instance.mgmt_primary[0].public_ip
    }
    inline = [
      "rm -fr ${local.smc_backup_local_path}",
      "mkdir ${local.smc_backup_local_path}",
      "chmod 777 ${local.smc_backup_local_path}",
      "sudo ${local.smc_base}/bin/sgBackupMgtSrv.sh -path ${local.smc_backup_local_path}",
      "sudo mv ${local.smc_backup_local_path}/*.zip ${local.smc_backup_name}"
    ]
  }
}

# Make sure that, regardless of sgroup_ingress_cidrlist, all instances deployed
# by the module can talk to each other over public interfaces.
resource "aws_security_group_rule" "smc_cross_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.smc.id

  cidr_blocks = concat(
    [format("%s/32", local.primary_public_ip)],
    [for ip in aws_instance.mgmt_replica.*.public_ip : format("%s/32", ip)],
    [for ip in aws_instance.log.*.public_ip : format("%s/32", ip)],
  )
}
