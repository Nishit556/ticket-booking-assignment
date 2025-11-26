#!/usr/bin/env python3
import os
import sys
import subprocess
import argparse
import shutil

def find_command(cmd):
    if sys.platform == "win32":
        for ext in ["", ".cmd", ".exe"]:
            path = shutil.which(f"{cmd}{ext}")
            if path: return path
    return shutil.which(cmd)

def get_cluster_zone(gcloud_path, project, region, cluster):
    print(f"Locating cluster '{cluster}' in region '{region}'...")
    cmd = [
        gcloud_path, "dataproc", "clusters", "describe", cluster,
        f"--region={region}",
        f"--project={project}",
        "--format=value(config.gceClusterConfig.zoneUri)"
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        zone_uri = result.stdout.strip()
        zone = zone_uri.split('/')[-1]
        print(f"Found cluster in zone: {zone}")
        return zone
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Could not find cluster zone. Is the cluster running?")
        print(e.stderr)
        sys.exit(1)

def submit_job(project_id, cluster_name, region, gcs_bucket, kafka_brokers):
    # 1. Setup Tools
    gsutil_path = find_command("gsutil")
    gcloud_path = find_command("gcloud")
    
    if not gsutil_path or not gcloud_path:
        print("ERROR: Cloud SDK (gcloud/gsutil) not found.")
        sys.exit(1)

    # 2. Upload Job File to GCS
    job_file = "analytics_job.py"
    if not os.path.exists(job_file):
        print(f"ERROR: {job_file} not found in current folder.")
        sys.exit(1)
        
    gcs_job_path = f"gs://{gcs_bucket}/flink-jobs/{job_file}"
    print(f"Uploading {job_file} to {gcs_job_path}...")
    subprocess.run([gsutil_path, "cp", job_file, gcs_job_path], check=True)

    # 3. Get Zone & Define Master Node
    zone = get_cluster_zone(gcloud_path, project_id, region, cluster_name)
    master_node = f"{cluster_name}-m"

    # 4. Construct Remote Command
    # FIX 1: Use Kafka Connector 1.15.4 to match Dataproc's Flink 1.15
    kafka_jar_url = "https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.15.4/flink-sql-connector-kafka-1.15.4.jar"
    kafka_jar_name = "flink-sql-connector-kafka-1.15.4.jar"
    remote_jar_path = f"/tmp/{kafka_jar_name}"
    remote_job_path = "/tmp/analytics_job.py"
    
    # FIX 2: Added '-m yarn-cluster' to tell Flink to run on YARN
    remote_command = (
        f"export KAFKA_BROKERS='{kafka_brokers}'; "
        f"export PYFLINK_CLIENT_EXECUTABLE=python3; "
        f"export PYFLINK_EXECUTABLE=python3; "
        f"[ -f {remote_jar_path} ] || wget -O {remote_jar_path} {kafka_jar_url}; "
        f"gsutil cp {gcs_job_path} {remote_job_path}; "
        f"flink run -m yarn-cluster -pyexec python3 -py {remote_job_path} -j {remote_jar_path}"
    )

    print(f"Connecting to {master_node} to run Flink job...")
    
    ssh_cmd = [
        gcloud_path, "compute", "ssh", master_node,
        f"--project={project_id}",
        f"--zone={zone}",
        "--command", remote_command
    ]

    # 5. Execute
    try:
        subprocess.run(ssh_cmd, check=True)
        print("\nJob submitted successfully (Check the output logs above)")
    except subprocess.CalledProcessError:
        print("\nERROR: Job submission failed during SSH execution.")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--cluster-name", default="flink-analytics-cluster")
    parser.add_argument("--region", default="us-central1")
    parser.add_argument("--gcs-bucket", required=True)
    parser.add_argument("--kafka-brokers", required=True)
    args = parser.parse_args()
    
    submit_job(args.project_id, args.cluster_name, args.region, args.gcs_bucket, args.kafka_brokers)