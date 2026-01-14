# Microservices E-Commerce Project

## Overview
This project implements a microservices architecture with multiple deployment options:
- **Docker Compose**: Quick local development
- **Kubernetes (Kind)**: Production-like local environment with orchestration
- **CI/CD**: Automated testing with GitHub Actions

## Services
- **Auth Service** (Port 3000): User authentication and authorization
- **Product Service** (Port 3001): Product management and order creation
- **Order Service** (Port 3002): Order processing and message queue consumption
- **API Gateway** (Port 3003): Request routing and load balancing
- **MongoDB**: NoSQL database for all services
- **RabbitMQ**: Message broker for inter-service communication

## Deployment Options

### 🚀 Quick Start - Docker Compose
```powershell
# Start all services
docker compose up -d

# Stop all services
docker compose down
```

See [DOCKER_CICD_SETUP.md](DOCKER_CICD_SETUP.md) for detailed setup.

### ☸️ Kubernetes with Kind (Recommended for Production-like Testing)
```powershell
# Automated deployment
.\deploy-k8s.ps1

# Manual deployment
kind create cluster --config=kind-config.yaml
kubectl apply -f k8s/
```

**Features:**
- ✅ 2-node cluster (1 control-plane + 1 worker)
- ✅ High availability with multiple replicas
- ✅ Health checks and auto-restart
- ✅ Resource limits and requests
- ✅ ConfigMaps and Secrets management
- ✅ Persistent storage for MongoDB and RabbitMQ

See **[KUBERNETES_SETUP.md](KUBERNETES_SETUP.md)** for comprehensive guide or **[QUICK_START_K8S.md](QUICK_START_K8S.md)** for quick start.

## Testing

### Local Testing

#### Prerequisites
- Node.js 18
- MongoDB running on localhost:27017
- Environment variables set up

#### Setup Environment
```bash
# Auth service .env
echo "MONGODB_AUTH_URI=mongodb://localhost:27017/auth_test" >> auth/.env
echo "JWT_SECRET=your_jwt_secret_here" >> auth/.env

# Product service .env  
echo "JWT_SECRET=your_jwt_secret_here" >> product/.env
echo "MONGODB_PRODUCT_URI=mongodb://localhost:27017/product_test" >> product/.env
echo "LOGIN_TEST_USER=testuser" >> product/.env
echo "LOGIN_TEST_PASSWORD=testpass" >> product/.env
```

#### Run Tests
```bash
# Install dependencies
npm ci
cd auth && npm ci && cd ..
cd product && npm ci && cd ..

# Start auth service
cd auth
npm start &
cd ..

# Wait for service to be ready
sleep 5

# Run auth tests
cd auth
npm test
cd ..

# Run product tests
cd product
npm test
cd ..
```

### GitHub Actions CI/CD

The CI/CD pipeline automatically runs on push and pull requests:

1. **Environment Setup**: Sets up Node.js 18 and MongoDB
2. **Dependencies**: Installs all required packages  
3. **Auth Tests**: Runs comprehensive tests for auth service
4. **Product Tests**: Starts auth service, creates test user, runs product tests
5. **Cleanup**: Terminates all processes

#### Required Secrets
Configure these in your GitHub repository settings:
- `JWT_SECRET`: Secret key for JWT token generation
- `LOGIN_TEST_USER`: Username for test user (e.g., "testuser")
- `LOGIN_TEST_PASSWORD`: Password for test user (e.g., "testpass")

## Test Coverage

### Auth Service Tests
- ✅ User registration (success and duplicate username)
- ✅ User login (success and invalid credentials)
- ✅ Protected route access with JWT authentication
- ✅ User profile retrieval
- ✅ Input validation and error handling
- ✅ Authentication middleware testing

### Product Service Tests
- ✅ Product creation (success and validation errors)
- ✅ Product listing retrieval
- ✅ Order creation with validation
- ✅ Authentication required for all endpoints
- ✅ Input validation for order data
- ✅ Error handling for invalid requests

## File Structure
```
├── test.yml                    # GitHub Actions CI/CD pipeline
├── auth/
│   ├── src/test/
│   │   └── authController.test.js
│   └── package.json
├── product/
│   ├── src/test/
│   │   └── product.test.js
│   └── package.json
└── package.json
```

## Notes
- Tests use local MongoDB instances for isolation
- Auth service must be running before product tests
- All tests include proper cleanup procedures
- CI/CD pipeline uses Ubuntu latest with Docker services