# --- 1. S3 Bucket for raw data (Images) ---
resource "aws_s3_bucket" "raw_data" {
  bucket        = "ticket-booking-raw-data-${random_id.suffix.hex}"
  force_destroy = true # Allows deleting bucket even if it has files
}

resource "random_id" "suffix" {
  byte_length = 4
}

# --- 2. ECR Repositories (To store your Docker images) ---
resource "aws_ecr_repository" "repos" {
  for_each     = toset(["frontend", "booking-service", "event-catalog", "user-service"])
  name         = "ticket-booking/${each.key}"
  force_delete = true
}

# --- 3. LAMBDA INFRASTRUCTURE (Serverless Requirement) ---

# A. Create the ZIP file from your Python code
data "archive_file" "lambda_zip" {
  type        = "zip"
  # This path points to where we created the python file earlier
  source_file = "${path.module}/../../services/ticket-generator/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# B. Create IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "ticket_booking_lambda_role"

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

# C. Attach Permissions (Logs + S3 Access)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "s3_access" {
  name = "lambda_s3_access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:HeadObject"]
        Resource = "${aws_s3_bucket.raw_data.arn}/*"
      }
    ]
  })
}

# D. Define the Lambda Function
resource "aws_lambda_function" "ticket_generator" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ticket-generator-func"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10
}

# E. Grant S3 permission to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ticket_generator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data.arn
}

# F. The Trigger: Connect S3 Bucket to Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.raw_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ticket_generator.arn
    events              = ["s3:ObjectCreated:*"]
    # Optional: Only trigger for specific file types if needed
    # filter_suffix       = ".jpg" 
  }

  depends_on = [aws_lambda_permission.allow_s3]
}