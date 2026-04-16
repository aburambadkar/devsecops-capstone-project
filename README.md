# Secure 2-Tier Inventory Deployment: A DevSecOps Pipeline

[![Build Status](https://github.com/aburambadkar/devsecops-capstone-project/actions/workflows/main-pipeline.yml/badge.svg)](https://github.com/aburambadkar/devsecops-capstone-project/actions/workflows/main-pipeline.yml)

##  Project Overview

This project demonstrates a production-ready **DevSecOps lifecycle** for a containerized two-tier web application. The application consists of a **Flask-based inventory system** paired with a **MySQL database**, orchestrated using **Docker Compose**.

The core objective was to move beyond simple deployment by establishing a "security-first" CI/CD pipeline. Using **GitHub Actions**, the workflow automates the entire process from the moment code is pushed—performing static analysis, vulnerability scanning, and multi-stage builds before deploying the verified artifacts to an **AWS EC2** instance.

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

## System Configuration & Environment

To maintain a secure and decoupled architecture, the pipeline utilizes a combination of **GitHub Repository Variables** for non-sensitive configuration and **GitHub Secrets** for sensitive credentials.

### GitHub Actions: Configuration & Secrets
The following environment data must be configured to enable the automated deployment:

| Item Name | Type | Description |
| :--- | :--- | :--- |
| **`DOCKER_USERNAME`** | **Variable** | Docker Hub ID used for image tagging and registry identification. |
| **`DOCKER_TOKEN`** | **Secret** | Personal Access Token (PAT) for secure image pushes. |
| **`EC2_HOST`** | **Secret** | Public IP of the Target AWS EC2 instance. |
| **`EC2_SSH_KEY`** | **Secret** | Private SSH key for secure remote command execution. |
| **`DB_PASSWORD`** | **Secret** | Secure database credential passed to both Flask and MySQL container. |

### Infrastructure Specifications (AWS)
* **Compute:** AWS EC2 (Ubuntu 22.04 LTS).
* **Network Security (Security Groups):** * **Inbound:** * Port `8080`: Public web traffic to the Flask application.
        * Port `22`: SSH access for the GitHub Actions deployment runner.
    * **Outbound:** All traffic (Required for pulling Docker images and security updates).
* **Host Requirements:** Docker and Docker Compose pre-installed on the instance.


## Engineering Challenges & Troubleshooting
Building this pipeline involved overcoming several hard-hit integration hurdles. While many minor issues were resolved during the build stages (linting, permissions, etc.), the following challenges required deep analysis and manual intervention.

### Git Workflow & "Conflicted Branch" Recovery
 **The Challenge** 
While following a feature-branch workflow, several untested and unstable commits were accidently included in an open Pull Request to main. When I tried to revert the unstable changes and "cherry-pick" only the verified fixes, I encountered a cascade of merge conflicts that made the branch history unreliable.

**The Resolution**
I performed a Git Revert to roll back the repository to its last known stable state. 
Instead of spending hours resolving complex cherry-pick conflicts, I created a brand-new branch directly from the stable main branch.
I manually ported only the specific, verified files and configurations into this new branch. This allowed for a clean, conflict-free Pull Request and a successful merge into main.

**The Lesson**
This reinforced the necessity of Branch Protection and atomic commits.
I learned that even in solo projects, maintaining a clean main branch is vital for deployment reliability.

### Internal Server Error After Successful Deployment
**The Challenge** 
Upon deployment, the application containers were reported as "Healthy," yet the URL returned an HTTP 500 Internal Server Error.

**The Root Cause**
During the initial run, the db/init.sql file was missing on the EC2 host. Volume mount instruction in docker compose, created a directory named init.sql instead of a file. MySQL initialized its internal data volume db_data meaning no tables were created.

App logs showed the following crash:

```text
mysql.connector.errors.ProgrammingError: 1146 (42S02): Table 'inventory.tools' doesn't exist
```

**The Resolution**
 I updated the deploy_to_ec2.yml workflow to explicitly include the db/ directory in the appleboy/scp-action phase, ensuring the real init.sql script reached the EC2 host.
 Executed sudo docker compose down -v to delete the stale, uninitialized database volumes.
 This forced MySQL to treat the next startup as a First Run and finally executing the init.sql script and creating the required schema.

**The Lesson**
I learned that Database volumes are persistent. Simply fixing a script isn't enough; you must reset the volume state to force a re-initialization.

## Reflections & Future Enhancements:

Looking back at the deployment, there are a few areas where the system's reliability could be hardened. These aren't necessarily missing features, but rather lessons learned on how to move from a working prototype to a more resilient, production-grade environment.

One of the biggest takeaways was that a "Healthy" container doesn't always mean a "Functional" app.

### The Database Level: 
Instead of just checking if MySQL is "awake" with a ping, a better approach would be a "Data-Ready" check. We could have the health check run a simple SELECT 1 on the tools table. That way, the database only flags itself as ready once the schema is actually there.

### The App Level: 
Similarly, the Flask app could have its own internal check. Before it starts serving traffic, it could try to "handshake" with the database. If it can't find the data it needs, it should report itself as unhealthy so we don't end up with those 500 errors.

### Automated Verification
It would be great to add a "Smoke Test" phase at the very end of the pipeline. Once the deployment finishes, a small script could hit the public URL and verify that it receives a 200 OK and sees the "Inventory" header. If that check fails, the pipeline could automatically alert us or even trigger a rollback to the previous version.