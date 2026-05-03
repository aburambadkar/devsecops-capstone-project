# Secure 2-Tier Inventory Deployment: A DevSecOps Pipeline

[![Build Status](https://github.com/aburambadkar/devsecops-capstone-project/actions/workflows/main-pipeline.yml/badge.svg)](https://github.com/aburambadkar/devsecops-capstone-project/actions/workflows/main-pipeline.yml)

##  Project Overview

This project demonstrates a production-ready **DevSecOps lifecycle** for a containerized two-tier web application. The application consists of a **Flask-based inventory system** paired with a **MySQL database**, orchestrated using **Docker Compose**.

The core objective was to move beyond simple deployment by establishing a "security-first" CI/CD pipeline. Using **GitHub Actions**, the workflow automates the entire process when a Pull Request is opened against `main`—performing static analysis, vulnerability scanning, and multi-stage builds before deploying the verified artifacts to an **AWS EC2** instance.

###  Key Objectives
* **Automation:** Eliminate manual intervention by using GitHub Actions for build and deployment.
* **Security Integration:** Implement a "Shift-Left" approach by scanning code and containers (Bandit, Hadolint, Trivy, Gitleaks) before they reach production.
* **Containerization & Orchestration:** Package the application and database into optimized Docker images and use Docker Compose to manage multi-container networking and environment consistency.

## Architecture Diagram
The following diagram illustrates the end-to-end DevSecOps lifecycle, from the developer's local environment through the automated security gates to the final production environment on AWS.

```text
+-----------------+      +-----------------------+      +-------------------------------------------+
|    Developer    |----->|     GitHub Repo       |----->|          GitHub Actions Runner            |
|  (Pushes Code)  |      |  (Source Code Mgmt)   |      |        (DevSecOps Orchestration)          |
+-----------------+      +-----------------------+      +---------------------+---------------------+
                                                                              |
                                        +-------------------------------------+---------------------+
                                        |  PHASE 1: Static Analysis (SAST)                          |
                                        |  - Linter: Code Quality Check                             |
                                        |  - Gitleaks: Secret Scanning                              |
                                        |  - Bandit: Python Security Scanning                       |
                                        +-------------------------------------+---------------------+
                                                                              |
                                        +-------------------------------------+---------------------+
                                        |  PHASE 2: Container Security                              |
                                        |  - Hadolint: Dockerfile Linting                           |
                                        |  - Docker Build: Image Creation                           |
                                        |  - Trivy: Container Image Vulnerability Scan              |
                                        |  - Docker Push: Push to Docker Hub (Verified Image)       |
                                        +-------------------------------------+---------------------+
                                                                              |
                                                                              | Secure Deployment (SSH)
                                                                              v
                                                        +-------------------------------------------+
                                                        |            Target App Server              |
                                                        |              (AWS EC2 Host)               |
                                                        |                                           |
                                                        |  +-------------------------------------+  |
                                                        |  |    Docker Compose Orchestration     |  |
                                                        |  |  - [Container] Flask App (Tier 1)   |  |
                                                        |  |  - [Container] MySQL DB (Tier 2)    |  |
                                                        |  +-------------------------------------+  |
                                                        +-------------------------------------------+
```

## Project Structure

```
devsecops-capstone-project/
├── .github/
│   └── workflows/
│       ├── main-pipeline.yml          # Orchestrator — triggers on PR to main
│       ├── python-security-check.yml  # Phase 1: flake8, Bandit, Gitleaks
│       ├── docker-build-push.yml      # Phase 2: Hadolint, Docker build, Trivy, push
│       └── deploy_to_ec2.yml          # Phase 3: SCP + SSH deploy to EC2
├── db/
│   └── init.sql                       # MySQL schema + seed data
├── templates/
│   └── index.html                     # Flask HTML template
├── app.py                             # Flask application (inventory routes + /health)
├── Dockerfile                         # Multi-stage build (builder + runtime)
├── docker-compose.yml                 # Service orchestration (Flask app + MySQL)
└── requirements.txt                   # Python dependencies
```

## System Configuration & Environment

To maintain a secure and decoupled architecture, the pipeline utilizes a combination of **GitHub Repository Variables** for non-sensitive configuration and **GitHub Secrets** for sensitive credentials.

### GitHub Actions: Configuration & Secrets
The following environment data must be configured to enable the automated deployment:

| Item Name | Type | Description |
| :--- | :--- | :--- |
| **`DOCKER_USERNAME`** | **Variable** | Docker Hub ID used for image tagging and registry identification. |
| **`DOCKER_TOKEN`** | **Secret** | Personal Access Token (PAT) for secure image pushes. |
| **`EC2_HOST`** | **Secret** | Public IP of the Target AWS EC2 instance. |
| **`EC2_USERNAME`** | **Secret** | SSH username for the EC2 instance (e.g. `ubuntu` for Ubuntu AMIs). |
| **`EC2_SSH_KEY`** | **Secret** | Private SSH key for secure remote command execution. |
| **`DB_PASSWORD`** | **Secret** | Secure database credential passed to both Flask and MySQL container. |

### Infrastructure Specifications (AWS)
* **Compute:** AWS EC2 (Ubuntu 22.04 LTS).
* **Network Security (Security Groups):** * **Inbound:** * Port `8080`: Public web traffic to the Flask application.
        * Port `22`: SSH access for the GitHub Actions deployment runner.
    * **Outbound:** All traffic (Required for pulling Docker images and security updates).
* **Host Requirements:** Docker and Docker Compose pre-installed on the instance.


## Running Locally

You can run the full two-tier stack on your machine with Docker Compose. No GitHub Actions or AWS account required.

**Prerequisites:** Docker and Docker Compose installed.

```bash
# 1. Build the Flask image locally
docker build -t inventory-app:latest .

# 2. Set the required environment variables
export DOCKER_USERNAME=inventory-app
export IMAGE_TAG=latest
export DB_PASSWORD=yourpassword

# 3. Start the stack (app + MySQL)
docker compose up -d

# 4. Visit the app
open http://localhost:8080
```

To stop and clean up:
```bash
docker compose down -v
```

> **Note:** The `docker-compose.yml` references `${DOCKER_USERNAME}/inventory-app:${IMAGE_TAG}` for the app image. When running locally, set `DOCKER_USERNAME=inventory-app` and `IMAGE_TAG=latest` so it matches the image you built in step 1.

## Reflections & Future Enhancements:

Looking back at the deployment, there are a few areas where the system's reliability could be hardened. These aren't necessarily missing features, but rather lessons learned on how to move from a working prototype to a more resilient, production-grade environment.

One of the biggest takeaways was that a "Healthy" container doesn't always mean a "Functional" app.

### The Database Level: 
Instead of just checking if MySQL is "awake" with a ping, a better approach would be a "Data-Ready" check. We could have the health check run a simple SELECT 1 on the tools table. That way, the database only flags itself as ready once the schema is actually there.

### The App Level: 
Similarly, the Flask app could have its own internal check. Before it starts serving traffic, it could try to "handshake" with the database. If it can't find the data it needs, it should report itself as unhealthy so we don't end up with those 500 errors.

### Automated Verification
It would be great to add a "Smoke Test" phase at the very end of the pipeline. Once the deployment finishes, a small script could hit the public URL and verify that it receives a 200 OK and sees the "Inventory" header. If that check fails, the pipeline could automatically alert us or even trigger a rollback to the previous version.