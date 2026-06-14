# API Reference

Complete REST API documentation for PayNext platform with examples and parameter descriptions.

## Table of Contents

- [Authentication](#authentication)
- [User Service API](#user-service-api)
- [Payment Service API](#payment-service-api)
- [Transaction Service API](#transaction-service-api)
- [Notification Service API](#notification-service-api)
- [ML Services API](#ml-services-api)
- [Error Handling](#error-handling)

## Authentication

### Overview

PayNext uses JWT (JSON Web Token) based authentication. Include the token in the `Authorization` header for all protected endpoints.

**Header Format**

```
Authorization: Bearer <jwt_token>
```

### Endpoints

#### Register User

| Property          | Value                       |
| ----------------- | --------------------------- |
| **Method**        | POST                        |
| **Path**          | `/users/register`           |
| **Auth Required** | No                          |
| **Description**   | Register a new user account |

**Request Parameters**

| Name     | Type   | Required? | Default | Description                                                               | Example            |
| -------- | ------ | --------- | ------- | ------------------------------------------------------------------------- | ------------------ |
| username | string | Yes       | -       | Unique username (3-50 chars)                                              | "john.doe"         |
| email    | string | Yes       | -       | Valid email address                                                       | "john@example.com" |
| password | string | Yes       | -       | Strong password (min 8 chars, uppercase, lowercase, number, special char) | "SecurePass123!"   |
| role     | string | No        | "USER"  | User role (USER, MERCHANT, ADMIN)                                         | "USER"             |

**Example Request**

```bash
curl -X POST http://localhost:8002/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john.doe",
    "email": "john@example.com",
    "password": "SecurePass123!",
    "role": "USER"
  }'
```

**Example Response**

```json
{
  "id": 1,
  "username": "john.doe",
  "email": "john@example.com",
  "role": "USER",
  "createdAt": "2025-01-01T10:00:00Z",
  "status": "ACTIVE"
}
```

#### Login

| Property          | Value                                   |
| ----------------- | --------------------------------------- |
| **Method**        | POST                                    |
| **Path**          | `/users/login`                          |
| **Auth Required** | No                                      |
| **Description**   | Authenticate user and receive JWT token |

**Request Parameters**

| Name     | Type   | Required? | Default | Description       | Example          |
| -------- | ------ | --------- | ------- | ----------------- | ---------------- |
| username | string | Yes       | -       | Username or email | "john.doe"       |
| password | string | Yes       | -       | User password     | "SecurePass123!" |

**Example Request**

```bash
curl -X POST http://localhost:8002/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john.doe",
    "password": "SecurePass123!"
  }'
```

**Example Response**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJqb2huLmRvZSIsImlhdCI6MTYxMjEzNzAyMiwiZXhwIjoxNjEyMTQwNjIyfQ.abc123",
  "type": "Bearer",
  "expiresIn": 3600
}
```

## User Service API

### Get User Profile

| Property          | Value                                |
| ----------------- | ------------------------------------ |
| **Method**        | GET                                  |
| **Path**          | `/users/profile`                     |
| **Auth Required** | Yes                                  |
| **Description**   | Get current user profile information |

**Example Request**

```bash
curl -X GET http://localhost:8002/users/profile \
  -H "Authorization: Bearer $TOKEN"
```

**Example Response**

```json
{
  "id": 1,
  "username": "john.doe",
  "email": "john@example.com",
  "role": "USER",
  "createdAt": "2025-01-01T10:00:00Z",
  "lastLogin": "2025-01-01T14:30:00Z",
  "twoFactorEnabled": false
}
```

### Update User Profile

| Property          | Value                           |
| ----------------- | ------------------------------- |
| **Method**        | PUT                             |
| **Path**          | `/users/profile`                |
| **Auth Required** | Yes                             |
| **Description**   | Update user profile information |

**Request Parameters**

| Name      | Type   | Required? | Default | Description       | Example                |
| --------- | ------ | --------- | ------- | ----------------- | ---------------------- |
| email     | string | No        | -       | New email address | "newemail@example.com" |
| phone     | string | No        | -       | Phone number      | "+1234567890"          |
| firstName | string | No        | -       | First name        | "John"                 |
| lastName  | string | No        | -       | Last name         | "Doe"                  |

**Example Request**

```bash
curl -X PUT http://localhost:8002/users/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newemail@example.com",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

## Payment Service API

### Create Payment

| Property          | Value                             |
| ----------------- | --------------------------------- |
| **Method**        | POST                              |
| **Path**          | `/api/payments`                   |
| **Auth Required** | Yes                               |
| **Description**   | Process a new payment transaction |

**Request Parameters**

| Name        | Type    | Required? | Default | Description                                                     | Example            |
| ----------- | ------- | --------- | ------- | --------------------------------------------------------------- | ------------------ |
| amount      | decimal | Yes       | -       | Payment amount (positive number)                                | 99.99              |
| currency    | string  | Yes       | -       | ISO 4217 currency code                                          | "USD"              |
| method      | string  | Yes       | -       | Payment method (CREDIT_CARD, DEBIT_CARD, BANK_TRANSFER, WALLET) | "CREDIT_CARD"      |
| description | string  | No        | -       | Payment description                                             | "Product purchase" |
| metadata    | object  | No        | {}      | Additional metadata                                             | {"orderId": "123"} |

**Example Request**

```bash
curl -X POST http://localhost:8002/api/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 99.99,
    "currency": "USD",
    "method": "CREDIT_CARD",
    "description": "Product purchase",
    "metadata": {
      "orderId": "ORD-2025-001",
      "customerId": "CUST-123"
    }
  }'
```

**Example Response**

```json
{
  "id": 1001,
  "transactionId": "TXN-2025-001",
  "status": "SUCCESS",
  "amount": 99.99,
  "currency": "USD",
  "method": "CREDIT_CARD",
  "description": "Product purchase",
  "createdAt": "2025-01-01T10:30:00Z",
  "processedAt": "2025-01-01T10:30:02Z",
  "metadata": {
    "orderId": "ORD-2025-001",
    "customerId": "CUST-123"
  }
}
```

### Get All Payments

| Property          | Value                                           |
| ----------------- | ----------------------------------------------- |
| **Method**        | GET                                             |
| **Path**          | `/api/payments`                                 |
| **Auth Required** | Yes                                             |
| **Description**   | Retrieve payment history for authenticated user |

**Query Parameters**

| Name      | Type    | Required? | Default | Description                                 | Example      |
| --------- | ------- | --------- | ------- | ------------------------------------------- | ------------ |
| page      | integer | No        | 0       | Page number (0-indexed)                     | 0            |
| size      | integer | No        | 20      | Items per page                              | 20           |
| status    | string  | No        | -       | Filter by status (SUCCESS, PENDING, FAILED) | "SUCCESS"    |
| startDate | date    | No        | -       | Filter from date (ISO 8601)                 | "2025-01-01" |
| endDate   | date    | No        | -       | Filter to date (ISO 8601)                   | "2025-01-31" |

**Example Request**

```bash
curl -X GET "http://localhost:8002/api/payments?page=0&size=10&status=SUCCESS" \
  -H "Authorization: Bearer $TOKEN"
```

**Example Response**

```json
{
  "content": [
    {
      "id": 1001,
      "transactionId": "TXN-2025-001",
      "status": "SUCCESS",
      "amount": 99.99,
      "currency": "USD",
      "createdAt": "2025-01-01T10:30:00Z"
    }
  ],
  "page": 0,
  "size": 10,
  "totalElements": 45,
  "totalPages": 5
}
```

### Get Payment by ID

| Property          | Value                             |
| ----------------- | --------------------------------- |
| **Method**        | GET                               |
| **Path**          | `/api/payments/{id}`              |
| **Auth Required** | Yes                               |
| **Description**   | Retrieve specific payment details |

**Path Parameters**

| Name | Type | Required? | Description | Example |
| ---- | ---- | --------- | ----------- | ------- |
| id   | long | Yes       | Payment ID  | 1001    |

**Example Request**

```bash
curl -X GET http://localhost:8002/api/payments/1001 \
  -H "Authorization: Bearer $TOKEN"
```

**Example Response**

```json
{
  "id": 1001,
  "transactionId": "TXN-2025-001",
  "userId": 1,
  "status": "SUCCESS",
  "amount": 99.99,
  "currency": "USD",
  "method": "CREDIT_CARD",
  "description": "Product purchase",
  "createdAt": "2025-01-01T10:30:00Z",
  "processedAt": "2025-01-01T10:30:02Z",
  "fraudScore": 0.03,
  "metadata": {
    "orderId": "ORD-2025-001"
  }
}
```

### Create Recurring Payment

| Property          | Value                                 |
| ----------------- | ------------------------------------- |
| **Method**        | POST                                  |
| **Path**          | `/api/payments/subscription`          |
| **Auth Required** | Yes                                   |
| **Description**   | Set up recurring payment subscription |

**Request Parameters**

| Name      | Type    | Required? | Default | Description                                       | Example      |
| --------- | ------- | --------- | ------- | ------------------------------------------------- | ------------ |
| amount    | decimal | Yes       | -       | Recurring amount                                  | 29.99        |
| currency  | string  | Yes       | -       | Currency code                                     | "USD"        |
| interval  | string  | Yes       | -       | Billing interval (DAILY, WEEKLY, MONTHLY, YEARLY) | "MONTHLY"    |
| startDate | date    | Yes       | -       | Subscription start date                           | "2025-01-01" |
| endDate   | date    | No        | -       | Subscription end date (null for indefinite)       | "2026-01-01" |

**Example Request**

```bash
curl -X POST http://localhost:8002/api/payments/subscription \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 29.99,
    "currency": "USD",
    "interval": "MONTHLY",
    "startDate": "2025-01-01",
    "description": "Premium subscription"
  }'
```

## Transaction Service API

### Get Transaction History

| Property          | Value                              |
| ----------------- | ---------------------------------- |
| **Method**        | GET                                |
| **Path**          | `/api/transactions`                |
| **Auth Required** | Yes                                |
| **Description**   | Retrieve all transactions for user |

**Example Request**

```bash
curl -X GET http://localhost:8002/api/transactions \
  -H "Authorization: Bearer $TOKEN"
```

### Process Refund

| Property          | Value                            |
| ----------------- | -------------------------------- |
| **Method**        | POST                             |
| **Path**          | `/api/transactions/{id}/refund`  |
| **Auth Required** | Yes                              |
| **Description**   | Process refund for a transaction |

**Request Parameters**

| Name         | Type    | Required? | Default     | Description   | Example                   |
| ------------ | ------- | --------- | ----------- | ------------- | ------------------------- |
| amount       | decimal | No        | full amount | Refund amount | 99.99                     |
| reason       | string  | Yes       | -           | Refund reason | "Product return"          |
| refundMethod | string  | No        | "ORIGINAL"  | Refund method | "ORIGINAL_PAYMENT_METHOD" |

**Example Request**

```bash
curl -X POST http://localhost:8002/api/transactions/1001/refund \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 99.99,
    "reason": "Product return",
    "refundMethod": "ORIGINAL_PAYMENT_METHOD"
  }'
```

## Notification Service API

### Send Email Notification

| Property          | Value                           |
| ----------------- | ------------------------------- |
| **Method**        | POST                            |
| **Path**          | `/api/notifications/email`      |
| **Auth Required** | Yes                             |
| **Description**   | Send email notification to user |

**Request Parameters**

| Name      | Type   | Required? | Default | Description     | Example                       |
| --------- | ------ | --------- | ------- | --------------- | ----------------------------- |
| recipient | string | Yes       | -       | Recipient email | "user@example.com"            |
| subject   | string | Yes       | -       | Email subject   | "Payment Confirmation"        |
| body      | string | Yes       | -       | Email body      | "Your payment was successful" |
| template  | string | No        | -       | Template name   | "payment_confirmation"        |

**Example Request**

```bash
curl -X POST http://localhost:8002/api/notifications/email \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "user@example.com",
    "subject": "Payment Confirmation",
    "body": "Your payment of $99.99 was successful",
    "template": "payment_confirmation"
  }'
```

## ML Services API

### Fraud Detection

| Property          | Value                                       |
| ----------------- | ------------------------------------------- |
| **Method**        | POST                                        |
| **Path**          | `http://localhost:5000/predict`             |
| **Auth Required** | No (internal service)                       |
| **Description**   | Check transaction for fraud using ML models |

**Request Parameters**

| Name             | Type    | Required? | Default | Description            | Example        |
| ---------------- | ------- | --------- | ------- | ---------------------- | -------------- |
| transaction_id   | string  | Yes       | -       | Transaction identifier | "TXN-2025-001" |
| user_id          | string  | Yes       | -       | User identifier        | "user123"      |
| amount           | decimal | Yes       | -       | Transaction amount     | 500.00         |
| merchant         | string  | Yes       | -       | Merchant name          | "OnlineStore"  |
| location         | string  | Yes       | -       | Location code          | "US-NY"        |
| transaction_type | string  | Yes       | -       | Type of transaction    | "purchase"     |
| time_of_day      | integer | No        | -       | Hour of day (0-23)     | 14             |

**Example Request**

```bash
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "TXN-2025-001",
    "user_id": "user123",
    "amount": 500.00,
    "merchant": "OnlineStore",
    "location": "US-NY",
    "transaction_type": "purchase",
    "time_of_day": 14
  }'
```

**Example Response**

```json
{
  "transaction_id": "TXN-2025-001",
  "is_fraud": false,
  "fraud_probability": 0.03,
  "risk_score": 15.2,
  "model_version": "v2.0",
  "recommendation": "APPROVE",
  "factors": {
    "amount_anomaly": 0.1,
    "location_risk": 0.05,
    "merchant_reputation": 0.95
  }
}
```

### Credit Scoring

| Property          | Value                           |
| ----------------- | ------------------------------- |
| **Method**        | POST                            |
| **Path**          | `http://localhost:5005/predict` |
| **Auth Required** | No (internal service)           |
| **Description**   | Calculate credit score for user |

**Example Request**

```bash
curl -X POST http://localhost:5005/predict \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user123",
    "annual_income": 75000,
    "credit_history_length": 5,
    "number_of_accounts": 3,
    "payment_history": 0.95,
    "debt_to_income": 0.3
  }'
```

### Churn Prediction

| Property          | Value                           |
| ----------------- | ------------------------------- |
| **Method**        | POST                            |
| **Path**          | `http://localhost:5001/predict` |
| **Auth Required** | No (internal service)           |
| **Description**   | Predict user churn probability  |

### Transaction Categorization

| Property          | Value                                |
| ----------------- | ------------------------------------ |
| **Method**        | POST                                 |
| **Path**          | `http://localhost:5002/predict`      |
| **Auth Required** | No (internal service)                |
| **Description**   | Automatically categorize transaction |

**Example Request**

```bash
curl -X POST http://localhost:5002/predict \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Amazon.com purchase",
    "amount": 45.99,
    "merchant": "Amazon"
  }'
```

**Example Response**

```json
{
  "category": "Shopping",
  "subcategory": "Online Retail",
  "confidence": 0.95
}
```

## Error Handling

### Error Response Format

All API errors follow a consistent format:

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable error message",
  "timestamp": "2025-01-01T10:30:00Z",
  "path": "/api/payments",
  "details": {
    "field": "amount",
    "issue": "must be positive"
  }
}
```

### HTTP Status Codes

| Code | Meaning               | Description                         |
| ---- | --------------------- | ----------------------------------- |
| 200  | OK                    | Request succeeded                   |
| 201  | Created               | Resource created successfully       |
| 400  | Bad Request           | Invalid request parameters          |
| 401  | Unauthorized          | Authentication required or failed   |
| 403  | Forbidden             | Insufficient permissions            |
| 404  | Not Found             | Resource not found                  |
| 409  | Conflict              | Resource conflict (e.g., duplicate) |
| 429  | Too Many Requests     | Rate limit exceeded                 |
| 500  | Internal Server Error | Server error                        |
| 503  | Service Unavailable   | Service temporarily unavailable     |

### Common Error Codes

| Error Code          | Description                   | Solution                     |
| ------------------- | ----------------------------- | ---------------------------- |
| AUTH_REQUIRED       | Authentication token missing  | Include Authorization header |
| AUTH_INVALID        | Invalid or expired token      | Login again to get new token |
| VALIDATION_ERROR    | Request validation failed     | Check request parameters     |
| INSUFFICIENT_FUNDS  | Insufficient balance          | Add funds to account         |
| PAYMENT_DECLINED    | Payment declined by processor | Use different payment method |
| RATE_LIMIT_EXCEEDED | Too many requests             | Wait before retrying         |

### Rate Limiting

API requests are rate-limited per user:

- **Default**: 100 requests per minute
- **Authenticated**: 1000 requests per minute
- **Premium**: 10000 requests per minute

Rate limit headers included in responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1609459200
```

## API Versioning

Current API version: **v1**

Future versions will be accessible via URL path:

- v1: `/api/payments` (current)
- v2: `/v2/api/payments` (future)

## SDKs and Libraries

Official SDKs available:

- JavaScript/TypeScript: `npm install @paynext/sdk`
- Python: `pip install paynext-sdk`
- Java: Maven dependency available

Community SDKs:

- Ruby: `paynext-ruby`
- PHP: `paynext-php`
- Go: `paynext-go`

## Next Steps

- [Usage Guide](USAGE.md) - Common usage patterns
- [Examples](examples/) - Working code examples
- [Configuration](CONFIGURATION.md) - API configuration options

---

# Current Implemented Contract (Authoritative)

This section reflects the endpoints as actually implemented in the backend, including
the additions from the endpoint-implementation pass. Where it differs from older
sections above, this section is authoritative. Interactive Swagger UI is available per
service at `/swagger-ui.html` (`/v3/api-docs` for the raw OpenAPI JSON).

All client traffic uses the `/api` prefix at the gateway, which strips `/api` and routes
`/api/users/**` to user-service, `/api/payments/**` to payment-service, and
`/api/notifications/**` to notification-service. Protected endpoints require
`Authorization: Bearer <token>` from `POST /api/users/login`. The token carries a
`userId` claim that payment-service uses to scope data to the caller.

## User service

- `POST /api/users/register` (public): `{username, email, password}` to
  201 `{id, username, name, email, role}`.
- `POST /api/users/login` (public): `{username, password}` to
  200 `{token, user: {id, username, name, email, role}}`.
- `GET /api/users/me` (auth): 200 `{id, username, name, email, role}`.
- `GET /api/users/profile` (auth): 200 merged profile with both web fields
  (`firstName`, `lastName`, `phoneNumber`, `address`, `city`, `postalCode`, `country`)
  and mobile aliases (`name`, `phone`).
- `PUT /api/users/profile` (auth): accepts any subset of `name` (split into first/last)
  or `firstName`/`lastName`, `email`, `phone` or `phoneNumber`, `address`, `city`,
  `postalCode`, `country`. Returns the updated profile.
- `GET /api/users/{id}` (auth): 200 `{id, username, name, email, role}` or 404.

## Payment service

A payment is `{id, userId, amount, paymentDate, status, recipient, description, type}`.

- `POST /api/payments` (auth): `{amount, recipient?, description?, type?}` to 201 payment.
- `GET /api/payments` (auth): array of the caller's payments.
- `GET /api/payments/{id}` (auth): a payment by numeric id, or 404.
- `GET /api/payments/balance` (auth): 200 `{balance, currency}`.
- `GET /api/payments/methods` (auth): array of
  `{id, userId, type, provider, last4, label, default, createdAt}`.
- `POST /api/payments/methods` (auth): `{type, provider, last4?, label?}` to 201 method.
- `POST /api/payments/requests` (auth): `{amount, description?}` to 201
  `{id, userId, amount, description, status, createdAt}`.

## Notification service

- `POST /api/notifications/send`: `{to, message, subject?}`. Used service to service
  after a payment is processed.

## Status codes

200 success, 201 created, 400 validation error (`{error}`), 401 missing or invalid
token, 404 not found.
