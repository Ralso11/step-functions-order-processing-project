# --- IAM role each Lambda function runs as ---

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Scoped permission: only save_order can write to DynamoDB ---

resource "aws_iam_role_policy" "dynamodb_write" {
  name = "${var.project_name}-dynamodb-write"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.orders.arn
      }
    ]
  })
}

# --- IAM role the Step Functions state machine itself runs as ---

resource "aws_iam_role" "step_functions_exec" {
  name = "${var.project_name}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

# --- Scoped permission: the state machine can only invoke these 5 specific Lambdas ---

resource "aws_iam_role_policy" "step_functions_invoke_lambda" {
  name = "${var.project_name}-sfn-invoke-lambda"
  role = aws_iam_role.step_functions_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          aws_lambda_function.validate_order.arn,
          aws_lambda_function.check_inventory.arn,
          aws_lambda_function.process_payment.arn,
          aws_lambda_function.save_order.arn,
          aws_lambda_function.handle_failure.arn
        ]
      }
    ]
  })
}