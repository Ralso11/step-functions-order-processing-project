resource "aws_sfn_state_machine" "order_processing" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.step_functions_exec.arn

  definition = templatefile("${path.module}/order_workflow.asl.json", {
    validate_order_arn  = aws_lambda_function.validate_order.arn
    check_inventory_arn = aws_lambda_function.check_inventory.arn
    process_payment_arn = aws_lambda_function.process_payment.arn
    save_order_arn      = aws_lambda_function.save_order.arn
    handle_failure_arn  = aws_lambda_function.handle_failure.arn
  })
}