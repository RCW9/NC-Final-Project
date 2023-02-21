resource "aws_lambda_function" "dummy-file-reader" {
  filename      = "${path.module}/../zips/reader.zip"
  function_name = var.dummy_lambda_name
  role          = aws_iam_role.ingest-lambda-role.arn
  handler       = "reader.lambda_handler"
  runtime       = "python3.9"
}

resource "aws_lambda_permission" "allow_s3_dummy_file_reader" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.dummy-file-reader.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.ingest-bucket.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_function" "ingestion_lambda" {
  filename         = data.archive_file.ingestion_lambda_zipper.output_path
  source_code_hash = data.archive_file.ingestion_lambda_zipper.output_base64sha256
  function_name    = var.ingestion_lambda_name
  role             = aws_iam_role.ingest-lambda-role.arn
  handler          = "ingestion.lambda_handler"
  runtime          = "python3.9"
  layers           = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:3"]

}

resource "aws_lambda_permission" "allow_eventbridge_ingestion_lambda" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ingestion_lambda.function_name
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.ingestion_lambda_event_rule.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_cloudwatch_event_rule" "ingestion_lambda_event_rule" {
  name                = "ingestion_lambda_event_rule"
  description         = "retry scheduled every 2 mins"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "ingestion_lambda_target" {
  arn  = aws_lambda_function.ingestion_lambda.arn
  rule = aws_cloudwatch_event_rule.ingestion_lambda_event_rule.name
}

resource "aws_lambda_function" "processing_lambda" {
  filename         = data.archive_file.processing_lambda_zipper.output_path
  source_code_hash = data.archive_file.processing_lambda_zipper.output_base64sha256
  function_name    = var.processing_lambda_name
  role             = aws_iam_role.processed-lambda-role.arn
  handler          = "transformation.transform_data"
  runtime          = "python3.9"
  layers           = ["arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:3"]
}

