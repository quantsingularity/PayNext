# PayNext

![CI/CD Status](https://img.shields.io/github/actions/workflow/status/quantsingularity/PayNext/cicd.yml?branch=main&label=CI/CD&logo=github)
[![Test Coverage](https://img.shields.io/badge/coverage-87%25-brightgreen)](https://github.com/quantsingularity/PayNext/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 💳 Modern Microservices Payment Platform

PayNext is a robust, scalable payment processing platform built on a microservices architecture. It provides secure, fast, and reliable payment solutions for businesses of all sizes, with support for multiple payment methods and currencies.

<div align="center">
  <img src="docs/images/PayNext_dashboard.bmp" alt="PayNext Dashboard" width="80%">
</div>

> **Note**: This project is under active development. Features and functionalities are continuously being enhanced to improve payment processing capabilities and user experience.

## Executive Summary

PayNext is a robust, scalable payment processing platform built on a **microservices architecture**. It provides secure, fast, and reliable payment solutions for businesses of all sizes, with comprehensive support for multiple payment methods and currencies. The platform is designed for high availability and maintainability, leveraging modern cloud-native technologies to ensure compliance and seamless transaction handling.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Services](#services)
- [Getting Started](#getting-started)
- [API Endpoints](#api-endpoints)
- [Testing](#testing)
- [CI/CD Pipeline](#cicd-pipeline)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

PayNext is a comprehensive payment processing platform designed with a microservices architecture to ensure scalability, resilience, and maintainability. The system handles various payment methods, provides robust security features, and offers a seamless user experience for both merchants and customers. Its modular design allows for independent development and deployment of services, making it adaptable to evolving payment industry standards and business needs.

---

## Project Structure

The project is organized into several main components:

```
PayNext/
├── backend/                # Core backend logic, services, and shared utilities
├── docs/                   # Project documentation
├── infrastructure/         # DevOps, deployment, and infra-related code
├── mobile-frontend/        # Mobile application
├── web-frontend/           # Web dashboard
├── scripts/                # Automation, setup, and utility scripts
├── LICENSE                 # License information
├── README.md               # Project overview and instructions
├── eslint.config.js        # ESLint configuration
└── package.json            # Node.js project metadata and dependencies
```

## Key Features

PayNext's features are structured across four critical areas of a modern payment platform, ensuring a secure, flexible, and fully managed service.

### Payment Processing

The platform offers extensive payment functionality, including support for **Multiple Payment Methods** such as credit/debit cards, bank transfers, and digital wallets. It is equipped for **International Payments** with multi-currency support and automatic conversion. For subscription-based models, PayNext handles **Recurring Payments**, and it also facilitates complex transactions through **Split Payments** among multiple recipients. Merchants can also generate **Payment Links** for shareable and easy collection.

### Security

Security is foundational to PayNext. The platform is designed for **PCI DSS Compliance**, adhering to the Payment Card Industry Data Security Standards. It employs **AI-powered Fraud Detection** and prevention mechanisms to protect transactions. Sensitive payment information is protected through **Tokenization**, and user accounts benefit from enhanced security via **Two-Factor Authentication**. All data in transit and at rest is secured through **End-to-end Encryption**.

### User Management

PayNext provides comprehensive tools for managing both merchants and customers. The system offers a **Streamlined Merchant Onboarding** process and secure storage for **Customer Profiles** and payment preferences. Access within the platform is governed by **Role-Based Access Control** (RBAC), ensuring granular permissions for different user types. Merchants also have access to **Account Management** tools for self-service maintenance.

### Reporting & Analytics

The platform delivers deep insights into payment activities. Merchants receive **Detailed Transaction Reports** and tools for **Financial Reconciliation** to balance accounts. An integrated **Analytics Dashboard** provides business intelligence and performance metrics. Data can be exported in various formats (CSV, PDF, Excel) via **Export Capabilities**, and users can configure specific data views using **Custom Reports**.

---

## Architecture

PayNext follows a microservices architecture, leveraging Spring Cloud components for robust service management and communication.

### Architectural Components

The system is composed of the following key components:

| Component            | Primary Function                                                                             |
| :------------------- | :------------------------------------------------------------------------------------------- |
| **API Gateway**      | Routes client requests, handles authentication, rate limiting, and circuit breaking.         |
| **Service Registry** | Manages service discovery, allowing services to find and communicate with each other.        |
| **Config Server**    | Centralizes configuration management for all microservices.                                  |
| **Core Services**    | User, Payment, Transaction, Notification, and Reporting services handle core business logic. |
| **Frontend**         | Web Dashboard and Mobile App provide user interfaces.                                        |
| **Infrastructure**   | Database Cluster, Message Queue (RabbitMQ/Kafka), Cache Layer (Redis), and Monitoring Stack. |

### Request Flow

1.  Client requests are received by the **API Gateway**.
2.  The Gateway routes requests to the appropriate microservices, utilizing the **Service Registry** for location.
3.  Services communicate with each other via REST APIs or the **Message Queue** for asynchronous processing.
4.  The **Config Server** provides dynamic configuration updates to all running services.

---

## Technology Stack

PayNext is built using a modern, enterprise-grade technology stack, primarily leveraging the Spring ecosystem.

### Core Technologies

| Category              | Key Technologies                                        | Description                                                                                   |
| :-------------------- | :------------------------------------------------------ | :-------------------------------------------------------------------------------------------- |
| **Backend**           | Spring Boot, Spring Cloud, Java 17                      | Robust framework for microservices development, utilizing Java for performance and stability. |
| **Databases**         | MySQL, MongoDB                                          | MySQL for transactional data; MongoDB for flexible data storage.                              |
| **Messaging**         | RabbitMQ, Kafka                                         | Message queues for reliable asynchronous communication and event streaming.                   |
| **Cache & Discovery** | Redis, Netflix Eureka                                   | Redis for fast caching; Eureka for dynamic service discovery.                                 |
| **API Gateway**       | Spring Cloud Gateway                                    | High-performance, reactive API gateway.                                                       |
| **Web Frontend**      | React, TypeScript, Redux Toolkit, Material-UI, Recharts | Modern stack for a responsive web dashboard with advanced data visualization.                 |
| **Mobile Frontend**   | React Native, Redux Toolkit                             | Cross-platform framework for native mobile application development.                           |

### Infrastructure & DevOps

| Category             | Key Technologies               | Description                                                            |
| :------------------- | :----------------------------- | :--------------------------------------------------------------------- |
| **Containerization** | Docker, Kubernetes             | Docker for containerization; Kubernetes for orchestration and scaling. |
| **CI/CD**            | GitHub Actions                 | Automated continuous integration and deployment pipelines.             |
| **Observability**    | Prometheus, Grafana, ELK Stack | Comprehensive monitoring, alerting, and centralized logging.           |
| **IaC**              | Terraform, Helm                | Infrastructure as Code for provisioning and managing cloud resources.  |

---

## Services

The platform is composed of dedicated microservices, each handling a specific domain:

| Service                  | Responsibilities                                                                                      |
| :----------------------- | :---------------------------------------------------------------------------------------------------- |
| **API Gateway**          | Request routing, authentication, rate limiting, circuit breaking, and Swagger documentation.          |
| **User Service**         | User registration, authentication, profile management, and role-based access control.                 |
| **Payment Service**      | Processing transactions, integrating payment gateways, and managing payment methods.                  |
| **Transaction Service**  | Recording transaction history, tracking status, handling refunds/chargebacks, and reconciliation.     |
| **Notification Service** | Sending transaction alerts via email, SMS, and push; managing notification preferences and templates. |
| **Reporting Service**    | Generating financial and transaction reports, providing analytics, and handling data export.          |

---

## Getting Started

### Prerequisites

To set up the platform, ensure you have the following installed:

- **Java 17** and **Maven**
- **Node.js** and **npm**
- **Docker** and Docker Compose
- **Kubernetes** (for production deployment)

### Local Development Setup

Follow these steps to set up the local development environment:

| Step                        | Command                                                                   | Description                                                          |
| :-------------------------- | :------------------------------------------------------------------------ | :------------------------------------------------------------------- |
| **1. Clone Repository**     | `git clone https://github.com/quantsingularity/PayNext.git && cd PayNext` | Download the source code and navigate to the project directory.      |
| **2. Start Infrastructure** | `docker-compose up -d mysql rabbitmq redis`                               | Start core infrastructure services (database, message queue, cache). |
| **3. Build & Run Backend**  | `./paynext.sh build-run-backend`                                          | Build and start all Spring Boot microservices.                       |
| **4. Run Frontend**         | `cd web-frontend && npm install && npm start`                             | Install dependencies and start the web dashboard.                    |

**Access Points:**

- **Web Dashboard**: `http://localhost:3000`
- **API Gateway**: `http://localhost:8080`
- **Swagger UI**: `http://localhost:8080/swagger-ui.html`

---

## API Endpoints

The API Gateway provides a unified entry point for accessing the various service APIs.

| Service         | Endpoint                        | Method | Description                         |
| :-------------- | :------------------------------ | :----- | :---------------------------------- |
| **User**        | `/api/users/register`           | `POST` | Register a new user.                |
| **Payment**     | `/api/payments`                 | `POST` | Initiate a new payment.             |
| **Payment**     | `/api/payments/history`         | `GET`  | Retrieve payment history.           |
| **Transaction** | `/api/transactions`             | `GET`  | List transactions.                  |
| **Transaction** | `/api/transactions/{id}/refund` | `POST` | Process a refund for a transaction. |

---

## Testing

The project maintains an overall test coverage of **87%** across all components, ensuring reliability and security in all payment operations.

### Test Coverage Summary

| Component               | Coverage | Status |
| :---------------------- | :------- | :----- |
| **Payment Service**     | 92%      | ✅     |
| **User Service**        | 90%      | ✅     |
| **Transaction Service** | 88%      | ✅     |
| **API Gateway**         | 85%      | ✅     |
| **Web Frontend**        | 85%      | ✅     |
| **Mobile Frontend**     | 80%      | ✅     |

### Testing Types

The comprehensive testing strategy includes:

- **Backend Tests**: Unit tests for service and repository layers, integration tests for API endpoints, contract tests for service interactions, and performance tests for critical operations.
- **Frontend Tests**: Component tests with React Testing Library, integration tests with Cypress, end-to-end tests for critical user flows, and snapshot tests for UI components.

**Running Tests:** All tests can be run using the convenience script `./run-all-tests.sh` from the root directory, or individually for backend (`./mvnw test`) and frontend (`npm test`).

---

## CI/CD Pipeline

PayNext uses GitHub Actions for continuous integration and deployment:

| Stage                | Control Area                    | Institutional-Grade Detail                                                              |
| :------------------- | :------------------------------ | :-------------------------------------------------------------------------------------- |
| **Formatting Check** | Change Triggers                 | Enforced on all `push` and `pull_request` events to `main` and `develop`                |
|                      | Manual Oversight                | On-demand execution via controlled `workflow_dispatch`                                  |
|                      | Source Integrity                | Full repository checkout with complete Git history for auditability                     |
|                      | Python Runtime Standardization  | Python 3.10 with deterministic dependency caching                                       |
|                      | Backend Code Hygiene            | `autoflake` to detect unused imports/variables using non-mutating diff-based validation |
|                      | Backend Style Compliance        | `black --check` to enforce institutional formatting standards                           |
|                      | Non-Intrusive Validation        | Temporary workspace comparison to prevent unauthorized source modification              |
|                      | Node.js Runtime Control         | Node.js 18 with locked dependency installation via `npm ci`                             |
|                      | Web Frontend Formatting Control | Prettier checks for web-facing assets                                                   |
|                      | Mobile Frontend Formatting      | Prettier enforcement for mobile application codebases                                   |
|                      | Documentation Governance        | Repository-wide Markdown formatting enforcement                                         |
|                      | Infrastructure Configuration    | Prettier validation for YAML/YML infrastructure definitions                             |
|                      | Compliance Gate                 | Any formatting deviation fails the pipeline and blocks merge                            |

---

## Documentation

| Document                    | Path                 | Description                                                    |
| :-------------------------- | :------------------- | :------------------------------------------------------------- |
| **README**                  | `README.md`          | High-level overview, project scope, and repository entry point |
| **Installation Guide**      | `INSTALLATION.md`    | Step-by-step installation and environment setup                |
| **API Reference**           | `API.md`             | Detailed documentation for all API endpoints                   |
| **CLI Reference**           | `CLI.md`             | Command-line interface usage, commands, and examples           |
| **User Guide**              | `USAGE.md`           | Comprehensive end-user guide, workflows, and examples          |
| **Architecture Overview**   | `ARCHITECTURE.md`    | System architecture, components, and design rationale          |
| **Configuration Guide**     | `CONFIGURATION.md`   | Configuration options, environment variables, and tuning       |
| **Feature Matrix**          | `FEATURE_MATRIX.md`  | Feature coverage, capabilities, and roadmap alignment          |
| **Contributing Guidelines** | `CONTRIBUTING.md`    | Contribution workflow, coding standards, and PR requirements   |
| **Troubleshooting**         | `TROUBLESHOOTING.md` | Common issues, diagnostics, and remediation steps              |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. The process involves forking the repository, creating a feature branch, committing your changes, and opening a Pull Request for review.

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
