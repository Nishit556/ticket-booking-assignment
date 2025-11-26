#!/bin/bash
# Simple script to submit Flink job to GCP Dataproc
# This is the RECOMMENDED method for the assignment

set -e

# Check if required arguments are provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <gcp-project-id> <cluster-name> <region> <gcs-bucket> <kafka-brokers>"
    echo "Example: $0 YOUR_GCP_PROJECT_ID flink-analytics-cluster us-central1 YOUR_GCP_PROJECT_ID-flink-jobs 'broker1:9092,broker2:9092'"
    exit 1
fi

PROJECT_ID=$1
CLUSTER_NAME=$2
REGION=$3
GCS_BUCKET=$4
KAFKA_BROKERS=$5

echo "=========================================="
echo "🚀 Submitting Flink Job to Dataproc"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "GCS Bucket: $GCS_BUCKET"
echo "Kafka Brokers: $KAFKA_BROKERS"
echo "=========================================="

# Step 1: Upload job file to GCS
JOB_FILE="analytics_job.py"
GCS_JOB_PATH="gs://${GCS_BUCKET}/flink-jobs/${JOB_FILE}"

echo ""
echo "📤 Step 1: Uploading job file to GCS..."
gsutil cp "${JOB_FILE}" "${GCS_JOB_PATH}"
echo "✅ Upload complete: ${GCS_JOB_PATH}"

# Step 2: Submit the Flink job using PyFlink
echo ""
echo "📝 Step 2: Submitting Flink job to cluster..."

gcloud dataproc jobs submit pyspark "${GCS_JOB_PATH}" \
  --cluster="${CLUSTER_NAME}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --jars="gs://spark-lib/bigquery/spark-bigquery-latest_2.12.jar" \
  --properties="spark.pyspark.python=python3" \
  -- \
  --kafka-brokers "${KAFKA_BROKERS}"

echo ""
echo "=========================================="
echo "✅ Job Submitted Successfully!"
echo "=========================================="
echo ""
echo "📊 Check job status:"
echo "  gcloud dataproc jobs list --cluster=${CLUSTER_NAME} --region=${REGION} --project=${PROJECT_ID}"
echo ""
echo "📄 View logs:"
echo "  gcloud dataproc jobs describe <JOB_ID> --region=${REGION} --project=${PROJECT_ID}"
echo ""

