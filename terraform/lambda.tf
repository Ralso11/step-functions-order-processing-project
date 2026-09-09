# --- Package each Lambda function into its own zip file ---

data "archive_file" "validate_order_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/validate_order.py"
  output_path = "${path.module}/validate_order.zip"
}

data "archive_file" "check_inventory_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/check_inventory.py"
  output_path = "${path.module}/check_inventory.zip"
}

data "archive_file" "process_payment_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/process_payment.py"
  output_path = "${path.module}/process_payment.zip"
}

data "archive_file" "save_order_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/save_order.py"
  output_path = "${path.module}/save_order.zip"
}

data "archive_file" "handle_failure_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handle_failure.py"
  output_path = "${path.module}/handle_failure.zip"
}

# --- The five Lambda functions ---

resource "aws_lambda_function" "validate_order" {
  function_name    = "${var.project_name}-${var.environment}-validate-order"
  filename         = data.archive_file.validate_order_zip.output_path
  source_code_hash = data.archive_file.validate_order_zip.output_base64sha256
  handler          = "validate_order.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "check_inventory" {
  function_name    = "${var.project_name}-${var.environment}-check-inventory"
  filename         = data.archive_file.check_inventory_zip.output_path
  source_code_hash = data.archive_file.check_inventory_zip.output_base64sha256
  handler          = "check_inventory.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "process_payment" {
  function_name    = "${var.project_name}-${var.environment}-process-payment"
  filename         = data.archive_file.process_payment_zip.output_path
  source_code_hash = data.archive_file.process_payment_zip.output_base64sha256
  handler          = "process_payment.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "save_order" {
  function_name    = "${var.project_name}-${var.environment}-save-order"
  filename         = data.archive_file.save_order_zip.output_path
  source_code_hash = data.archive_file.save_order_zip.output_base64sha256
  handler          = "save_order.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      ORDERS_TABLE = aws_dynamodb_table.orders.name
    }
  }
}

resource "aws_lambda_function" "handle_failure" {
  function_name    = "${var.project_name}-${var.environment}-handle-failure"
  filename         = data.archive_file.handle_failure_zip.output_path
  source_code_hash = data.archive_file.handle_failure_zip.output_base64sha256
  handler          = "handle_failure.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}