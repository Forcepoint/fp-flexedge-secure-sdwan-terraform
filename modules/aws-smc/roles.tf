locals {
  SSM_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  mgmt_primary_policies = concat([
    aws_iam_policy.ec2_create_tag.arn,
    aws_iam_policy.publish_status_update.arn
    ],
    [],
  var.enable_ssm ? local.SSM_policies : [])
  mgmt_replica_policies = concat([
    aws_iam_policy.ec2_describe_instance.arn
  ],
    var.replica_count >0 ? [aws_iam_policy.receive_status_update[0].arn]: [],
    [],
  var.enable_ssm ? local.SSM_policies : [])
  log_policies = concat(
    var.logserver_count > 0 ? [
      aws_iam_policy.ec2_describe_instance.arn,
      aws_iam_policy.receive_status_update[0].arn
    ]:[],
    var.enable_ssm ? local.SSM_policies : [])
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#create tag to mgmt primary instance
data "aws_iam_policy_document" "ec2_create_tag" {
  #ideally, we should scope to mgmt_primary instance_id here. But this is not
  #possible for now as it introduces a cycle in the terraform obj.
  statement {
    actions   = ["ec2:CreateTags"]
    resources = ["*"]
  }
}
resource "aws_iam_policy" "ec2_create_tag" {
  name_prefix = "ec2_create_tag"
  description = "Create tag to EC2 instance"
  policy      = data.aws_iam_policy_document.ec2_create_tag.json
}

#describe EC2 instance
data "aws_iam_policy_document" "ec2_describe_instance" {
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}
resource "aws_iam_policy" "ec2_describe_instance" {
  name_prefix = "ec2_describe_instance"
  description = "Describe EC2 instance"
  policy      = data.aws_iam_policy_document.ec2_describe_instance.json
}

# we have 3 different roles
resource "aws_iam_role" "mgmt_primary" {
  name_prefix        = "smc_mgmt_primary"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}
resource "aws_iam_instance_profile" "mgmt_primary" {
  name_prefix = "smc_mgmt_primary"
  role        = aws_iam_role.mgmt_primary.name
}
resource "aws_iam_role" "mgmt_replica" {
  name_prefix        = "smc_mgmt_replica"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}
resource "aws_iam_instance_profile" "mgmt_replica" {
  name_prefix = "smc_mgmt_replica"
  role        = aws_iam_role.mgmt_replica.name
}
resource "aws_iam_role" "log" {
  name_prefix        = "smc_log"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}
resource "aws_iam_instance_profile" "log" {
  name_prefix = "smc_log"
  role        = aws_iam_role.log.name
}

#we attach policies to roles
resource "aws_iam_role_policy_attachment" "mgmt_primary" {
  count      = length(local.mgmt_primary_policies)
  role       = aws_iam_role.mgmt_primary.name
  policy_arn = local.mgmt_primary_policies[count.index]
}
resource "aws_iam_role_policy_attachment" "mgmt_replica" {
  count      = length(local.mgmt_replica_policies)
  role       = aws_iam_role.mgmt_replica.name
  policy_arn = local.mgmt_replica_policies[count.index]
}
resource "aws_iam_role_policy_attachment" "log" {
  count      = length(local.log_policies)
  role       = aws_iam_role.log.name
  policy_arn = local.log_policies[count.index]
}

# Implicit dependencies are not enough, instance might be generated before
# we have the profile. The workaround is to have a dependency on local
# resource where we establish that such a profile exists before we continue.
#
# https://github.com/hashicorp/terraform/issues/15341
resource "null_resource" "aws_iam_instance_profile_poll" {
  depends_on = [
    aws_iam_instance_profile.mgmt_primary,
    aws_iam_instance_profile.mgmt_replica,
    aws_iam_instance_profile.log
  ]
  provisioner "local-exec" {
    command = <<-EOF
      poll() {
        for _ in $(seq 120); do
          if aws iam get-instance-profile --instance-profile-name $1; then
            return 0
          fi
          sleep 1
        done
        echo "ERROR: Instance profile \"$1\" not available"
        return 1
      }
      poll ${aws_iam_instance_profile.mgmt_primary.name} || exit 1
      poll ${aws_iam_instance_profile.mgmt_replica.name} || exit 1
      poll ${aws_iam_instance_profile.log.name} || exit 1
    EOF
  }
}
