# Cloud Computing Assignment - Design Document
**Group Members:** [Add Names/IDs here]

## 1. System Overview
Our application is a **Ticket Booking System** (Education/Entertainment Domain). It allows users to view events, register profiles, and book tickets. The system is designed as a microservices architecture to ensure scalability and fault tolerance.
- **Public URL:** [Will be the LoadBalancer URL of Frontend]
- **Domain:** Event Ticketing

## 2. Microservice Responsibilities
The application consists of 6 microservices:

1.  **Frontend Service (AWS EKS):**
    * **Role:** Provides the Web UI for users.
    * **Tech:** Node.js/React.
2.  **Booking Service (AWS EKS):**
    * **Role:** Handles ticket requests and pushes them to Kafka (Critical Service).
    * **Tech:** Python.
3.  **Event Catalog Service (AWS EKS):**
    * **Role:** Manages event details (SQL Data).
    * **Tech:** Python + AWS RDS (PostgreSQL).
4.  **User Service (AWS EKS):**
    * **Role:** Manages user profiles (NoSQL Data).
    * **Tech:** Node.js + AWS DynamoDB.
5.  **Ticket Generator (AWS Lambda):**
    * **Role:** Serverless function triggered by S3 uploads to generate PDF tickets.
    * **Tech:** Python Lambda.
6.  **Analytics Service (GCP Dataproc):**
    * **Role:** Consumes Kafka stream to calculate real-time sales metrics.
    * **Tech:** Apache Flink on GCP.

## 3. Cloud Deployment Architecture
* **Infrastructure as Code:** All resources provisioned via Terraform.
* **Container Orchestration:** AWS EKS (Elastic Kubernetes Service).
* **GitOps:** Deployments managed by ArgoCD tracking the GitHub repository.
* **Messaging:** AWS MSK (Managed Kafka) for decoupling Booking and Analytics.
* **Auto-scaling:**
    * **HPA:** Configured for Booking Service and User Service (CPU > 50%).
    * **Cluster Autoscaler:** EKS Node groups can scale from 2 to 3 nodes.

## 4. Interconnection Mechanisms
* **Frontend -> Backend:** REST APIs (HTTP).
* **Booking -> Analytics:** Asynchronous messaging via Kafka (Event-driven).
* **S3 -> Ticket Generator:** Event triggers (S3 Notification).

## 5. Rationale Behind Design Choices
* **Why AWS MSK?** Managed Kafka removes the operational overhead of managing Zookeeper/Brokers manually, ensuring high availability for our critical booking data.
* **Why DynamoDB for Users?** User session data requires high throughput and low latency. A key-value NoSQL store is more efficient for this than a relational DB.
* **Why Lambda for Tickets?** Ticket generation is bursty traffic (happens only after upload). Serverless saves cost by not having a container running 24/7 for occasional tasks.

## 6. Links
* **Code Video:** [Link]
* **Demo Video:** [Link]