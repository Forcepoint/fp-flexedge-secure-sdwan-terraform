#primary server sends a message to SNS topic when the server is ready;
#the message is forwarded to each subscriber (each replica and log server)
resource "aws_sns_topic" "primary_status_update" {
  name_prefix = "primary_status_update"
}

#replica server waits until it receives a message from its own SQS queue
resource "aws_sqs_queue" "replica_status_update" {
  depends_on  = [aws_instance.mgmt_primary]
  count       = var.replica_count
  name_prefix = "replica_status_update"

  sqs_managed_sse_enabled = true
}

#log server waits until it receives a message from its own SQS queue
resource "aws_sqs_queue" "log_status_update" {
  depends_on  = [aws_instance.mgmt_primary]
  count       = var.logserver_count
  name_prefix = "log_status_update"

  sqs_managed_sse_enabled = true
}

#https://github.com/hashicorp/terraform-provider-aws/issues/13980#issuecomment-725069967
resource "time_sleep" "wait_60_seconds" {
  depends_on = [
    aws_sqs_queue.replica_status_update,
    aws_sqs_queue.log_status_update
  ]
  create_duration = "60s"
}

data "aws_iam_policy_document" "replica_status_update" {
  policy_id = "sqspolicy"
  count     = var.replica_count
  statement {
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.replica_status_update[count.index].arn]
    condition {
      test     = "ArnEquals"
      values   = [aws_sns_topic.primary_status_update.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "replica_status_update" {
  depends_on = [time_sleep.wait_60_seconds]
  count      = var.replica_count
  queue_url  = aws_sqs_queue.replica_status_update[count.index].id
  policy     = data.aws_iam_policy_document.replica_status_update[count.index].json
}

data "aws_iam_policy_document" "log_status_update" {
  policy_id = "sqspolicy"
  count     = var.logserver_count
  statement {
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.log_status_update[count.index].arn]
    condition {
      test     = "ArnEquals"
      values   = [aws_sns_topic.primary_status_update.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "log_status_update" {
  depends_on = [time_sleep.wait_60_seconds]
  count      = var.logserver_count
  queue_url  = aws_sqs_queue.log_status_update[count.index].id
  policy     = data.aws_iam_policy_document.log_status_update[count.index].json
}

resource "aws_sns_topic_subscription" "replica_status_update" {
  count     = var.replica_count
  topic_arn = aws_sns_topic.primary_status_update.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.replica_status_update[count.index].arn
}

resource "aws_sns_topic_subscription" "log_status_update" {
  count     = var.logserver_count
  topic_arn = aws_sns_topic.primary_status_update.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.log_status_update[count.index].arn
}

data "aws_iam_policy_document" "publish_status_update" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.primary_status_update.arn]
  }
}

resource "aws_iam_policy" "publish_status_update" {
  name_prefix = "publish_status_update"
  policy      = data.aws_iam_policy_document.publish_status_update.json
}

data "aws_iam_policy_document" "receive_status_update" {
  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]
    resources = concat(aws_sqs_queue.replica_status_update.*.arn,
    aws_sqs_queue.log_status_update.*.arn)
  }
}

resource "aws_iam_policy" "receive_status_update" {
  name_prefix = "receive_status_update"
  policy      = data.aws_iam_policy_document.receive_status_update.json
  count = var.logserver_count + var.replica_count > 0 ? 1:0
}
