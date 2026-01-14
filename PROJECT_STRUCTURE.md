# CẤU TRÚC DỰ ÁN - KUBERNETES

```
test_kubernetes/
│
├── 📁 auth/                          # Auth Service
│   ├── Dockerfile
│   ├── package.json
│   ├── index.js
│   └── src/
│       ├── app.js                    # ✓ Health check added
│       ├── config/
│       ├── controllers/
│       ├── middlewares/
│       ├── models/
│       ├── repositories/
│       ├── routes/
│       ├── services/
│       └── test/
│
├── 📁 product/                       # Product Service
│   ├── Dockerfile
│   ├── package.json
│   ├── index.js
│   └── src/
│       ├── app.js                    # ✓ Health check added
│       ├── config.js
│       ├── controllers/
│       ├── models/
│       ├── repositories/
│       ├── routes/
│       ├── services/
│       ├── test/
│       └── utils/
│
├── 📁 order/                         # Order Service
│   ├── Dockerfile
│   ├── package.json
│   ├── index.js
│   └── src/
│       ├── app.js                    # ✓ Health check added
│       ├── config.js
│       ├── controllers/
│       ├── models/
│       ├── repositories/
│       ├── routes/
│       ├── services/
│       └── utils/
│
├── 📁 api-gateway/                   # API Gateway
│   ├── Dockerfile
│   ├── package.json
│   └── index.js                      # ✓ Health check added
│
├── 📁 k8s/                           # ⭐ Kubernetes Manifests
│   ├── configmap-secret.yaml        # ConfigMaps & Secrets
│   ├── mongodb.yaml                 # MongoDB Deployment & Service
│   ├── rabbitmq.yaml                # RabbitMQ Deployment & Service
│   ├── auth-service.yaml            # Auth Service Deployment & Service
│   ├── product-service.yaml         # Product Service Deployment & Service
│   ├── order-service.yaml           # Order Service Deployment & Service
│   └── api-gateway.yaml             # API Gateway Deployment & Service
│
├── 📄 kind-config.yaml               # ⭐ Kind Cluster Configuration
│                                     #    - 1 Control Plane Node
│                                     #    - 1 Worker Node
│                                     #    - Port Mappings
│
├── 📄 docker-compose.yml             # Docker Compose Configuration
│
├── 🔧 deploy-k8s.ps1                 # ⭐ Automated Deployment Script
├── 🔧 cleanup-k8s.ps1                # ⭐ Cleanup Script
├── 🔧 test-k8s-api.ps1               # ⭐ API Testing Script
│
├── 📖 README.md                      # ✓ Updated - Main Documentation
├── 📖 KUBERNETES_SETUP.md            # ⭐ Complete K8s Setup Guide
├── 📖 QUICK_START_K8S.md             # ⭐ Quick Start Guide
├── 📖 KUBECTL_CHEATSHEET.md          # ⭐ Kubectl Commands Reference
├── 📖 DOCKER_CICD_SETUP.md           # Docker Compose Setup
├── 📖 GITHUB_SECRETS_SETUP.md        # GitHub Secrets Setup
├── 📖 QUICK_START.md                 # Docker Quick Start
└── 📖 test_api.md                    # API Testing Guide

```

## Các File Mới Được Tạo

### ⭐ Kubernetes Configuration Files

1. **kind-config.yaml**
   - Cấu hình Kind cluster với 2 nodes
   - Port mappings cho tất cả services
   - Ingress-ready configuration

2. **k8s/** - Thư mục chứa tất cả Kubernetes manifests
   - `configmap-secret.yaml`: Environment variables và secrets
   - `mongodb.yaml`: MongoDB với PersistentVolume
   - `rabbitmq.yaml`: RabbitMQ với PersistentVolume
   - `auth-service.yaml`: Auth service với 2 replicas
   - `product-service.yaml`: Product service với 2 replicas
   - `order-service.yaml`: Order service với 2 replicas
   - `api-gateway.yaml`: API Gateway với 2 replicas

### ⭐ Automation Scripts

3. **deploy-k8s.ps1**
   - Tự động build Docker images
   - Tạo Kind cluster
   - Load images vào cluster
   - Deploy tất cả services
   - Hiển thị trạng thái

4. **cleanup-k8s.ps1**
   - Xóa deployments hoặc toàn bộ cluster
   - Interactive menu
   - Safe cleanup

5. **test-k8s-api.ps1**
   - Test health checks
   - Test user registration & login
   - Test authenticated API calls
   - Verify all services

### ⭐ Documentation

6. **KUBERNETES_SETUP.md**
   - Hướng dẫn chi tiết từng bước
   - Yêu cầu hệ thống
   - Troubleshooting guide
   - Best practices

7. **QUICK_START_K8S.md**
   - Quick start guide
   - Essential commands
   - Common use cases

8. **KUBECTL_CHEATSHEET.md**
   - Tất cả kubectl commands hữu ích
   - Troubleshooting commands
   - Advanced debugging

### ✓ Updated Files

9. **Service Health Checks**
   - `auth/src/app.js`: Added `/health` endpoint
   - `product/src/app.js`: Added `/health` endpoint
   - `order/src/app.js`: Added `/health` endpoint
   - `api-gateway/index.js`: Added `/health` endpoint

10. **README.md**
    - Updated with Kubernetes deployment options
    - Links to all documentation

## Kubernetes Resources

### Deployments
- **auth-service**: 2 replicas, 256Mi-512Mi RAM, 100m-200m CPU
- **product-service**: 2 replicas, 256Mi-512Mi RAM, 100m-200m CPU
- **order-service**: 2 replicas, 256Mi-512Mi RAM, 100m-200m CPU
- **api-gateway**: 2 replicas, 256Mi-512Mi RAM, 100m-200m CPU
- **mongodb**: 1 replica, 512Mi-1Gi RAM, 250m-500m CPU
- **rabbitmq**: 1 replica, 512Mi-1Gi RAM, 250m-500m CPU

### Services (NodePort)
- **auth-service**: Port 3000 → NodePort 30000
- **product-service**: Port 3001 → NodePort 30001
- **order-service**: Port 3002 → NodePort 30002
- **api-gateway**: Port 3003 → NodePort 30003
- **mongodb**: Port 27017 → NodePort 30017
- **rabbitmq**: 
  - AMQP Port 5672 → NodePort 30672
  - Management Port 15672 → NodePort 31672

### Persistent Storage
- **mongodb-pv/pvc**: 5Gi storage for MongoDB data
- **rabbitmq-pv/pvc**: 2Gi storage for RabbitMQ data

### ConfigMaps & Secrets
- **app-config**: Chứa tất cả configuration không nhạy cảm
- **app-secrets**: Chứa JWT secrets, DB URIs, RabbitMQ URIs

## Features

### ✅ High Availability
- Multiple replicas cho mỗi service
- Automatic pod rescheduling
- Load balancing giữa replicas

### ✅ Health Monitoring
- Liveness probes: Tự động restart pod khi unhealthy
- Readiness probes: Không route traffic đến pod chưa sẵn sàng
- Health check endpoints trên tất cả services

### ✅ Resource Management
- CPU và Memory requests/limits
- Tránh resource starvation
- Predictable performance

### ✅ Data Persistence
- PersistentVolumes cho MongoDB
- PersistentVolumes cho RabbitMQ
- Dữ liệu không mất khi pod restart

### ✅ Configuration Management
- ConfigMaps cho app configuration
- Secrets cho sensitive data
- Easy to update without rebuilding images

### ✅ Service Discovery
- Kubernetes DNS tự động
- Services có thể gọi nhau bằng tên
- No hardcoded IPs

## Deployment Workflow

```
1. Build Images
   ↓
2. Create Kind Cluster (2 nodes)
   ↓
3. Load Images to Cluster
   ↓
4. Deploy ConfigMaps & Secrets
   ↓
5. Deploy Infrastructure (MongoDB, RabbitMQ)
   ↓
6. Deploy Microservices (Auth, Product, Order, Gateway)
   ↓
7. Verify Deployment
   ↓
8. Test APIs
```

## Access Points

| Service | Internal URL | External URL |
|---------|-------------|--------------|
| API Gateway | http://api-gateway:3003 | http://localhost:3003 |
| Auth Service | http://auth-service:3000 | http://localhost:3000 |
| Product Service | http://product-service:3001 | http://localhost:3001 |
| Order Service | http://order-service:3002 | http://localhost:3002 |
| MongoDB | mongodb://mongodb:27017 | mongodb://localhost:27017 |
| RabbitMQ AMQP | amqp://rabbitmq:5672 | amqp://localhost:5672 |
| RabbitMQ Mgmt | http://rabbitmq:15672 | http://localhost:15672 |

## Next Steps

1. **Bắt đầu**: Chạy `.\deploy-k8s.ps1`
2. **Kiểm tra**: Chạy `.\test-k8s-api.ps1`
3. **Monitoring**: `kubectl get pods -w`
4. **Logs**: `kubectl logs -l app=auth-service`
5. **Cleanup**: `.\cleanup-k8s.ps1`

---

**Chúc bạn triển khai thành công! 🚀**
