# Ultra-Simple Job Submission Script
# Just runs the gcloud command directly with your values

Write-Host "🚀 Submitting Flink Job to Dataproc" -ForegroundColor Green
Write-Host ""

# Your values (update if needed)
$PROJECT_ID = "YOUR_GCP_PROJECT_ID"
$CLUSTER = "flink-analytics-cluster"
$REGION = "us-central1"
$BUCKET = "YOUR_GCP_PROJECT_ID-flink-jobs"
$KAFKA = "b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092"

# Upload job file
Write-Host "📤 Uploading job file..." -ForegroundColor Cyan
gsutil cp analytics_job.py gs://$BUCKET/flink-jobs/analytics_job.py

Write-Host "✅ Uploaded!" -ForegroundColor Green
Write-Host ""

# Submit job
Write-Host "📝 Submitting job..." -ForegroundColor Cyan
Write-Host ""

# The actual command (with proper argument passing)
gcloud dataproc jobs submit pyspark `
  gs://$BUCKET/flink-jobs/analytics_job.py `
  --cluster=$CLUSTER `
  --region=$REGION `
  --project=$PROJECT_ID `
  --properties=spark.pyspark.python=python3 `
  -- `
  --kafka-brokers="$KAFKA"

Write-Host ""
Write-Host "✅ Done! Check job status with:" -ForegroundColor Green
Write-Host "gcloud dataproc jobs list --cluster=$CLUSTER --region=$REGION --project=$PROJECT_ID" -ForegroundColor Yellow

