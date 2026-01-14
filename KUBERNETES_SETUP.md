# HƯỚNG DẪN TRIỂN KHAI KUBERNETES VỚI KIND

## Tổng Quan

Hướng dẫn này sẽ giúp bạn triển khai ứng dụng microservices lên Kubernetes cluster sử dụng **Kind (Kubernetes in Docker)** với cấu hình:
- **1 Control Plane Node**: Quản lý cluster
- **1 Worker Node**: Chạy workload

## Kiến Trúc Hệ Thống

```
┌─────────────────────────────────────────────────────────┐
│           Kind Cluster (eproject-cluster)               │
│                                                         │
│  ┌──────────────────┐      ┌──────────────────┐       │
│  │ Control Plane    │      │  Worker Node     │       │
│  │  - API Server    │      │  - Auth Service  │       │
│  │  - Scheduler     │      │  - Product Svc   │       │
│  │  - Controller    │      │  - Order Svc     │       │
│  │  - etcd          │      │  - API Gateway   │       │
│  │                  │      │  - MongoDB       │       │
│  │  + API Gateway   │      │  - RabbitMQ      │       │
│  └──────────────────┘      └──────────────────┘       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Services:
1. **Auth Service** (Port 3000): Xác thực và phân quyền người dùng
2. **Product Service** (Port 3001): Quản lý sản phẩm
3. **Order Service** (Port 3002): Xử lý đơn hàng
4. **API Gateway** (Port 3003): Định tuyến và cân bằng tải
5. **MongoDB** (Port 27017): Cơ sở dữ liệu NoSQL
6. **RabbitMQ** (Port 5672/15672): Message broker

## Yêu Cầu Hệ Thống

### 1. Cài Đặt Docker Desktop
- Tải và cài đặt [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Đảm bảo Docker đang chạy: `docker --version`
- Enable Kubernetes trong Docker Desktop (Tùy chọn, nhưng không bắt buộc cho Kind)

### 2. Cài Đặt Kind
```powershell
# Sử dụng Chocolatey
choco install kind

# Hoặc tải trực tiếp
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe C:\Windows\System32\kind.exe

# Kiểm tra
kind --version
```

### 3. Cài Đặt kubectl
```powershell
# Sử dụng Chocolatey
choco install kubernetes-cli

# Hoặc tải trực tiếp
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
Move-Item .\kubectl.exe C:\Windows\System32\

# Kiểm tra
kubectl version --client
```

## Bước 1: Build Docker Images

Trước khi triển khai lên Kubernetes, cần build các Docker images cho các services:

```powershell
# Di chuyển vào thư mục dự án
cd D:\test_kubernetes

# Build Auth Service
docker build -t auth-service:latest ./auth

# Build Product Service
docker build -t product-service:latest ./product

# Build Order Service
docker build -t order-service:latest ./order

# Build API Gateway
docker build -t api-gateway:latest ./api-gateway

# Kiểm tra images đã build
docker images | Select-String "auth-service|product-service|order-service|api-gateway"
```

## Bước 2: Tạo Kind Cluster

```powershell
# Tạo cluster từ file cấu hình
kind create cluster --config=kind-config.yaml --name eproject-cluster

# Kiểm tra cluster đã được tạo
kind get clusters

# Kiểm tra context kubectl
kubectl config current-context

# Xem các nodes
kubectl get nodes
```

**Kết quả mong đợi:**
```
NAME                            STATUS   ROLES           AGE   VERSION
eproject-cluster-control-plane  Ready    control-plane   30s   v1.27.3
eproject-cluster-worker         Ready    <none>          20s   v1.27.3
```

## Bước 3: Load Docker Images vào Kind

Kind cluster không tự động truy cập được các Docker images local, cần load thủ công:

```powershell
# Load tất cả images vào cluster
kind load docker-image auth-service:latest --name eproject-cluster
kind load docker-image product-service:latest --name eproject-cluster
kind load docker-image order-service:latest --name eproject-cluster
kind load docker-image api-gateway:latest --name eproject-cluster

# Kiểm tra images trong cluster
docker exec -it eproject-cluster-control-plane crictl images | Select-String "auth-service|product-service|order-service|api-gateway"
```

## Bước 4: Deploy Infrastructure (MongoDB & RabbitMQ)

```powershell
# Deploy ConfigMap và Secrets
kubectl apply -f k8s/configmap-secret.yaml

# Deploy MongoDB
kubectl apply -f k8s/mongodb.yaml

# Deploy RabbitMQ
kubectl apply -f k8s/rabbitmq.yaml

# Kiểm tra deployment
kubectl get pods
kubectl get services
kubectl get pv
kubectl get pvc

# Đợi cho MongoDB và RabbitMQ sẵn sàng (có thể mất 1-2 phút)
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s
```

## Bước 5: Deploy Microservices

```powershell
# Deploy Auth Service
kubectl apply -f k8s/auth-service.yaml

# Deploy Product Service
kubectl apply -f k8s/product-service.yaml

# Deploy Order Service
kubectl apply -f k8s/order-service.yaml

# Deploy API Gateway
kubectl apply -f k8s/api-gateway.yaml

# Kiểm tra tất cả pods
kubectl get pods -w
# Nhấn Ctrl+C để thoát chế độ watch
```

**Đợi tất cả pods ở trạng thái Running:**
```
NAME                              READY   STATUS    RESTARTS   AGE
auth-service-xxxxxxxxx-xxxxx      1/1     Running   0          30s
auth-service-xxxxxxxxx-xxxxx      1/1     Running   0          30s
product-service-xxxxxxxxx-xxxxx   1/1     Running   0          25s
product-service-xxxxxxxxx-xxxxx   1/1     Running   0          25s
order-service-xxxxxxxxx-xxxxx     1/1     Running   0          20s
order-service-xxxxxxxxx-xxxxx     1/1     Running   0          20s
api-gateway-xxxxxxxxx-xxxxx       1/1     Running   0          15s
api-gateway-xxxxxxxxx-xxxxx       1/1     Running   0          15s
mongodb-xxxxxxxxx-xxxxx           1/1     Running   0          2m
rabbitmq-xxxxxxxxx-xxxxx          1/1     Running   0          2m
```

## Bước 6: Kiểm Tra Services

```powershell
# Xem tất cả services
kubectl get services

# Kiểm tra endpoints
kubectl get endpoints
```

**Kết quả services:**
```
NAME              TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
auth-service      NodePort   10.96.x.x       <none>        3000:30000/TCP    1m
product-service   NodePort   10.96.x.x       <none>        3001:30001/TCP    1m
order-service     NodePort   10.96.x.x       <none>        3002:30002/TCP    1m
api-gateway       NodePort   10.96.x.x       <none>        3003:30003/TCP    1m
mongodb           NodePort   10.96.x.x       <none>        27017:30017/TCP   2m
rabbitmq          NodePort   10.96.x.x       <none>        5672:30672/TCP,   2m
                                                            15672:31672/TCP
```

## Bước 7: Test Ứng Dụng

### Cách 1: Test với PowerShell/cURL

#### Truy cập các services từ localhost:

```powershell
# Test API Gateway
curl http://localhost:3003/health

# Test Auth Service
curl http://localhost:3000/health

# Test Product Service
curl http://localhost:3001/health

# Test Order Service
curl http://localhost:3002/health

# Truy cập RabbitMQ Management UI
Start-Process "http://localhost:15672"
# Username: admin
# Password: admin
```

#### Test API đầy đủ:

```powershell
# 1. Đăng ký user mới
$registerBody = @{
    username = "testuser"
    password = "testpass123"
    email = "test@example.com"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3003/auth/register" `
    -Method POST `
    -ContentType "application/json" `
    -Body $registerBody

# 2. Đăng nhập
$loginBody = @{
    username = "testuser"
    password = "testpass123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri "http://localhost:3003/auth/login" `
    -Method POST `
    -ContentType "application/json" `
    -Body $loginBody

$token = $loginResponse.token
Write-Host "Token: $token"

# 3. Lấy danh sách products
Invoke-RestMethod -Uri "http://localhost:3003/product" `
    -Method GET `
    -Headers @{Authorization = "Bearer $token"}
```

### Cách 2: Test với Postman

#### Setup Postman:

1. **Tải và cài đặt Postman** (nếu chưa có): https://www.postman.com/downloads/

2. **Tạo Collection mới** cho project:
   - Mở Postman
   - Click "New" → "Collection"
   - Đặt tên: "Kubernetes Microservices"

#### Test 1: Health Checks

**1.1. API Gateway Health Check**
- Method: `GET`
- URL: `http://localhost:3003/health`
- Click "Send"
- Expected Response:
  ```json
  {
    "status": "ok",
    "service": "api-gateway"
  }
  ```

**1.2. Auth Service Health Check**
- Method: `GET`
- URL: `http://localhost:3000/health`
- Expected Response:
  ```json
  {
    "status": "ok",
    "service": "auth"
  }
  ```

**1.3. Product Service Health Check**
- Method: `GET`
- URL: `http://localhost:3001/health`

**1.4. Order Service Health Check**
- Method: `GET`
- URL: `http://localhost:3002/health`

#### Test 2: User Authentication Flow

**2.1. Register User (Đăng ký)**
- Method: `POST`
- URL: `http://localhost:3003/auth/register`
- Headers:
  - `Content-Type`: `application/json`
- Body (raw JSON):
  ```json
  {
    "username": "testuser",
    "password": "testpass123",
    "email": "test@example.com"
  }
  ```
- Click "Send"
- Expected Response (201 Created):
  ```json
  {
    "_id": "...",
    "username": "testuser",
    "email": "test@example.com"
  }
  ```

**2.2. Login User (Đăng nhập)**
- Method: `POST`
- URL: `http://localhost:3003/auth/login`
- Headers:
  - `Content-Type`: `application/json`
- Body (raw JSON):
  ```json
  {
    "username": "testuser",
    "password": "testpass123"
  }
  ```
- Click "Send"
- Expected Response (200 OK):
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
  ```
- **⚠️ QUAN TRỌNG**: Copy token từ response để sử dụng cho các request tiếp theo

#### Test 3: Product APIs (Authenticated)

**Setup Authentication cho các requests:**
- Trong Postman, vào tab "Authorization"
- Type: chọn "Bearer Token"
- Token: paste token từ bước Login

**Hoặc thêm Header thủ công:**
- Tab "Headers"
- Key: `Authorization`
- Value: `Bearer <your-token-here>`

**3.1. Get All Products**
- Method: `GET`
- URL: `http://localhost:3003/products`
- Headers:
  - `Authorization`: `Bearer <token-từ-login>`
- Click "Send"

**3.2. Get Product by ID**
- Method: `GET`
- URL: `http://localhost:3003/products/<product-id>`
- Headers:
  - `Authorization`: `Bearer <token>`

**3.3. Create Product** (nếu có endpoint)
- Method: `POST`
- URL: `http://localhost:3003/products`
- Headers:
  - `Authorization`: `Bearer <token>`
  - `Content-Type`: `application/json`
- Body (raw JSON):
  ```json
  {
    "name": "Sample Product",
    "price": 99.99,
    "description": "Product description"
  }
  ```

#### Test 4: Order APIs (Authenticated)

**4.1. Create Order**
- Method: `POST`
- URL: `http://localhost:3003/orders`
- Headers:
  - `Authorization`: `Bearer <token>`
  - `Content-Type`: `application/json`
- Body (raw JSON):
  ```json
  {
    "productId": "<product-id>",
    "quantity": 2
  }
  ```

**4.2. Get User Orders**
- Method: `GET`
- URL: `http://localhost:3003/orders`
- Headers:
  - `Authorization`: `Bearer <token>`

#### Tips Postman:

1. **Sử dụng Environment Variables:**
   - Click vào ⚙️ (Settings) → "Environments"
   - Tạo environment mới: "Kubernetes Local"
   - Thêm variables:
     - `base_url`: `http://localhost:3003`
     - `auth_token`: `<để-trống>`
   - Sử dụng trong requests: `{{base_url}}/auth/login`

2. **Auto-save Token bằng Test Script:**
   - Trong request "Login", vào tab "Tests"
   - Thêm script:
     ```javascript
     var jsonData = pm.response.json();
     pm.environment.set("auth_token", jsonData.token);
     ```
   - Token sẽ tự động lưu vào environment variable
   - Sử dụng: `{{auth_token}}` trong Authorization header

3. **Save Collection:**
   - Sau khi tạo xong các requests
   - Right-click collection → "Export"
   - Lưu file JSON để share hoặc backup

4. **Organize Requests:**
   - Tạo folders trong collection:
     - 📁 Health Checks
     - 📁 Authentication
     - 📁 Products
     - 📁 Orders
   - Kéo thả requests vào folders tương ứng

#### Test RabbitMQ Management UI:

- URL: `http://localhost:15672`
- Username: `admin`
- Password: `admin`
- Vào tab "Queues" để xem message queues
- Vào tab "Connections" để xem active connections

## Các Lệnh Quản Lý Hữu Ích

### Xem logs:
```powershell
# Logs của một pod cụ thể
kubectl logs <pod-name>

# Logs của service (tất cả replicas)
kubectl logs -l app=auth-service

# Follow logs real-time
kubectl logs -f <pod-name>

# Logs của container trước đó (nếu pod restart)
kubectl logs <pod-name> --previous
```

### Kiểm tra chi tiết:
```powershell
# Mô tả pod
kubectl describe pod <pod-name>

# Mô tả service
kubectl describe service <service-name>

# Xem events
kubectl get events --sort-by=.metadata.creationTimestamp

# Kiểm tra resource usage
kubectl top nodes
kubectl top pods
```

### Exec vào container:
```powershell
# Exec vào pod
kubectl exec -it <pod-name> -- /bin/sh

# Chạy lệnh trong pod
kubectl exec <pod-name> -- env
```

### Scale services:
```powershell
# Scale up/down
kubectl scale deployment auth-service --replicas=3

# Kiểm tra
kubectl get deployments
```

### Restart services:
```powershell
# Restart bằng cách xóa pods (sẽ tự tạo lại)
kubectl rollout restart deployment auth-service

# Hoặc xóa pod cụ thể
kubectl delete pod <pod-name>
```

## Troubleshooting

### 1. Pod không start được

```powershell
# Xem mô tả chi tiết
kubectl describe pod <pod-name>

# Xem logs
kubectl logs <pod-name>

# Kiểm tra events
kubectl get events --field-selector involvedObject.name=<pod-name>
```

### 2. Image pull error

```powershell
# Kiểm tra images trong cluster
docker exec -it eproject-cluster-control-plane crictl images

# Load lại image nếu cần
kind load docker-image <image-name>:latest --name eproject-cluster
```

### 3. Service không kết nối được

```powershell
# Kiểm tra endpoints
kubectl get endpoints <service-name>

# Test kết nối từ bên trong cluster
kubectl run test-pod --rm -it --image=busybox -- sh
# Trong pod: wget -O- http://auth-service:3000/health
```

### 4. PersistentVolume issues

```powershell
# Kiểm tra PV và PVC
kubectl get pv
kubectl get pvc

# Xem chi tiết
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name>
```

### 5. Health check failures

Nếu pods bị restart liên tục do liveness/readiness probe fail:

1. Kiểm tra logs của pod
2. Đảm bảo service có endpoint `/health`
3. Có thể tạm thời comment liveness/readiness probe để debug

## Dọn Dẹp

### Xóa deployments nhưng giữ cluster:
```powershell
# Xóa tất cả deployments
kubectl delete -f k8s/

# Hoặc xóa từng thành phần
kubectl delete -f k8s/api-gateway.yaml
kubectl delete -f k8s/order-service.yaml
kubectl delete -f k8s/product-service.yaml
kubectl delete -f k8s/auth-service.yaml
kubectl delete -f k8s/rabbitmq.yaml
kubectl delete -f k8s/mongodb.yaml
kubectl delete -f k8s/configmap-secret.yaml
```

### Xóa hoàn toàn cluster:
```powershell
# Xóa cluster
kind delete cluster --name eproject-cluster

# Kiểm tra
kind get clusters
```

## Update Code và Redeploy

Khi bạn thay đổi code và muốn update:

```powershell
# 1. Rebuild image
docker build -t auth-service:latest ./auth

# 2. Load vào cluster
kind load docker-image auth-service:latest --name eproject-cluster

# 3. Restart deployment (sẽ pull image mới)
kubectl rollout restart deployment auth-service

# 4. Theo dõi rollout
kubectl rollout status deployment auth-service
```

## Lưu Ý Quan Trọng

1. **imagePullPolicy: Never**: Các deployment sử dụng images local, không pull từ registry
2. **NodePort**: Services dùng NodePort để expose ra ngoài thông qua port mapping của Kind
3. **Health Checks**: Đảm bảo các services có endpoint `/health` để liveness/readiness probes hoạt động
4. **Resources**: Đã set resource limits để tránh cluster quá tải
5. **Replicas**: Mỗi service có 2 replicas cho high availability

## Tham Khảo Thêm

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Ports Mapping Summary

| Service | Container Port | NodePort | Host Port |
|---------|---------------|----------|-----------|
| Auth Service | 3000 | 30000 | 3000 |
| Product Service | 3001 | 30001 | 3001 |
| Order Service | 3002 | 30002 | 3002 |
| API Gateway | 3003 | 30003 | 3003 |
| MongoDB | 27017 | 30017 | 27017 |
| RabbitMQ AMQP | 5672 | 30672 | 5672 |
| RabbitMQ Management | 15672 | 31672 | 15672 |

---

**Chúc bạn triển khai thành công! 🚀**
