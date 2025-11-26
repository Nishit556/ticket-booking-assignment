# Code Explanation Transcript - Cloud Computing Assignment
## Division Plan for 4 Group Members

---

## 📋 **DIVISION OVERVIEW**

The codebase has been divided into **4 equal parts** to ensure fair weightage for all group members:

| Part | Member | Focus Area | Files/Components |
|------|--------|-----------|------------------|
| **Part 1** | Member 1 | AWS Infrastructure (Terraform) | `infrastructure/aws/*.tf` |
| **Part 2** | Member 2 | Core Microservices (EKS) | `services/booking-service/`, `services/event-catalog/`, `services/user-service/`, `services/frontend/` |
| **Part 3** | Member 3 | Analytics, Serverless & GCP | `services/analytics-service/`, `services/ticket-generator/`, `infrastructure/gcp/` |
| **Part 4** | Member 4 | K8s Orchestration & Observability | `k8s-gitops/`, `argocd-app.yaml`, `load-testing/` |

---

# PART 1: AWS INFRASTRUCTURE AS CODE (TERRAFORM)
**Member: [ID Number]**

## Introduction
Hello, I am [Name], ID [ID Number]. I will be explaining **Part 1: AWS Infrastructure as Code** using Terraform. This part covers all the cloud infrastructure provisioning for AWS, which forms the foundation of our ticket booking system.

## Overview
Our infrastructure is defined using Terraform, which allows us to provision all AWS resources declaratively. This includes networking, compute, databases, messaging, storage, and serverless components.

## File Structure
Let me show you the files I'm responsible for:
- `infrastructure/aws/providers.tf` - Cloud provider configuration
- `infrastructure/aws/vpc.tf` - Network infrastructure
- `infrastructure/aws/eks.tf` - Kubernetes cluster
- `infrastructure/aws/kafka.tf` - Message queue (MSK)
- `infrastructure/aws/database.tf` - SQL and NoSQL databases
- `infrastructure/aws/storage.tf` - Object storage (S3)
- `infrastructure/aws/variables.tf` - Input variables
- `infrastructure/aws/outputs.tf` - Output values

## Detailed Explanation

### 1. Provider Configuration (`providers.tf`)
```hcl
terraform {
  required_providers {
    aws = {
      source  = "terraform-aws-modules/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```
**Explanation:** This file configures the AWS provider for Terraform. It specifies which cloud provider we're using and the region where resources will be created. The `required_providers` block ensures we use compatible versions.

### 2. VPC and Networking (`vpc.tf`)
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "ticket-booking-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}
```
**Explanation:** This creates a Virtual Private Cloud (VPC) with public and private subnets across two availability zones. The NAT gateway allows private subnets to access the internet for pulling container images, while keeping resources secure. This is a best practice for production deployments.

### 3. EKS Cluster (`eks.tf`)
```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 3
      desired_size = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  enable_irsa = true
}
```
**Explanation:** This provisions an Amazon EKS (Elastic Kubernetes Service) cluster. EKS is a managed Kubernetes service that hosts our microservices. The node group defines the worker nodes that run our containers. I've configured it to scale between 2-3 nodes. `enable_irsa` allows pods to use IAM roles for AWS service access, which is crucial for accessing S3 and DynamoDB.

### 4. Kafka/MSK Cluster (`kafka.tf`)
```hcl
resource "aws_msk_cluster" "kafka" {
  cluster_name           = "ticket-booking-kafka"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = module.vpc.private_subnets
    security_groups = [aws_security_group.kafka_sg.id]
  }
}
```
**Explanation:** This creates an Amazon MSK (Managed Streaming for Kafka) cluster. MSK is a fully managed Kafka service that handles message queuing between our booking service and analytics service. I've configured 2 broker nodes for high availability. The security group ensures only EKS pods can communicate with Kafka.

### 5. Databases (`database.tf`)
```hcl
# RDS PostgreSQL for Event Catalog
resource "aws_db_instance" "postgres" {
  identifier     = "ticket-booking-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  db_name  = "ticketdb"
  username = "dbadmin"
  password = var.db_password
  
  allocated_storage     = 20
  storage_encrypted     = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}

# DynamoDB for User Service
resource "aws_dynamodb_table" "users" {
  name     = "ticket-booking-users"
  hash_key = "userId"
  
  attribute {
    name = "userId"
    type = "S"
  }
  
  billing_mode = "PAY_PER_REQUEST"
}
```
**Explanation:** I've provisioned two databases: RDS PostgreSQL for structured event data (SQL) and DynamoDB for user profiles (NoSQL). RDS is in a private subnet with security groups restricting access. DynamoDB uses on-demand billing, which is cost-effective for variable workloads. This satisfies requirement (f) for multiple storage types.

### 6. Storage (`storage.tf`)
```hcl
resource "aws_s3_bucket" "raw_data" {
  bucket = "ticket-booking-raw-data-${random_id.bucket_suffix.hex}"

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.raw_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ticket_generator.arn
    events              = ["s3:ObjectCreated:*"]
  }
}
```
**Explanation:** This creates an S3 bucket for storing raw data (like ID proofs) that trigger our Lambda function. The bucket notification automatically invokes the Lambda when files are uploaded, implementing event-driven architecture. Versioning ensures we can recover previous versions if needed.

### 7. Lambda Function (`storage.tf` or separate file)
```hcl
resource "aws_lambda_function" "ticket_generator" {
  filename      = "lambda_function.zip"
  function_name = "ticket-generator"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  
  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.raw_data.id
    }
  }
}
```
**Explanation:** This provisions the serverless Lambda function that generates tickets asynchronously when files are uploaded to S3. This satisfies requirement (b) for a serverless function. The IAM role grants permissions to read from and write to S3.

## Key Design Decisions
1. **Private Subnets for EKS**: Security best practice - worker nodes don't need public IPs
2. **Multi-AZ Deployment**: High availability across availability zones
3. **Managed Services**: Using MSK and RDS reduces operational overhead
4. **IRSA (IAM Roles for Service Accounts)**: Secure way for pods to access AWS services

## Conclusion
This infrastructure provides a secure, scalable foundation for our microservices. All resources are provisioned declaratively, making it easy to reproduce and version control. The architecture supports the requirements for managed K8s, message queues, multiple storage types, and serverless functions.

---

# PART 2: CORE MICROSERVICES (EKS SERVICES)
**Member: [ID Number]**

## Introduction
Hello, I am [Name], ID [ID Number]. I will be explaining **Part 2: Core Microservices** that run on AWS EKS. These are the main application services that handle user interactions, event management, and booking operations.

## Overview
I'm responsible for four microservices:
1. **Frontend Service** - Web UI and API gateway
2. **Booking Service** - Handles ticket bookings and Kafka integration
3. **Event Catalog Service** - Manages event data with PostgreSQL
4. **User Service** - Manages user profiles with DynamoDB
G
## Service-by-Service Explanation

### 1. Frontend Service (`services/frontend/server.js`)

**Purpose:** Acts as a reverse proxy and web server, providing the public-facing interface.

**Key Features:**
```javascript
const BOOKING_SERVICE_URL = process.env.BOOKING_SERVICE_URL || 'http://booking-service:5000';
const EVENT_SERVICE_URL = process.env.EVENT_SERVICE_URL || 'http://event-catalog:5000';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:3000';
```
**Explanation:** The frontend uses Kubernetes internal DNS names to communicate with backend services. This is secure because these addresses only work inside the cluster.

**API Routes:**
- `/api/events` - Proxies to Event Catalog Service
- `/api/book` - Proxies booking requests to Booking Service
- `/api/users` - Handles user registration via User Service
- `/api/upload` - Uploads files to S3, triggering Lambda

**S3 Integration:**
```javascript
const command = new PutObjectCommand({
  Bucket: BUCKET_NAME,
  Key: key,
  Body: fileContent
});
await s3Client.send(command);
```
**Explanation:** When users upload ID proofs, the frontend uploads them to S3. This triggers the Lambda function asynchronously, demonstrating event-driven architecture.

**Prometheus Metrics:**
```javascript
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code']
});
```
**Explanation:** I've integrated Prometheus metrics to track request latency and status codes. This enables observability dashboards in Grafana.

### 2. Booking Service (`services/booking-service/app.py`)

**Purpose:** Handles ticket booking requests and publishes events to Kafka.

**Kafka Integration:**
```python
KAFKA_BROKERS = os.environ.get('KAFKA_BROKERS', 'localhost:9092')
TOPIC_NAME = 'ticket-bookings'

producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKERS,
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)
```
**Explanation:** The booking service uses Kafka producer to send booking events asynchronously. This decouples booking from processing, allowing the analytics service to consume events independently.

**Booking Endpoint:**
```python
@app.route('/book', methods=['POST'])
def book_ticket():
    booking_event = {
        "event_id": data['event_id'],
        "user_id": data['user_id'],
        "ticket_count": data.get('ticket_count', 1),
        "timestamp": time.time()
    }
    kp.send(TOPIC_NAME, booking_event)
    return jsonify({"message": "Booking request received!", "status": "queued"}), 202
```
**Explanation:** The service validates input, creates a booking event, and publishes it to Kafka. It returns HTTP 202 (Accepted) because processing is asynchronous. This satisfies requirement (b) for message queue communication.

**Prometheus Integration:**
```python
from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)
```
**Explanation:** Prometheus metrics are automatically exposed at `/metrics` endpoint, enabling monitoring of request rates and errors.

### 3. Event Catalog Service (`services/event-catalog/app.py`)

**Purpose:** Manages event information stored in PostgreSQL (RDS).

**Database Configuration:**
```python
db_host = os.environ.get('DB_HOST')
if db_host:
    app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{db_user}:{db_password}@{db_host}:5432/{db_name}"
else:
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///local_events.db'
```
**Explanation:** The service checks for `DB_HOST` environment variable. If present (production), it connects to AWS RDS PostgreSQL. Otherwise, it falls back to SQLite for local development. This makes the service portable.

**Data Model:**
```python
class Event(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    date = db.Column(db.String(50), nullable=False)
    venue = db.Column(db.String(100), nullable=False)
    tickets_available = db.Column(db.Integer, default=100)
```
**Explanation:** Using SQLAlchemy ORM, I've defined the Event model that maps to the PostgreSQL table. This provides type safety and easy database operations.

**API Endpoints:**
- `GET /events` - Lists all events
- `GET /events/<id>` - Gets specific event details

**Database Seeding:**
```python
if not Event.query.first():
    db.session.add(Event(name="Coldplay World Tour", ...))
    db.session.commit()
```
**Explanation:** On first run, the service seeds the database with sample events if the table is empty. This ensures the application has data to work with immediately.

### 4. User Service (`services/user-service/index.js`)

**Purpose:** Manages user profiles stored in DynamoDB (NoSQL).

**DynamoDB Integration:**
```javascript
const client = new DynamoDBClient({ region: REGION });
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = "ticket-booking-users";
```
**Explanation:** The service uses AWS SDK v3 to interact with DynamoDB. In EKS, credentials are automatically picked up from the node's IAM role (IRSA), so no explicit credentials are needed.

**Create User:**
```javascript
app.post('/users', async (req, res) => {
  const userId = uuidv4();
  const newUser = {
    userId: userId,
    name: name,
    email: email,
    createdAt: new Date().toISOString()
  };
  
  const command = new PutCommand({
    TableName: TABLE_NAME,
    Item: newUser
  });
  await docClient.send(command);
});
```
**Explanation:** Users are created with a UUID as the primary key. DynamoDB's on-demand billing means we don't need to provision capacity, making it cost-effective for variable workloads.

**Get User:**
```javascript
app.get('/users/:id', async (req, res) => {
  const command = new GetCommand({
    TableName: TABLE_NAME,
    Key: { userId: req.params.id }
  });
  const response = await docClient.send(command);
});
```
**Explanation:** DynamoDB GetItem operation is very fast (single-digit milliseconds) because it's a key-value lookup. This is ideal for user profile queries.

## Design Patterns Used

1. **API Gateway Pattern**: Frontend acts as a single entry point
2. **Microservices Architecture**: Each service has a single responsibility
3. **Event-Driven Communication**: Kafka for async messaging
4. **Service Discovery**: Kubernetes DNS for inter-service communication
5. **Observability**: Prometheus metrics in all services

## Docker Configuration

Each service includes a `Dockerfile`:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```
**Explanation:** Multi-stage builds aren't needed for simplicity, but each service is containerized independently, enabling independent deployment and scaling.

## Conclusion
These four microservices form the core of our application. They communicate via REST APIs and Kafka, use different storage backends (PostgreSQL and DynamoDB), and are designed to scale independently using Kubernetes HPAs.

---

# PART 3: ANALYTICS, SERVERLESS & GCP INFRASTRUCTURE
**Member: [ID Number]**

## Introduction
Hello, I am [Name], ID [ID Number]. I will be explaining **Part 3: Analytics Service, Serverless Function, and GCP Infrastructure**. This part covers the real-time stream processing service on GCP Dataproc and the AWS Lambda function.

## Overview
I'm responsible for:
1. **Analytics Service** - Apache Flink job running on GCP Dataproc
2. **Ticket Generator** - AWS Lambda function for asynchronous ticket generation
3. **GCP Infrastructure** - Terraform for Dataproc and GCS

## 1. Analytics Service - Flink Job (`services/analytics-service/analytics_job.py`)

**Purpose:** Performs real-time stream processing on booking events from Kafka, calculating aggregated metrics per time window.

**Flink Environment Setup:**
```python
env = StreamExecutionEnvironment.get_execution_environment()
env.set_parallelism(1)

settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
t_env = StreamTableEnvironment.create(env, environment_settings=settings)
```
**Explanation:** I'm using Flink's Table API, which provides SQL-like syntax for stream processing. This is easier to write and understand than the DataStream API. The parallelism is set to 1 for simplicity in the assignment.

**Kafka Source Table:**
```python
t_env.execute_sql("""
    CREATE TABLE bookings (
        event_id STRING,
        ticket_count INT,
        proc_time AS PROCTIME()
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'ticket-bookings',
        'properties.bootstrap.servers' = '{kafka_brokers}',
        'format' = 'json',
        'scan.startup.mode' = 'latest-offset'
    )
""")
```
**Explanation:** This defines a Flink table that reads from the Kafka topic `ticket-bookings`. The `PROCTIME()` function creates a processing time attribute, which is needed for time-windowed aggregations. The JSON format automatically deserializes messages.

**Kafka Sink Table:**
```python
t_env.execute_sql("""
    CREATE TABLE results (
        event_id STRING,
        window_end TIMESTAMP(3),
        total_tickets BIGINT
    ) WITH (
        'connector' = 'kafka',
        'topic' = 'analytics-results',
        'properties.bootstrap.servers' = '{kafka_brokers}',
        'format' = 'json'
    )
""")
```
**Explanation:** Results are written back to a different Kafka topic `analytics-results`. This allows other services to consume aggregated metrics. The schema includes the window end time and total tickets sold.

**Time-Windowed Aggregation:**
```python
t_env.execute_sql("""
    INSERT INTO results
    SELECT 
        event_id,
        TUMBLE_END(proc_time, INTERVAL '1' MINUTE) as window_end,
        SUM(ticket_count) as total_tickets
    FROM bookings
    GROUP BY 
        event_id,
        TUMBLE(proc_time, INTERVAL '1' MINUTE)
""")
```
**Explanation:** This is the core logic - a **tumbling window aggregation** over 1-minute intervals. For each event, it groups bookings by `event_id` and calculates the total tickets sold in each 1-minute window. This satisfies requirement (e) for stateful, time-windowed aggregation.

**Key Features:**
- **Stateful Processing**: Flink maintains state for window aggregations
- **Exactly-Once Semantics**: Flink ensures no duplicate processing
- **Low Latency**: Results are emitted as soon as each window closes

## 2. GCP Dataproc Infrastructure (`infrastructure/gcp/dataproc.tf`)

**Purpose:** Provisions the managed Flink cluster on GCP.

**Dataproc Cluster:**
```hcl
resource "google_dataproc_cluster" "flink_cluster" {
  name   = "ticket-booking-flink"
  region = var.gcp_region

  cluster_config {
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-2"
    }

    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-2"
    }

    software_config {
      image_version = "2.1-debian11"
      optional_components = ["FLINK"]
    }

    initialization_action {
      script = "gs://${google_storage_bucket.scripts.name}/install-dependencies.sh"
    }
  }
}
```
**Explanation:** This creates a Dataproc cluster with Flink pre-installed. The initialization script installs Python dependencies needed for the Flink job. Dataproc is GCP's managed Hadoop/Spark/Flink service, similar to AWS EMR.

**Why GCP for Analytics?**
- Requirement (b) specifies analytics service must run on a different cloud provider
- Dataproc provides managed Flink, reducing operational overhead
- Easy integration with GCS for job artifacts

**GCS Bucket for Scripts:**
```hcl
resource "google_storage_bucket" "scripts" {
  name     = "ticket-booking-scripts-${random_id.bucket_suffix.hex}"
  location = var.gcp_region
}
```
**Explanation:** Google Cloud Storage (GCS) stores the initialization script and Flink job JAR/Python files. This satisfies requirement (f) for using an object store.

## 3. Job Submission Script (`services/analytics-service/submit-dataproc-job.py`)

**Purpose:** Submits the Flink job to the Dataproc cluster.

**Key Code:**
```python
from google.cloud import dataproc_v1

job_client = dataproc_v1.JobControllerClient()

job = {
    "placement": {"cluster_name": cluster_name},
    "pyspark_job": {
        "main_python_file_uri": f"gs://{bucket_name}/analytics_job.py",
        "args": [f"--kafka-brokers={kafka_brokers}"]
    }
}

response = job_client.submit_job(project_id=project_id, region=region, job=job)
```
**Explanation:** The script uses GCP's Dataproc API to submit the Flink job. The job is configured to run the Python file from GCS and pass Kafka broker addresses as arguments.

## 4. Ticket Generator Lambda (`services/ticket-generator/lambda_function.py`)

**Purpose:** Serverless function that generates PDF tickets when files are uploaded to S3.

**Lambda Handler:**
```python
def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    # Download the uploaded file
    s3_client.download_file(bucket, key, '/tmp/input.txt')
    
    # Generate PDF ticket
    ticket_content = generate_ticket_pdf(key)
    
    # Upload to S3 tickets/ folder
    output_key = f"tickets/ticket_{timestamp}.pdf"
    s3_client.upload_file('/tmp/ticket.pdf', bucket, output_key)
```
**Explanation:** The Lambda is triggered automatically by S3 events. When a file is uploaded to the `uploads/` prefix, S3 invokes the Lambda. The function generates a PDF ticket and stores it in the `tickets/` prefix. This demonstrates **event-driven, asynchronous processing**.

**Key Features:**
- **Serverless**: No infrastructure to manage
- **Event-Driven**: Triggered by S3 uploads
- **Stateless**: Each invocation is independent
- **Cost-Effective**: Pay only for execution time

**IAM Permissions:**
The Lambda needs permissions to:
- Read from S3 bucket (input files)
- Write to S3 bucket (generated tickets)
- These are configured in Terraform via IAM roles

## 5. GCP Service Account & Networking (`infrastructure/gcp/network.tf`)

**Purpose:** Configures network access for Dataproc to reach AWS MSK.

**VPC Configuration:**
```hcl
resource "google_compute_network" "dataproc_vpc" {
  name = "dataproc-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "dataproc_subnet" {
  name          = "dataproc-subnet"
  network       = google_compute_network.dataproc_vpc.id
  ip_cidr_range = "10.1.0.0/24"
  region        = var.gcp_region
}
```
**Explanation:** Creates a VPC for Dataproc. For cross-cloud access to AWS MSK, we configure security groups to allow traffic from GCP (for demo purposes, we use public endpoints with proper security).

## Design Decisions

1. **Flink on Dataproc**: Managed service reduces operational complexity
2. **Python Flink Job**: Easier to write and debug than Java
3. **Lambda for Tickets**: Serverless is perfect for sporadic, event-driven tasks
4. **Cross-Cloud Architecture**: Demonstrates multi-cloud capabilities

## Integration Points

- **Analytics Service** consumes from AWS MSK (Kafka)
- **Lambda** triggered by S3 events (AWS)
- **Results** published back to Kafka for consumption by other services

## Conclusion
This part demonstrates real-time stream processing, serverless computing, and multi-cloud architecture. The Flink job performs stateful aggregations as required, and the Lambda function showcases event-driven serverless architecture.

---

# PART 4: KUBERNETES ORCHESTRATION, GITOPS & OBSERVABILITY
**Member: [ID Number]**

## Introduction
Hello, I am [Name], ID [ID Number]. I will be explaining **Part 4: Kubernetes Orchestration, GitOps Configuration, and Observability Stack**. This part covers how services are deployed, how GitOps manages updates, and how we monitor and log the entire system.

## Overview
I'm responsible for:
1. **Kubernetes Manifests** - Deployment, Service, HPA configurations
2. **GitOps (ArgoCD)** - Automated deployment management
3. **Monitoring Stack** - Prometheus and Grafana
4. **Logging Stack** - Loki and Promtail
5. **Load Testing** - k6 scripts for HPA validation

## 1. Kubernetes Application Manifests (`k8s-gitops/apps/`)

### Booking Service Deployment (`booking-service.yaml`)

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: booking-service
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: booking-service
        image: YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ticket-booking/booking-service:latest
        env:
        - name: KAFKA_BROKERS
          value: "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092"
        resources:
          limits:
            cpu: "200m"
          requests:
            cpu: "50m"
```
**Explanation:** This defines how the booking service runs in Kubernetes. I've set initial replicas to 2 for high availability. The CPU limits and requests are crucial for HPA - HPA uses these to calculate utilization. The image is pulled from AWS ECR (Elastic Container Registry).

**Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: booking-service
spec:
  selector:
    app: booking-service
  ports:
  - port: 5000
    targetPort: 5000
```
**Explanation:** The Service creates a stable DNS name `booking-service` that other pods can use to communicate. Kubernetes load-balances traffic across all pods with the `app: booking-service` label.

**Horizontal Pod Autoscaler (HPA):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: booking-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: booking-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 20
```
**Explanation:** This HPA automatically scales the booking service based on CPU utilization. When average CPU exceeds 20%, it adds pods (up to 10). When CPU drops, it removes pods (down to 2). This satisfies requirement (c) for HPA on critical services.

**Why 20% threshold?** Lower threshold means more aggressive scaling, ensuring we handle traffic spikes quickly. This is important for a booking service that might experience sudden load.

### User Service HPA (`user-service.yaml`)

Similar HPA configuration:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-hpa
spec:
  scaleTargetRef:
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 20
```
**Explanation:** User service also has HPA, satisfying the requirement for "at least two critical services" with HPAs.

## 2. GitOps Configuration (`argocd-app.yaml`)

**Purpose:** ArgoCD automatically syncs Kubernetes manifests from Git repository.

**Application Definition:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ticket-booking-app
spec:
  project: default
  source:
    repoURL: https://github.com/Nishit556/ticket-booking-assignment.git
    targetRevision: main
    path: k8s-gitops/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
**Explanation:** This tells ArgoCD to:
- Watch the Git repository
- Monitor the `k8s-gitops/apps` directory
- Automatically apply any changes (automated sync)
- Remove resources deleted from Git (prune)
- Fix manual changes (selfHeal)

**Why GitOps?**
- **Version Control**: All changes are tracked in Git
- **Reproducibility**: Same Git state = same cluster state
- **Compliance**: Requirement (d) mandates GitOps, no direct kubectl apply
- **Collaboration**: Multiple team members can review changes via PRs

## 3. Monitoring Stack (`k8s-gitops/system/monitoring.yaml`)

**Prometheus & Grafana:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
spec:
  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    helm:
      parameters:
      - name: grafana.service.type
        value: LoadBalancer
```
**Explanation:** I'm using the `kube-prometheus-stack` Helm chart, which includes:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards
- **ServiceMonitors**: Auto-discovery of services with `/metrics` endpoints

**Grafana LoadBalancer:** Exposes Grafana via a public URL, allowing access to dashboards from outside the cluster.

**ServiceMonitor Configuration (`servicemonitors.yaml`):**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: booking-service-monitor
spec:
  selector:
    matchLabels:
      app: booking-service
  endpoints:
  - port: http
    path: /metrics
```
**Explanation:** ServiceMonitors tell Prometheus which services to scrape. Prometheus automatically discovers all services with matching labels and scrapes their `/metrics` endpoints every 15 seconds.

**Metrics Collected:**
- Request rate (RPS)
- Error rate
- Latency (p50, p95, p99)
- CPU/Memory utilization
- Pod count (for HPA visibility)

## 4. Logging Stack (`k8s-gitops/system/logging.yaml`)

**Loki & Promtail:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
spec:
  template:
    spec:
      containers:
      - name: promtail
        image: grafana/promtail:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
```
**Explanation:** Promtail runs as a DaemonSet (one pod per node) and collects logs from all containers. It sends logs to Loki, which stores them efficiently.

**Loki Configuration:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
data:
  loki.yaml: |
    auth_enabled: false
    server:
      http_listen_port: 3100
    schema_config:
      configs:
      - from: 2024-01-01
        store: boltdb
        object_store: filesystem
        schema: v11
        index:
          prefix: index_
          period: 168h
```
**Explanation:** Loki is configured for single-binary mode (simple setup). It uses filesystem storage, which is sufficient for the assignment. In production, you'd use object storage like S3.

**Log Aggregation Benefits:**
- Centralized logs from all microservices
- Searchable via Grafana
- Correlates with metrics for troubleshooting
- Satisfies requirement (g.3) for centralized logging

## 5. Load Testing (`load-testing/k6-load-test.js`)

**Purpose:** Validates HPA scaling under load.

**k6 Script:**
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up to 10 users
    { duration: '1m', target: 50 },     // Ramp up to 50 users
    { duration: '2m', target: 150 },   // Peak load: 150 users
    { duration: '1m', target: 50 },    // Ramp down
    { duration: '30s', target: 0 },     // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests < 500ms
    http_req_failed: ['rate<0.1'],     // Error rate < 10%
  },
};

export default function () {
  const response = http.post('http://frontend-service/api/book', JSON.stringify({
    user_id: 'test-user',
    event_id: 1,
    ticket_count: 1
  }), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  check(response, {
    'status is 202': (r) => r.status === 202,
  });
  
  sleep(1);
}
```
**Explanation:** This k6 script:
- Gradually increases load from 10 to 150 virtual users
- Sends booking requests to the frontend
- Validates response times and error rates
- Demonstrates HPA scaling as CPU increases

**Running the Test:**
```powershell
k6 run k6-load-test.js
```

**Expected Results:**
- HPA scales booking-service from 2 → 8-10 pods
- System maintains <500ms latency
- Error rate stays below 10%
- This satisfies requirement (h) for load testing and HPA validation

## 6. Service Health & Status Endpoints

All services expose `/health` endpoints:
```python
@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200
```
**Explanation:** Health endpoints enable Kubernetes liveness and readiness probes. If a service becomes unhealthy, Kubernetes restarts the pod or removes it from the load balancer.

## Design Patterns

1. **GitOps**: Infrastructure as Code for Kubernetes
2. **Observability**: Metrics, logs, and traces (3 pillars)
3. **Auto-Scaling**: HPA based on resource utilization
4. **Service Discovery**: Kubernetes DNS for inter-service communication
5. **Centralized Logging**: All logs in one place for correlation

## Key Configuration Files

- `k8s-gitops/apps/*.yaml` - Application deployments
- `k8s-gitops/system/monitoring.yaml` - Prometheus/Grafana
- `k8s-gitops/system/logging.yaml` - Loki/Promtail
- `k8s-gitops/system/servicemonitors.yaml` - Metrics discovery
- `argocd-app.yaml` - GitOps application definition

## Conclusion
This part ensures the system is:
- **Automatically Deployed**: GitOps manages all changes
- **Observable**: Metrics and logs provide full visibility
- **Scalable**: HPA responds to load automatically
- **Tested**: Load tests validate resilience

The observability stack provides dashboards showing RPS, error rates, latency, and cluster health, satisfying requirement (g). The GitOps setup ensures all deployments are version-controlled and automated, satisfying requirement (d).

---

# SUMMARY & COORDINATION

## How Parts Work Together

1. **Part 1 (Infrastructure)** provisions the cloud resources
2. **Part 2 (Microservices)** implements the business logic
3. **Part 3 (Analytics & Serverless)** adds real-time processing and event-driven functions
4. **Part 4 (Orchestration)** deploys and monitors everything

## Recording Guidelines

Each member should:
1. **Show ID in terminal/code** - Display student ID clearly
2. **Explain your code sections** - Walk through key files and logic
3. **Demonstrate understanding** - Explain design decisions and trade-offs
4. **Keep video focused** - 10-15 minutes per part
5. **Save link** - Put video URL in `<idno>_video.txt`

## Common Integration Points

- **Kafka**: Connects Part 2 (Booking) → Part 3 (Analytics)
- **S3**: Connects Part 2 (Frontend) → Part 3 (Lambda)
- **Kubernetes**: Part 4 deploys Part 2 services
- **Monitoring**: Part 4 observes Part 2 & 3 services
- **Databases**: Part 1 provisions, Part 2 services use them

---

**End of Transcript**

