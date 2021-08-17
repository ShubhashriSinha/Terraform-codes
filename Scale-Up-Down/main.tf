provider "aws" {
  region = "ap-south-1"
  access_key = "<access-key>" 
  secret_key = "<Secret-key>"

}

resource "aws_iam_role" "iam_for_lambda" {
  name = "ec2-rds-scheduler"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
              "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF


}

resource "aws_iam_policy" "policy_for_lambda" {
  name        = "ec2-auto-start-stop"
  description = "For scheduling ec2 instances"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "ec2:DescribeInstances",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "logs:CreateLogGroup",
                "logs:PutLogEvents",
                "ec2:ModifyInstanceAttribute"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "terraform_policy" {
  role = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = aws_iam_policy.policy_for_lambda.arn
}

resource "aws_iam_policy" "policy_for_lambda2" {
  name        = "rds-DB-instance-start-stop"
  description = "For scheduling RDS DB instances"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:StopDBInstance",
                "rds:StartDBInstance"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "terraform_policy2" {
  role = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = aws_iam_policy.policy_for_lambda2.arn
}

resource "aws_lambda_function" "ec2-scale-start" {
  filename      = "lambda_ec2_scale.zip"
  function_name = "ec2-scale-start"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_ec2_scale.handler"
  source_code_hash = "${filebase64sha256("lambda_ec2_scale.zip")}"
  runtime = "nodejs14.x"
  timeout = "180"
}

resource "aws_lambda_function" "ec2-stop" {
  filename      = "lambda_ec2_stop.zip"
  function_name = "ec2-stop"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_ec2_stop.handler"
  source_code_hash = "${filebase64sha256("lambda_ec2_stop.zip")}"
  runtime = "nodejs14.x"
}

resource "aws_lambda_function" "rds-db-instance-start" {
  filename      = "lambda_rds_start.zip"
  function_name = "rds-db-start"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_rds_start.lambda_handler"
  source_code_hash = "${filebase64sha256("lambda_rds_start.zip")}"
  runtime = "python3.8"
  environment {
    variables = {
      DBInstanceName = "${var.db_identifier}"
    }
  }

}

resource "aws_lambda_function" "rds-db-instance-stop" {
  filename      = "lambda_rds_stop.zip"
  function_name = "rds-db-stop"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_rds_stop.lambda_handler"
  source_code_hash = "${filebase64sha256("lambda_rds_stop.zip")}"
  runtime = "python3.8"
    environment {
    variables = {
      DBInstanceName = "${var.db_identifier}"
    }
  }

}

resource "aws_iam_role_policy" "inline_policy_for_lambda_db_start" {
  name = "inline_policy_lambda_db_start"
  role = aws_iam_role.iam_for_lambda.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "lambda:GetFunctionConfiguration",
            "Resource": "${aws_lambda_function.rds-db-instance-start.arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "inline_policy_for_lambda_db_stop" {
  name = "inline_policy_lambda_db_stop"
  role = aws_iam_role.iam_for_lambda.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "lambda:GetFunctionConfiguration",
            "Resource": "${aws_lambda_function.rds-db-instance-stop.arn}"
        }
    ]
}
EOF
}

resource "aws_cloudwatch_event_rule" "start_instances" {
  name        = "ec2_rds_start"
  description = "Start ec2 and RDS db instances at 6AM"

  schedule_expression = "cron(30 0 * * ? *)"

}

resource "aws_cloudwatch_event_target" "ec2-start-instance-scheduling" {
  arn  = aws_lambda_function.ec2-scale-start.arn
  rule = aws_cloudwatch_event_rule.start_instances.id

  input = <<EOF

{
  "instanceRegion": "ap-south-1",
  "instanceId": "${var.ec2_instance_id}",
  "instanceType": "t2.small"
}

EOF
}

resource "aws_cloudwatch_event_target" "rds-start-instance-scheduling" {
  arn  = aws_lambda_function.rds-db-instance-start.arn
  rule = aws_cloudwatch_event_rule.start_instances.id

}

resource "aws_cloudwatch_event_rule" "stop_instances" {
  name        = "ec2_rds_stop"
  description = "Stop ec2 and RDS db instances at 11PM"

  schedule_expression = "cron(30 17 * * ? *)"

}

resource "aws_cloudwatch_event_target" "ec2-stop-instance-scheduling" {
  arn  = aws_lambda_function.ec2-stop.arn
  rule = aws_cloudwatch_event_rule.stop_instances.id

  input = <<EOF

{
  "instanceRegion": "ap-south-1",
  "instanceId": "${var.ec2_instance_id}"
}

EOF
}

resource "aws_cloudwatch_event_target" "rds-stop-instance-scheduling" {
  arn  = aws_lambda_function.rds-db-instance-stop.arn
  rule = aws_cloudwatch_event_rule.stop_instances.id
}

resource "aws_cloudwatch_event_rule" "scale_down_instances" {
  name        = "ec2_rds_scale_down"
  description = "scale down ec2 and rds instances at 6PM"

  schedule_expression = "cron(30 12 * * ? *)"

}

resource "aws_cloudwatch_event_target" "ec2_instance_scale_down" {
  arn  = aws_lambda_function.ec2-scale-start.arn
  rule = aws_cloudwatch_event_rule.scale_down_instances.id

  input = <<EOF

{
  "instanceRegion": "ap-south-1",
  "instanceId": "${var.ec2_instance_id}",
  "instanceType": "t2.micro"
}

EOF
}