# QUICK START - KUBERNETES VỚI KIND

## Cài Đặt Nhanh

### 1. Yêu cầu
- Docker Desktop (đang chạy)
- Kind
- kubectl

```powershell
# Cài đặt Kind và kubectl (nếu chưa có)
choco install kind kubernetes-cli
```

### 2. Deploy Tự Động

Sử dụng script PowerShell tự động:

```powershell
# Deploy toàn bộ
.\deploy-k8s.ps1
```

Script sẽ tự động:
- ✅ Build tất cả Docker images
- ✅ Tạo Kind cluster với 2 nodes
- ✅ Load images vào cluster
- ✅ Deploy MongoDB & RabbitMQ
- ✅ Deploy 4 microservices
- ✅ Expose các ports cần thiết

### 3. Deploy Thủ Công (Nếu muốn)

```powershell
# Build images
docker build -t auth-service:latest ./auth
docker build -t product-service:latest ./product
docker build -t order-service:latest ./order
docker build -t api-gateway:latest ./api-gateway

# Tạo cluster
kind create cluster --config=kind-config.yaml --name eproject-cluster

# Load images
kind load docker-image auth-service:latest --name eproject-cluster
kind load docker-image product-service:latest --name eproject-cluster
kind load docker-image order-service:latest --name eproject-cluster
kind load docker-image api-gateway:latest --name eproject-cluster

# Deploy
kubectl apply -f k8s/configmap-secret.yaml
kubectl apply -f k8s/mongodb.yaml
kubectl apply -f k8s/rabbitmq.yaml
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/product-service.yaml
kubectl apply -f k8s/order-service.yaml
kubectl apply -f k8s/api-gateway.yaml
```

### 4. Kiểm Tra

```powershell
# Xem pods
kubectl get pods

# Xem services
kubectl get services

# Xem logs
kubectl logs -l app=auth-service
```

### 5. Test API

```powershell
# Test health checks
curl http://localhost:3003/health
curl http://localhost:3000/health
curl http://localhost:3001/health
curl http://localhost:3002/health

# RabbitMQ Management
Start-Process "http://localhost:15672"  # admin/admin
```

## Các Lệnh Hữu Ích

```powershell
# Xem logs real-time
kubectl logs -f <pod-name>

# Exec vào pod
kubectl exec -it <pod-name> -- /bin/sh

# Restart service
kubectl rollout restart deployment auth-service

# Scale service
kubectl scale deployment auth-service --replicas=3

# Xem events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Update Code

Sau khi sửa code:

```powershell
# 1. Rebuild image
docker build -t auth-service:latest ./auth

# 2. Load vào cluster
kind load docker-image auth-service:latest --name eproject-cluster

# 3. Restart deployment
kubectl rollout restart deployment auth-service
```

## Dọn Dẹp

```powershell
# Sử dụng script
.\cleanup-k8s.ps1

# Hoặc xóa thủ công
kind delete cluster --name eproject-cluster
```

## Endpoints

| Service | URL |
|---------|-----|
| API Gateway | http://localhost:3003 |
| Auth Service | http://localhost:3000 |
| Product Service | http://localhost:3001 |
| Order Service | http://localhost:3002 |
| RabbitMQ Management | http://localhost:15672 |
| MongoDB | mongodb://localhost:27017 |

## Troubleshooting

### Pods không start
```powershell
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Service không kết nối
```powershell
kubectl get endpoints
kubectl exec -it <pod-name> -- wget -O- http://service-name:port/health
```

### Load image lỗi
```powershell
# Kiểm tra image đã build
docker images | Select-String "service"

# Load lại
kind load docker-image <image-name>:latest --name eproject-cluster
```

---

📖 **Chi tiết đầy đủ**: Xem [KUBERNETES_SETUP.md](KUBERNETES_SETUP.md)
