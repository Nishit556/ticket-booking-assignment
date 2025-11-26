#!/bin/bash
# Script to submit Flink job to GCP Dataproc
# Usage: ./submit-dataproc-job.sh <gcp-project-id> <cluster-name> <region> <gcs-bucket> <kafka-brokers>

set -e

PROJECT_ID=${1:-"your-project-id"}
CLUSTER_NAME=${2:-"flink-analytics-cluster"}
REGION=${3:-"us-central1"}
GCS_BUCKET=${4:-"your-bucket-name"}
KAFKA_BROKERS=${5:-"localhost:9092"}

echo "🚀 Submitting Flink job to Dataproc..."
echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "GCS Bucket: $GCS_BUCKET"
echo "Kafka Brokers: $KAFKA_BROKERS"

# Upload the job file to GCS if not already there
JOB_FILE="analytics_job.py"
GCS_JOB_PATH="gs://${GCS_BUCKET}/flink-jobs/${JOB_FILE}"

echo "📤 Uploading job file to GCS..."
gsutil cp "${JOB_FILE}" "${GCS_JOB_PATH}"

# Submit the Flink job
echo "📝 Submitting job to Dataproc..."

gcloud dataproc jobs submit flink \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --cluster="${CLUSTER_NAME}" \
  --py-files="${GCS_JOB_PATH}" \
  --properties="flink.jobmanager.memory.process.size=1024m,flink.taskmanager.memory.process.size=1024m" \
  -- \
  --python "${GCS_JOB_PATH}" \
  --env KAFKA_BROKERS="${KAFKA_BROKERS}"

echo "✅ Job submitted successfully!"
echo "Check job status with:"
echo "  gcloud dataproc jobs list --project=${PROJECT_ID} --region=${REGION} --cluster=${CLUSTER_NAME}"

