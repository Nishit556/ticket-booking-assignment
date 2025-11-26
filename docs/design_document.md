# Cloud Computing Assignment - Design Document
**Course:** CS/SS G527 - Cloud Computing  
**Assignment:** Multi-Cloud Microservices Application  
**Domain:** Event Ticketing System

---

## Table of Contents
1. [System Overview](#1-system-overview)
2. [Cloud Deployment Architecture](#2-cloud-deployment-architecture)
3. [Microservices Architecture](#3-microservices-architecture)
4. [Microservice Responsibilities](#4-microservice-responsibilities)
5. [Interconnection Mechanisms](#5-interconnection-mechanisms)
6. [Rationale Behind Design Choices](#6-rationale-behind-design-choices)
7. [Infrastructure as Code](#7-infrastructure-as-code)
8. [Observability Stack](#8-observability-stack)
9. [Load Testing Strategy](#9-load-testing-strategy)

---

## 1. System Overview

### 1.1 Application Domain
Our application is a **Ticket Booking System** in the **Entertainment/Event Management** domain. The system enables users to:
- Browse available events (concerts, shows, sports events)
- Register user profiles
- Book tickets for events
- Generate and download ticket receipts
- View real-time booking analytics

### 1.2 High-Level Architecture
The system is built as a **cloud-native microservices architecture** deployed across **two cloud providers**:
- **Primary Cloud Provider (Provider A):** AWS (Amazon Web Services)
- **Secondary Cloud Provider (Provider B):** GCP (Google Cloud Platform)

### 1.3 Key Characteristics
- **6 Microservices** serving distinct functional purposes
- **Multi-cloud deployment** with analytics service on GCP
- **Event-driven architecture** using Kafka for asynchronous communication
- **Serverless components** for cost-effective bursty workloads
- **Fully automated infrastructure** via Terraform
- **GitOps-based deployment** using ArgoCD
- **Comprehensive observability** with Prometheus, Grafana, and Loki
- **Auto-scaling** via Horizontal Pod Autoscalers (HPA)

### 1.4 Public Access
The application is accessible via a **public LoadBalancer URL** provided by AWS EKS:
- **Frontend Service:** Exposed via AWS LoadBalancer (Type: LoadBalancer)
- **Grafana Dashboard:** Exposed via AWS LoadBalancer for monitoring visualization

---

## 2. Cloud Deployment Architecture

### 2.1 Multi-Cloud Strategy

#### Provider A: AWS (Primary Infrastructure)
**Services Deployed:**
- **EKS Cluster:** Managed Kubernetes service hosting stateless microservices
- **MSK (Managed Kafka):** Event streaming platform for asynchronous communication
- **RDS PostgreSQL:** Managed SQL database for structured event data
- **DynamoDB:** Managed NoSQL database for high-throughput user data
- **S3:** Object storage for raw data (ID proofs, ticket files)
- **Lambda:** Serverless function for ticket generation
- **ECR:** Container registry for Docker images
- **VPC:** Isolated network with public/private subnets

**Network Architecture:**
```
AWS VPC (us-east-1)
├── Public Subnets (for LoadBalancers)
├── Private Subnets (for EKS nodes)
├── Database Subnets (for RDS)
└── Security Groups:
    ├── EKS Node Security Group
    ├── RDS Security Group (allows EKS → RDS)
    └── Kafka Security Group (allows EKS → MSK)
```

#### Provider B: GCP (Analytics Infrastructure)
**Services Deployed:**
- **Dataproc Cluster:** Managed Apache Flink cluster for stream processing
- **GCS (Google Cloud Storage):** Storage for Flink job artifacts
- **VPC Network:** Isolated network for Dataproc cluster
- **Service Accounts:** IAM for secure access

**Network Architecture:**
```
GCP VPC Network
├── Dataproc Subnet (for Flink cluster)
├── Firewall Rules:
│   ├── Allow internal communication
│   ├── Allow SSH access
│   └── Allow Flink UI access
└── Service Account with required permissions
```

### 2.2 Infrastructure Components

#### 2.2.1 Container Orchestration (AWS EKS)
- **Cluster Name:** `ticket-booking-cluster`
- **Kubernetes Version:** 1.30
- **Node Group Configuration:**
  - Instance Type: `t3.medium`
  - Min Nodes: 2
  - Max Nodes: 3
  - Desired Nodes: 2
  - Capacity Type: ON_DEMAND
- **IAM Roles for Service Accounts (IRSA):** Enabled for secure AWS service access

#### 2.2.2 Messaging Infrastructure (AWS MSK)
- **Cluster Name:** `ticket-booking-kafka`
- **Kafka Version:** 3.5.1
- **Broker Nodes:** 2 (for high availability)
- **Instance Type:** `kafka.t3.small`
- **Topics:**
  - `ticket-bookings` (source topic for booking events)
  - `analytics-results` (sink topic for aggregated results)
- **Security:** PLAINTEXT (simplified for assignment, production would use TLS)

#### 2.2.3 Storage Infrastructure

**AWS S3:**
- **Bucket:** `ticket-booking-raw-data-{random-hex}`
- **Purpose:** 
  - Store uploaded ID proof files
  - Store generated ticket receipts
  - Trigger Lambda function on file upload
- **Lifecycle:** Files in `tickets/` folder are generated tickets

**GCP GCS:**
- **Bucket:** For Flink job artifacts and initialization scripts
- **Purpose:** Store Python dependencies and Flink job files

#### 2.2.4 Database Infrastructure

**AWS RDS PostgreSQL:**
- **Instance Class:** `db.t3.micro`
- **Engine:** PostgreSQL 16.3
- **Database Name:** `ticketdb`
- **Storage:** 20 GB allocated
- **Network:** Private subnet, accessible only from EKS nodes
- **Purpose:** Store structured event catalog data

**AWS DynamoDB:**
- **Table Name:** `ticket-booking-users`
- **Billing Mode:** PAY_PER_REQUEST (serverless)
- **Primary Key:** `userId` (String)
- **Purpose:** Store user profiles with high throughput and low latency

#### 2.2.5 Serverless Function (AWS Lambda)
- **Function Name:** `ticket-generator-func`
- **Runtime:** Python 3.9
- **Trigger:** S3 ObjectCreated events
- **Purpose:** Asynchronously process uploaded files and generate ticket receipts
- **IAM Permissions:** S3 read/write, CloudWatch Logs

#### 2.2.6 Stream Processing (GCP Dataproc)
- **Cluster Name:** Configurable via Terraform variables
- **Image Version:** 2.1-debian11
- **Components:** Apache Flink (optional component)
- **Master Node:** 1 instance
- **Worker Nodes:** Configurable (default: 2)
- **Machine Type:** Configurable (default: n1-standard-2)
- **Purpose:** Run Flink job for real-time analytics

---

## 3. Microservices Architecture

### 3.1 Architecture Diagram (Textual Representation)

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                           │
│                    (Browser / Mobile App)                        │
└────────────────────────────┬────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FRONTEND SERVICE (AWS EKS)                    │
│  - Node.js/Express                                              │
│  - LoadBalancer (Public URL)                                    │
│  - Routes requests to backend services                           │
└──────┬──────────────┬──────────────┬──────────────┬─────────────┘
       │              │              │              │
       │ REST         │ REST         │ REST         │ REST
       ▼              ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   USER      │ │  BOOKING    │ │   EVENT    │ │   TICKET   │
│  SERVICE    │ │   SERVICE   │ │  CATALOG   │ │  GENERATOR │
│ (AWS EKS)   │ │  (AWS EKS)  │ │  (AWS EKS) │ │  (Lambda)  │
│             │ │             │ │            │ │            │
│ DynamoDB    │ │   Kafka     │ │   RDS      │ │    S3      │
│ (NoSQL)     │ │  Producer   │ │ (PostgreSQL)│ │  Trigger   │
└─────────────┘ └──────┬──────┘ └─────────────┘ └─────────────┘
                       │
                       │ Kafka Topic: ticket-bookings
                       ▼
              ┌─────────────────┐
              │   AWS MSK       │
              │  (Kafka Cluster)│
              └────────┬────────┘
                       │
                       │ Consumes from Kafka
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│          ANALYTICS SERVICE (GCP Dataproc)                       │
│  - Apache Flink                                                 │
│  - Stateful time-windowed aggregation                          │
│  - 1-minute tumbling windows                                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ Publishes to Kafka
                       ▼
              ┌─────────────────┐
              │   AWS MSK       │
              │  Topic: analytics-results │
              └─────────────────┘
```

### 3.2 Service Communication Flow

1. **User Registration Flow:**
   - Frontend → User Service (REST) → DynamoDB

2. **Event Browsing Flow:**
   - Frontend → Event Catalog Service (REST) → RDS PostgreSQL

3. **Ticket Booking Flow:**
   - Frontend → Booking Service (REST)
   - Booking Service → Kafka Topic `ticket-bookings` (async)
   - Analytics Service (Flink) consumes from Kafka
   - Analytics Service aggregates data in 1-minute windows
   - Analytics Service publishes results to `analytics-results` topic

4. **Ticket Generation Flow:**
   - Frontend uploads file to S3
   - S3 triggers Lambda function
   - Lambda processes file and generates ticket
   - Lambda uploads ticket to S3 `tickets/` folder

### 3.3 Data Flow Architecture

**Synchronous Communication (REST):**
- Frontend ↔ User Service
- Frontend ↔ Event Catalog Service
- Frontend ↔ Booking Service

**Asynchronous Communication (Kafka):**
- Booking Service → Kafka → Analytics Service
- Analytics Service → Kafka (results topic)

**Event-Driven (S3 + Lambda):**
- S3 ObjectCreated → Lambda Function → S3 ObjectCreated (ticket)

---

## 4. Microservice Responsibilities

### 4.1 Frontend Service
**Location:** AWS EKS  
**Technology:** Node.js, Express.js  
**Container Image:** `ticket-booking/frontend:latest`  
**Port:** 3000 (internal), 80 (LoadBalancer)

**Responsibilities:**
- Serve static web UI (HTML, CSS, JavaScript)
- Act as API gateway, routing requests to backend services
- Handle file uploads to S3 for ticket generation
- Display service health status
- Aggregate data from multiple backend services for UI

**Key Endpoints:**
- `GET /` - Serve main UI
- `GET /api/health` - Health check aggregator
- `POST /api/users/register` - Proxy to User Service
- `GET /api/events` - Proxy to Event Catalog Service
- `POST /api/bookings/book` - Proxy to Booking Service

**Dependencies:**
- User Service (REST)
- Event Catalog Service (REST)
- Booking Service (REST)
- AWS S3 (for file uploads)

---

### 4.2 User Service
**Location:** AWS EKS  
**Technology:** Node.js, Express.js  
**Container Image:** `ticket-booking/user-service:latest`  
**Port:** 3000  
**HPA:** Enabled (CPU-based, 2-10 replicas)

**Responsibilities:**
- Manage user registration and profiles
- Store user data in DynamoDB (NoSQL)
- Provide user lookup by ID
- Expose Prometheus metrics for monitoring

**Key Endpoints:**
- `POST /users` - Create new user
- `GET /users/:id` - Get user by ID
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

**Database:**
- **DynamoDB Table:** `ticket-booking-users`
- **Schema:**
  - `userId` (String, Primary Key)
  - `name` (String)
  - `email` (String)
  - `createdAt` (String, ISO timestamp)

**Rationale for NoSQL:**
- High-throughput user lookups
- Simple key-value access pattern
- Low latency requirements
- Scalable without complex joins

---

### 4.3 Event Catalog Service
**Location:** AWS EKS  
**Technology:** Python, Flask, SQLAlchemy  
**Container Image:** `ticket-booking/event-catalog:latest`  
**Port:** 5000  
**Replicas:** 2 (for availability)

**Responsibilities:**
- Manage event catalog (concerts, shows, sports events)
- Store structured event data in PostgreSQL
- Provide event listing and details
- Seed initial event data on first deployment

**Key Endpoints:**
- `GET /events` - List all events
- `GET /events/:id` - Get event by ID
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

**Database:**
- **RDS PostgreSQL:** `ticketdb`
- **Table:** `event`
- **Schema:**
  - `id` (Integer, Primary Key)
  - `name` (String)
  - `date` (String)
  - `venue` (String)
  - `tickets_available` (Integer)

**Rationale for SQL:**
- Structured relational data
- ACID compliance for event inventory
- Complex queries (filtering, sorting)
- Data integrity requirements

---

### 4.4 Booking Service
**Location:** AWS EKS  
**Technology:** Python, Flask, Kafka-Python  
**Container Image:** `ticket-booking/booking-service:latest`  
**Port:** 5000  
**HPA:** Enabled (CPU-based, 2-10 replicas)

**Responsibilities:**
- Accept ticket booking requests
- Validate booking data (user_id, event_id, ticket_count)
- Publish booking events to Kafka topic `ticket-bookings`
- Return asynchronous acknowledgment to client
- Expose Prometheus metrics

**Key Endpoints:**
- `POST /book` - Create booking request
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

**Message Format (Kafka):**
```json
{
  "event_id": "string",
  "user_id": "string",
  "ticket_count": integer,
  "timestamp": float
}
```

**Rationale for Async Processing:**
- Decouple booking acceptance from processing
- Handle traffic spikes gracefully
- Enable downstream analytics processing
- Improve system resilience

---

### 4.5 Ticket Generator (Serverless Function)
**Location:** AWS Lambda  
**Technology:** Python 3.9  
**Function Name:** `ticket-generator-func`  
**Trigger:** S3 ObjectCreated events

**Responsibilities:**
- Process uploaded ID proof files from S3
- Validate file size (max 5MB)
- Generate ticket receipt as text file
- Upload ticket to S3 `tickets/` folder
- Log processing results to CloudWatch

**Event Source:**
- **S3 Bucket:** `ticket-booking-raw-data-{hex}`
- **Trigger:** `s3:ObjectCreated:*`
- **Filter:** Excludes `tickets/` folder to prevent infinite loops

**Output:**
- **Location:** `s3://bucket/tickets/{original_filename}_TICKET.txt`
- **Content:** Ticket receipt with verification status

**Rationale for Serverless:**
- Bursty, event-driven workload
- Cost-effective (pay per invocation)
- No need for always-on infrastructure
- Automatic scaling

---

### 4.6 Analytics Service (Stream Processing)
**Location:** GCP Dataproc  
**Technology:** Apache Flink, Python (PyFlink)  
**Job Type:** Flink Streaming Job

**Responsibilities:**
- Consume booking events from Kafka topic `ticket-bookings`
- Perform stateful, time-windowed aggregation
- Calculate ticket counts per event in 1-minute windows
- Publish aggregated results to Kafka topic `analytics-results`
- Run continuously for real-time analytics

**Processing Logic:**
- **Window Type:** Tumbling Window (1 minute)
- **Aggregation:** SUM of `ticket_count` grouped by `event_id`
- **State Management:** Flink manages state internally
- **Output Format:**
  ```json
  {
    "event_id": "string",
    "window_end": "timestamp",
    "total_tickets": bigint
  }
  ```

**Kafka Configuration:**
- **Source Topic:** `ticket-bookings`
- **Sink Topic:** `analytics-results`
- **Consumer Group:** `flink-analytics-group`
- **Startup Mode:** `latest-offset` (process new events only)

**Rationale for GCP Dataproc:**
- Assignment requirement: Analytics on different cloud provider
- Managed Flink cluster reduces operational overhead
- Easy integration with GCP services
- Cost-effective for batch and streaming workloads

---

## 5. Interconnection Mechanisms

### 5.1 Synchronous Communication (REST)

**Protocol:** HTTP/HTTPS  
**Format:** JSON  
**Used By:**
- Frontend ↔ User Service
- Frontend ↔ Event Catalog Service
- Frontend ↔ Booking Service

**Characteristics:**
- Request-response pattern
- Low latency for user-facing operations
- Direct service-to-service calls within EKS cluster
- Service discovery via Kubernetes DNS

**Example:**
```http
POST /api/users/register HTTP/1.1
Host: frontend-service
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com"
}
```

---

### 5.2 Asynchronous Communication (Kafka)

**Protocol:** Kafka Protocol (TCP)  
**Format:** JSON messages  
**Broker:** AWS MSK (Managed Kafka Service)

**Topics:**
1. **`ticket-bookings`** (Source)
   - **Producer:** Booking Service
   - **Consumer:** Analytics Service (Flink)
   - **Purpose:** Stream booking events for real-time processing

2. **`analytics-results`** (Sink)
   - **Producer:** Analytics Service (Flink)
   - **Consumer:** (Future: Dashboard service or frontend polling)
   - **Purpose:** Publish aggregated analytics results

**Message Flow:**
```
Booking Service → Kafka (ticket-bookings) → Flink Job → Kafka (analytics-results)
```

**Characteristics:**
- Decoupled producer and consumer
- High throughput for event streaming
- Durability and replay capability
- Scalable consumer groups

**Configuration:**
- **Brokers:** 2 nodes for high availability
- **Replication:** Managed by MSK
- **Partitions:** Auto-created (default)
- **Serialization:** JSON (UTF-8)

---

### 5.3 Event-Driven Communication (S3 + Lambda)

**Trigger:** S3 ObjectCreated event  
**Function:** AWS Lambda  
**Pattern:** Event-driven serverless processing

**Flow:**
1. Frontend uploads file to S3 bucket
2. S3 generates `ObjectCreated` event
3. S3 invokes Lambda function asynchronously
4. Lambda processes file and generates ticket
5. Lambda uploads ticket to S3 `tickets/` folder

**Configuration:**
- **Event Types:** `s3:ObjectCreated:*`
- **Filter:** Excludes `tickets/` prefix
- **Timeout:** 10 seconds
- **Memory:** Default (128 MB)

**Characteristics:**
- Fully managed event routing
- Automatic retries on failure
- No infrastructure to manage
- Pay-per-invocation pricing

---

### 5.4 Database Connections

**RDS PostgreSQL:**
- **Protocol:** PostgreSQL wire protocol (TCP 5432)
- **Connection:** From EKS pods to RDS endpoint
- **Security:** VPC security groups (EKS → RDS only)
- **Connection Pooling:** SQLAlchemy default pool

**DynamoDB:**
- **Protocol:** AWS SDK (HTTPS)
- **Authentication:** IAM roles (IRSA)
- **Region:** us-east-1
- **Endpoint:** Regional DynamoDB endpoint

---

### 5.5 Cross-Cloud Communication

**GCP Dataproc → AWS MSK:**
- **Method:** Kafka client library (PyFlink Kafka connector)
- **Network:** Internet (public Kafka bootstrap servers)
- **Security:** MSK security groups allow Dataproc IPs
- **Configuration:** Kafka brokers configured via environment variables

**Challenges Addressed:**
- Network connectivity between clouds
- Security group configuration
- Kafka broker accessibility
- Latency considerations

---

## 6. Rationale Behind Design Choices

### 6.1 Multi-Cloud Strategy

**Why AWS for Primary Infrastructure?**
- **EKS:** Mature managed Kubernetes service with excellent integration
- **MSK:** Fully managed Kafka eliminates operational complexity
- **RDS/DynamoDB:** Proven managed database services
- **Lambda:** Industry-leading serverless platform
- **S3:** Reliable, scalable object storage
- **ECR:** Integrated container registry

**Why GCP for Analytics?**
- **Assignment Requirement:** Analytics service must run on different cloud provider
- **Dataproc:** Excellent managed Flink/Hadoop service
- **Cost Efficiency:** Pay-per-use model for batch/streaming jobs
- **Integration:** Easy setup with GCS and service accounts

**Benefits:**
- Vendor diversity reduces lock-in risk
- Leverage best-of-breed services from each provider
- Demonstrate multi-cloud architecture competency

---

### 6.2 Microservices Architecture

**Why Microservices?**
- **Scalability:** Independent scaling of services based on load
- **Technology Diversity:** Use best tool for each service (Python, Node.js)
- **Fault Isolation:** Failure in one service doesn't cascade
- **Team Autonomy:** Different teams can own different services
- **Deployment Flexibility:** Deploy services independently

**Trade-offs:**
- Increased operational complexity
- Network latency between services
- Distributed system challenges (eventual consistency)

---

### 6.3 Container Orchestration: Kubernetes (EKS)

**Why Kubernetes?**
- **Industry Standard:** Widely adopted container orchestration
- **Portability:** Can run on any cloud provider
- **Auto-scaling:** Built-in HPA and cluster autoscaler
- **Service Discovery:** DNS-based service discovery
- **Resource Management:** CPU/memory limits and requests

**Why Managed Service (EKS)?**
- **Reduced Operational Overhead:** AWS manages control plane
- **High Availability:** Multi-AZ control plane
- **Security:** Integrated with AWS IAM and VPC
- **Updates:** Automated Kubernetes version updates

---

### 6.4 Messaging: Kafka (MSK)

**Why Kafka?**
- **High Throughput:** Handle millions of events per second
- **Durability:** Persistent message storage
- **Replay Capability:** Replay events for reprocessing
- **Scalability:** Horizontal scaling via partitions
- **Event Sourcing:** Natural fit for event-driven architecture

**Why Managed Service (MSK)?**
- **Operational Simplicity:** No Zookeeper management
- **High Availability:** Multi-AZ deployment
- **Automatic Updates:** Managed Kafka version updates
- **Monitoring:** CloudWatch integration

**Alternative Considered:** AWS SQS
- **Rejected Because:** SQS doesn't support multiple consumers, replay, or complex event processing patterns

---

### 6.5 Database Choices

**PostgreSQL (RDS) for Event Catalog:**
- **Rationale:**
  - Structured relational data (events, venues, dates)
  - ACID compliance for inventory management
  - Complex queries (filtering, sorting, joins)
  - Data integrity requirements
  - SQL familiarity for team

**DynamoDB for User Service:**
- **Rationale:**
  - Simple key-value access pattern (user lookup by ID)
  - High throughput requirements (many concurrent users)
  - Low latency (single-digit millisecond reads)
  - Serverless model (pay-per-request)
  - No need for complex queries or joins

**Alternative Considered:** Single PostgreSQL database
- **Rejected Because:** Different access patterns require different optimizations

---

### 6.6 Serverless Function: Lambda

**Why Lambda for Ticket Generation?**
- **Event-Driven:** Perfect fit for S3-triggered processing
- **Cost Efficiency:** Pay only when files are uploaded
- **Automatic Scaling:** Handles traffic spikes without configuration
- **No Infrastructure:** No servers to manage or patch
- **Fast Deployment:** Simple code deployment process

**Alternative Considered:** Containerized service in EKS
- **Rejected Because:** Would require always-on infrastructure for occasional workload

---

### 6.7 Stream Processing: Apache Flink

**Why Flink?**
- **Assignment Requirement:** Real-time stream processing with stateful, time-windowed aggregation
- **Stateful Processing:** Maintains state for window aggregations
- **Low Latency:** Sub-second processing latency
- **Exactly-Once Semantics:** Guaranteed processing semantics
- **Rich Window Functions:** Built-in support for tumbling, sliding, session windows

**Why GCP Dataproc?**
- **Managed Service:** No cluster management overhead
- **Flink Integration:** Optional component in Dataproc
- **Cost Effective:** Pay only for cluster runtime
- **Easy Scaling:** Add/remove worker nodes as needed

**Alternative Considered:** AWS Kinesis Analytics
- **Rejected Because:** Assignment requires Flink on managed cluster (Dataproc/EMR)

---

### 6.8 GitOps: ArgoCD

**Why GitOps?**
- **Assignment Requirement:** All deployments via GitOps controller
- **Declarative:** Infrastructure as code in Git repository
- **Auditability:** All changes tracked in Git history
- **Rollback:** Easy rollback via Git revert
- **Automation:** Automatic sync when Git changes

**Why ArgoCD?**
- **Kubernetes Native:** Built for Kubernetes
- **Multi-Source:** Supports Helm charts and plain YAML
- **UI:** User-friendly web interface
- **RBAC:** Role-based access control
- **Sync Policies:** Automated or manual sync options

**Alternative Considered:** Flux
- **Rejected Because:** ArgoCD provides better UI and easier setup

---

### 6.9 Observability Stack

**Why Prometheus?**
- **Industry Standard:** De facto standard for Kubernetes metrics
- **Pull Model:** Scrapes metrics from services
- **Rich Query Language:** PromQL for complex queries
- **Service Discovery:** Automatic discovery of Kubernetes services

**Why Grafana?**
- **Visualization:** Rich dashboards for metrics
- **Alerting:** Built-in alerting rules
- **Data Source Integration:** Supports Prometheus and Loki
- **User-Friendly:** Intuitive UI for non-technical users

**Why Loki?**
- **Log Aggregation:** Centralized logging solution
- **Prometheus-Compatible:** Similar query language (LogQL)
- **Cost Effective:** Indexes metadata, not full logs
- **Kubernetes Integration:** Promtail automatically collects pod logs

**Alternative Considered:** ELK Stack (Elasticsearch, Logstash, Kibana)
- **Rejected Because:** More resource-intensive, Loki is simpler for Kubernetes

---

### 6.10 Auto-Scaling: HPA

**Why HPA?**
- **Assignment Requirement:** HPA for at least two critical services
- **Automatic Scaling:** Responds to CPU/memory utilization
- **Cost Optimization:** Scale down during low traffic
- **Performance:** Maintains response times under load

**Services with HPA:**
1. **Booking Service:** Critical path, high traffic
2. **User Service:** High read/write operations

**Configuration:**
- **Min Replicas:** 2 (for availability)
- **Max Replicas:** 10 (for peak load)
- **Metric:** CPU utilization
- **Target:** 20% (Booking), 7% (User) - Aggressive scaling for demo

**Alternative Considered:** VPA (Vertical Pod Autoscaler)
- **Rejected Because:** HPA is more suitable for stateless services

---

## 7. Infrastructure as Code

### 7.1 Terraform Structure

**AWS Infrastructure (`infrastructure/aws/`):**
- `providers.tf` - AWS provider configuration
- `vpc.tf` - VPC, subnets, internet gateway
- `eks.tf` - EKS cluster and node groups
- `kafka.tf` - MSK cluster and security groups
- `database.tf` - RDS and DynamoDB
- `storage.tf` - S3 buckets, ECR repositories, Lambda
- `outputs.tf` - Output values for other modules

**GCP Infrastructure (`infrastructure/gcp/`):**
- `providers.tf` - GCP provider configuration
- `network.tf` - VPC network, subnets, firewall rules
- `dataproc.tf` - Dataproc cluster configuration
- `storage.tf` - GCS buckets for job artifacts
- `variables.tf` - Input variables
- `outputs.tf` - Output values

### 7.2 Infrastructure Provisioning

**Prerequisites:**
- Terraform >= 1.0
- AWS CLI configured
- GCP service account with required permissions

**Provisioning Steps:**
1. Initialize Terraform: `terraform init`
2. Review plan: `terraform plan`
3. Apply infrastructure: `terraform apply`
4. Retrieve outputs: `terraform output`

**Key Outputs:**
- EKS cluster endpoint and kubeconfig
- MSK broker endpoints
- RDS endpoint
- S3 bucket name
- Lambda function ARN
- Dataproc cluster endpoint

### 7.3 Infrastructure Principles

**Idempotency:** Terraform ensures consistent state
**Modularity:** Reusable modules for common patterns
**Versioning:** Terraform state versioned in S3 (backend)
**Security:** Secrets managed via environment variables or AWS Secrets Manager
**Cost Optimization:** Use smallest instance types suitable for assignment

---

## 8. Observability Stack

### 8.1 Metrics Collection (Prometheus)

**Deployment:** Via ArgoCD (Helm chart: kube-prometheus-stack)

**Components:**
- **Prometheus Server:** Scrapes metrics from services
- **ServiceMonitors:** Auto-discovers services with metrics endpoints
- **AlertManager:** Handles alert routing (optional)

**Metrics Collected:**
- **Kubernetes Metrics:**
  - Node CPU/memory usage
  - Pod CPU/memory usage
  - Container resource limits
- **Application Metrics:**
  - HTTP request rate (RPS)
  - HTTP request duration (latency)
  - HTTP error rate
  - Custom business metrics

**Service Integration:**
- All services expose `/metrics` endpoint
- Prometheus scrapes every 30 seconds
- Metrics retained for 15 days

### 8.2 Visualization (Grafana)

**Deployment:** Via ArgoCD (included in kube-prometheus-stack)

**Access:**
- **Type:** LoadBalancer (public URL)
- **Default Credentials:** admin / prom-operator
- **Port:** 80

**Dashboards:**
1. **Kubernetes Cluster Health:**
   - Node status and resource usage
   - Pod status and restarts
   - Namespace resource quotas

2. **Service Metrics:**
   - Request rate (RPS) per service
   - Error rate per service
   - Latency (p50, p95, p99) per service
   - CPU/memory usage per service

3. **HPA Status:**
   - Current replicas vs desired
   - CPU utilization triggering scaling
   - Scaling events timeline

### 8.3 Log Aggregation (Loki)

**Deployment:** Via ArgoCD (Helm chart: loki-stack)

**Components:**
- **Loki:** Log aggregation system
- **Promtail:** Log shipper (runs as DaemonSet)
- **Grafana Integration:** Loki added as data source

**Log Collection:**
- **Promtail:** Automatically collects logs from all pods
- **Filters:** Excludes system namespaces (kube-system, kube-public)
- **Storage:** Ephemeral (for assignment), production would use persistent volume

**Query Language:** LogQL (Prometheus-compatible)

**Example Queries:**
- `{namespace="default", app="booking-service"} |= "error"`
- `rate({app="user-service"}[5m])`

### 8.4 Service Monitoring

**ServiceMonitors:**
- Defined in `k8s-gitops/system/servicemonitors.yaml`
- Labels services for Prometheus discovery
- Configures scrape intervals and endpoints

**Metrics Endpoints:**
- All services implement `/metrics` endpoint
- Prometheus client libraries (prom-client, prometheus-flask-exporter)
- Exposes standard metrics (request count, duration, errors)

---

## 9. Load Testing Strategy

### 9.1 Load Testing Tool: k6

**Why k6?**
- **Assignment Requirement:** Use load testing tool (k6, JMeter, Gatling)
- **JavaScript-based:** Easy to write and maintain tests
- **Cloud-Native:** Designed for modern architectures
- **Metrics:** Rich built-in and custom metrics
- **CI/CD Integration:** Easy to integrate in pipelines

### 9.2 Test Scenarios

**Test Script:** `load-testing/k6-load-test.js`

**Stages:**
1. **Ramp-up (1 min):** 0 → 10 users
2. **Ramp-up (3 min):** 10 → 50 users
3. **Ramp-up (5 min):** 50 → 100 users (triggers HPA)
4. **Peak Load (3 min):** 100 → 150 users (stress test)
5. **Ramp-down (2 min):** 150 → 50 users
6. **Ramp-down (1 min):** 50 → 0 users

**Total Duration:** ~15 minutes

### 9.3 Test Cases

1. **Homepage Access:**
   - GET `/` - Verify 200 status

2. **User Registration:**
   - POST `/api/users/register` - Create unique users
   - Verify user_id returned

3. **Event Listing:**
   - GET `/api/events` - Retrieve all events
   - Verify non-empty response

4. **Ticket Booking:**
   - POST `/api/bookings/book` - Book tickets
   - Verify booking confirmation

5. **User Bookings:**
   - GET `/api/users/:id/bookings` - Retrieve user bookings

6. **Health Check:**
   - GET `/api/health` - Verify service status

### 9.4 Success Criteria

**Performance Thresholds:**
- **95th Percentile Latency:** < 500ms
- **Error Rate:** < 10%
- **Request Success Rate:** > 90%

**HPA Validation:**
- Observe pod scaling during load test
- Verify CPU utilization triggers scaling
- Confirm replicas scale from 2 → 10 (max)
- Verify scale-down after load decreases

### 9.5 Monitoring During Load Test

**Metrics to Observe:**
- Pod count (via `kubectl get hpa`)
- CPU utilization per pod
- Request rate (RPS)
- Error rate
- Response time percentiles

**Commands:**
```bash
# Watch HPA scaling
kubectl get hpa -w

# Watch pod count
kubectl get pods -w

# View pod metrics
kubectl top pods
```

### 9.6 Load Test Results

**Expected Outcomes:**
- HPA scales Booking Service from 2 → 10 replicas
- HPA scales User Service from 2 → 10 replicas
- System maintains < 500ms latency under load
- Error rate remains < 10%
- Services recover gracefully after load decreases

**Documentation:**
- Results saved to `readme/load-test-summary.json`
- Grafana dashboards show metrics during test
- Screenshots/video of HPA scaling events

---

## 10. Deployment Architecture

### 10.1 GitOps Workflow

**Repository Structure:**
```
k8s-gitops/
├── apps/
│   ├── frontend.yaml
│   ├── user-service.yaml
│   ├── booking-service.yaml
│   └── event-catalog.yaml
└── system/
    ├── monitoring.yaml
    ├── logging.yaml
    └── servicemonitors.yaml
```

**ArgoCD Application:**
- **Name:** `ticket-booking-app`
- **Source:** GitHub repository
- **Path:** `k8s-gitops/apps`
- **Sync Policy:** Automated (prune, self-heal)

**Deployment Flow:**
1. Developer commits changes to Git
2. ArgoCD detects changes (polling or webhook)
3. ArgoCD syncs changes to Kubernetes cluster
4. Kubernetes applies new manifests
5. Pods are updated via rolling update

### 10.2 Container Images

**ECR Repositories:**
- `ticket-booking/frontend`
- `ticket-booking/user-service`
- `ticket-booking/booking-service`
- `ticket-booking/event-catalog`

**Image Build Process:**
1. Build Docker image locally
2. Tag with ECR repository URL
3. Push to ECR: `docker push <ecr-url>:latest`
4. Kubernetes pulls latest image on deployment

### 10.3 Service Deployment

**Deployment Strategy:**
- **Rolling Update:** Default Kubernetes strategy
- **Replicas:** 2 (minimum for availability)
- **Resource Limits:** CPU/memory limits defined
- **Health Checks:** Liveness and readiness probes

**Service Types:**
- **LoadBalancer:** Frontend (public access)
- **ClusterIP:** Backend services (internal only)

---

## 11. Security Considerations

### 11.1 Network Security

**VPC Isolation:**
- Private subnets for EKS nodes
- Database subnets for RDS
- Security groups restrict traffic

**Security Groups:**
- EKS nodes: Allow traffic from LoadBalancer
- RDS: Allow only from EKS nodes
- MSK: Allow only from EKS nodes

### 11.2 IAM and Access Control

**EKS IAM Roles:**
- Node group IAM role with required permissions
- IRSA (IAM Roles for Service Accounts) for pod-level permissions

**Service Account Permissions:**
- User Service: DynamoDB read/write
- EKS Nodes: S3, DynamoDB, MSK access

### 11.3 Secrets Management

**Current Implementation:**
- Environment variables in Kubernetes manifests
- **Note:** Production should use Kubernetes Secrets or AWS Secrets Manager

**Improvements for Production:**
- Use Kubernetes Secrets
- Integrate with AWS Secrets Manager
- Encrypt secrets at rest
- Rotate secrets regularly

---

## 12. Scalability and Performance

### 12.1 Horizontal Scaling

**HPA Configuration:**
- **Booking Service:** 2-10 replicas (CPU-based)
- **User Service:** 2-10 replicas (CPU-based)
- **Event Catalog:** 2 replicas (fixed, low traffic)

**Cluster Autoscaling:**
- EKS node group: 2-3 nodes
- Automatically adds nodes when pods are pending

### 12.2 Database Scaling

**RDS:**
- Vertical scaling: Upgrade instance class
- Read replicas: For read-heavy workloads
- Connection pooling: SQLAlchemy default pool

**DynamoDB:**
- Auto-scaling: PAY_PER_REQUEST mode
- On-demand capacity: Handles traffic spikes automatically

### 12.3 Caching Strategy

**Future Improvements:**
- Redis for session storage
- CDN for static assets
- Application-level caching for event catalog

---

## 13. Disaster Recovery and High Availability

### 13.1 High Availability

**Multi-AZ Deployment:**
- EKS control plane: Multi-AZ (managed by AWS)
- MSK brokers: 2 brokers in different AZs
- RDS: Can be configured for Multi-AZ (not in current setup)

**Pod Distribution:**
- Kubernetes scheduler distributes pods across nodes
- Anti-affinity rules (future improvement)

### 13.2 Backup Strategy

**RDS:**
- Automated backups: Daily snapshots
- Retention: 7 days (configurable)

**S3:**
- Versioning: Can be enabled
- Cross-region replication: For disaster recovery

**DynamoDB:**
- Point-in-time recovery: Can be enabled
- On-demand backup: Manual backups

### 13.3 Monitoring and Alerting

**Prometheus Alerts:**
- Pod crash loop
- High error rate
- High latency
- Resource exhaustion

**Grafana Dashboards:**
- Real-time monitoring
- Historical trends
- Capacity planning

---

## 14. Cost Optimization

### 14.1 Resource Sizing

**Instance Types:**
- EKS nodes: `t3.medium` (cost-effective)
- RDS: `db.t3.micro` (smallest available)
- MSK: `kafka.t3.small` (minimum for HA)
- Dataproc: `n1-standard-2` (balanced)

### 14.2 Cost-Saving Strategies

**Serverless Components:**
- Lambda: Pay per invocation
- DynamoDB: PAY_PER_REQUEST mode

**Auto-Scaling:**
- Scale down during low traffic
- HPA prevents over-provisioning

**Reserved Instances:**
- Not used (assignment environment)
- Production would benefit from RIs

---

## 15. Future Enhancements

### 15.1 Short-Term Improvements

1. **Kubernetes Secrets:** Replace environment variables
2. **Multi-AZ RDS:** Enable for high availability
3. **Redis Cache:** Add caching layer
4. **API Gateway:** Centralized API management
5. **WAF:** Web Application Firewall for frontend

### 15.2 Long-Term Enhancements

1. **Service Mesh:** Istio or Linkerd for advanced traffic management
2. **CI/CD Pipeline:** Automated testing and deployment
3. **Multi-Region:** Deploy to multiple regions
4. **Advanced Analytics:** Machine learning for demand forecasting
5. **Mobile App:** Native mobile applications

---

## 16. Conclusion

This design document presents a comprehensive multi-cloud microservices architecture for an event ticketing system. The architecture demonstrates:

✅ **6 Microservices** with distinct responsibilities  
✅ **Multi-cloud deployment** (AWS + GCP)  
✅ **Infrastructure as Code** via Terraform  
✅ **GitOps** deployment with ArgoCD  
✅ **Real-time stream processing** with Flink on Dataproc  
✅ **Serverless function** for event-driven processing  
✅ **Comprehensive observability** with Prometheus, Grafana, and Loki  
✅ **Auto-scaling** via HPA for critical services  
✅ **Load testing** validation with k6  

The system is designed to be scalable, resilient, and maintainable while meeting all assignment requirements. The use of managed services reduces operational overhead while providing enterprise-grade reliability and performance.

---

## Appendix A: Technology Stack Summary

| Component | Technology | Provider |
|-----------|-----------|----------|
| Container Orchestration | Kubernetes (EKS) | AWS |
| Frontend | Node.js, Express | AWS EKS |
| User Service | Node.js, Express | AWS EKS |
| Booking Service | Python, Flask | AWS EKS |
| Event Catalog | Python, Flask | AWS EKS |
| Ticket Generator | Python | AWS Lambda |
| Analytics | Apache Flink (PyFlink) | GCP Dataproc |
| Message Queue | Kafka (MSK) | AWS |
| SQL Database | PostgreSQL (RDS) | AWS |
| NoSQL Database | DynamoDB | AWS |
| Object Storage | S3 | AWS |
| Container Registry | ECR | AWS |
| GitOps | ArgoCD | AWS EKS |
| Metrics | Prometheus | AWS EKS |
| Visualization | Grafana | AWS EKS |
| Logging | Loki | AWS EKS |
| Load Testing | k6 | Local/CI |

---

## Appendix B: Key Configuration Values

**AWS Region:** us-east-1  
**GCP Region:** us-central1 (configurable)  
**Kubernetes Version:** 1.30  
**Kafka Version:** 3.5.1  
**PostgreSQL Version:** 16.3  
**Flink Version:** Latest (via Dataproc image)  
**Python Version:** 3.9 (Lambda), Latest (services)  
**Node.js Version:** Latest LTS  

---

## Appendix C: Repository Links

**GitHub Repository:** https://github.com/Nishit556/ticket-booking-assignment.git  
**ArgoCD Application:** `ticket-booking-app`  
**Terraform State:** S3 backend (configured)  

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-23  
**Status:** Complete
