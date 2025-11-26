#!/bin/bash
# Initialization script for Dataproc cluster
# This script installs Python dependencies for the Flink analytics job

set -e

echo "Installing Python dependencies for Flink analytics job..."

# Dataproc 2.1 comes with Flink 1.15.x pre-installed
# We only need to install the Kafka connector JAR

# Download Kafka connector for Flink 1.15
KAFKA_CONNECTOR_VERSION="1.15.4"
KAFKA_JAR_URL="https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar"
FLINK_LIB_DIR="/usr/lib/flink/lib"

echo "Downloading Kafka connector for Flink 1.15..."
wget -O "${FLINK_LIB_DIR}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar" "${KAFKA_JAR_URL}"

echo "Kafka connector installed successfully!"

# Verify installation
if [ -f "${FLINK_LIB_DIR}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar" ]; then
    echo "✅ Kafka connector JAR is in place"
else
    echo "❌ Failed to install Kafka connector"
    exit 1
fi

echo "Dataproc Flink cluster is ready for analytics jobs!"

