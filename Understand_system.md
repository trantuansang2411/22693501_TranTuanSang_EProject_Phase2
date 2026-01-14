# HIỂU HỆ THỐNG - KUBERNETES TRÊN DOCKER LOCAL

## Mục Lục
1. [Kind (Kubernetes in Docker) là gì?](#1-kind-kubernetes-in-docker-là-gì)
2. [Kiến trúc hệ thống](#2-kiến-trúc-hệ-thống)
3. [Các thành phần Kubernetes](#3-các-thành-phần-kubernetes)
4. [Luồng triển khai](#4-luồng-triển-khai)
5. [Networking - Mạng trong Kubernetes](#5-networking---mạng-trong-kubernetes)
6. [Storage - Lưu trữ dữ liệu](#6-storage---lưu-trữ-dữ-liệu)
7. [Service Discovery - Tìm kiếm dịch vụ](#7-service-discovery---tìm-kiếm-dịch-vụ)
8. [ConfigMaps và Secrets](#8-configmaps-và-secrets)
9. [Health Checks và Auto-healing](#9-health-checks-và-auto-healing)
10. [Scaling và Load Balancing](#10-scaling-và-load-balancing)
11. [Luồng hoạt động của ứng dụng](#11-luồng-hoạt-động-của-ứng-dụng)
12. [So sánh Docker Compose vs Kubernetes](#12-so-sánh-docker-compose-vs-kubernetes)

---

## 1. Kind (Kubernetes in Docker) là gì?

### Khái niệm

**Kind** (Kubernetes IN Docker) là công cụ cho phép chạy **Kubernetes cluster bên trong Docker containers**.

```
┌─────────────────────────────────────────────┐
│         Docker Desktop (Host)               │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │    Kind Cluster                       │ │
│  │                                       │ │
│  │  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │ Container 1  │  │ Container 2  │  │ │
│  │  │ Control-Plane│  │   Worker     │  │ │
│  │  │   (Node)     │  │   (Node)     │  │ │
│  │  │              │  │              │  │ │
│  │  │ ┌──────────┐ │  │ ┌──────────┐ │  │ │
│  │  │ │  Pods    │ │  │ │  Pods    │ │  │ │
│  │  │ └──────────┘ │  │ └──────────┘ │  │ │
│  │  └──────────────┘  └──────────────┘  │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Tại sao dùng Kind?

1. **Môi trường giống Production**: Kubernetes thật, không phải giả lập
2. **Dễ dàng**: Chạy trên Docker Desktop, không cần cài đặt phức tạp
3. **Isolated**: Mỗi cluster độc lập, không ảnh hưởng hệ thống
4. **Học tập & Testing**: Hoàn hảo để học Kubernetes và test

### Kind vs Minikube vs Docker Desktop Kubernetes

| Tính năng | Kind | Minikube | Docker Desktop K8s |
|-----------|------|----------|-------------------|
| Chạy trên | Docker containers | VM hoặc Docker | Built-in |
| Multi-node | ✅ Dễ dàng | ⚠️ Phức tạp | ❌ Single node |
| Tốc độ | ⚡ Nhanh | 🐢 Chậm hơn | ⚡ Nhanh |
| Tài nguyên | 💾 Nhẹ | 💾 Nặng | 💾 Nhẹ |
| Production-like | ✅ Cao | ✅ Cao | ⚠️ Thấp |

---

## 2. Kiến Trúc Hệ Thống

### Tổng Quan

```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                           │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              CONTROL PLANE NODE                        │    │
│  │  - API Server (điều phối cluster)                      │    │
│  │  - Scheduler (lên lịch pods)                           │    │
│  │  - Controller Manager (quản lý state)                  │    │
│  │  - etcd (database lưu cluster state)                   │    │
│  │                                                         │    │
│  │  + API Gateway Pod (exposed qua port 3003)             │    │
│  └────────────────────────────────────────────────────────┘    │
│                          │                                      │
│                          ▼                                      │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  WORKER NODE                           │    │
│  │                                                         │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │    │
│  │  │ Auth Pods   │  │Product Pods │  │ Order Pods  │    │    │
│  │  │ (x2 replicas│  │(x2 replicas)│  │(x2 replicas)│    │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │    │
│  │                                                         │    │
│  │  ┌─────────────┐  ┌─────────────┐                      │    │
│  │  │ MongoDB Pod │  │RabbitMQ Pod │                      │    │
│  │  │ + Storage   │  │ + Storage   │                      │    │
│  │  └─────────────┘  └─────────────┘                      │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    Port 3003      Port 3000      Port 3001      Port 27017
   (Gateway)       (Auth)         (Product)      (MongoDB)
```

### Các Layer

1. **Infrastructure Layer**: Docker Desktop
2. **Cluster Layer**: Kind cluster với 2 nodes
3. **Kubernetes Layer**: API Server, Scheduler, Controllers
4. **Application Layer**: Pods chạy microservices
5. **Networking Layer**: Services, DNS, Load Balancing
6. **Storage Layer**: PersistentVolumes

---

## 3. Các Thành Phần Kubernetes

### 3.1. Nodes (Máy chủ)

**Node** là một máy (vật lý hoặc ảo) trong cluster. Trong Kind, mỗi node là một Docker container.

```yaml
# kind-config.yaml
nodes:
  - role: control-plane  # Node master, quản lý cluster
  - role: worker         # Node worker, chạy workload
```

**Control Plane Node** chạy:
- API Server: Nhận requests từ kubectl
- Scheduler: Quyết định pod chạy trên node nào
- Controller Manager: Đảm bảo desired state = actual state
- etcd: Database lưu trữ toàn bộ state

**Worker Node** chạy:
- kubelet: Agent quản lý pods
- kube-proxy: Quản lý networking
- Container runtime: Docker/containerd chạy containers
- Pods: Ứng dụng thực tế

### 3.2. Pods

**Pod** là đơn vị nhỏ nhất trong Kubernetes, chứa 1 hoặc nhiều containers.

```
┌─────────────────────────┐
│      Auth Pod           │
│                         │
│  ┌──────────────────┐   │
│  │  auth-service    │   │ <- Container chạy Node.js app
│  │  Image: auth:v1  │   │
│  │  Port: 3000      │   │
│  └──────────────────┘   │
│                         │
│  Resources:             │
│  - CPU: 100m-200m       │
│  - RAM: 256Mi-512Mi     │
│                         │
│  Environment:           │
│  - PORT=3000            │
│  - JWT_SECRET=xxx       │
│  - MONGODB_URI=xxx      │
└─────────────────────────┘
```

**Tại sao cần Pods?**
- Đóng gói container + config + resources
- Có IP riêng trong cluster
- Có thể restart tự động khi lỗi
- Share network namespace (nếu nhiều containers)

### 3.3. Deployments

**Deployment** quản lý việc tạo và update Pods.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 2  # Tạo 2 pods giống hệt nhau
  selector:
    matchLabels:
      app: auth-service
  template:    # Template để tạo pods
    spec:
      containers:
      - name: auth-service
        image: auth-service:latest
        ports:
        - containerPort: 3000
```

**Deployment làm gì?**
1. **Tạo ReplicaSet**: Đảm bảo luôn có đúng số replicas
2. **Rolling Updates**: Update từng pod một, không downtime
3. **Rollback**: Quay lại version cũ nếu có lỗi
4. **Self-healing**: Tự tạo pod mới nếu pod chết

```
Deployment "auth-service"
    │
    ├── ReplicaSet (quản lý 2 replicas)
    │       │
    │       ├── Pod 1 (auth-service-abc123)
    │       └── Pod 2 (auth-service-def456)
```

**Ví dụ thực tế:**
```bash
# Ban đầu: 2 pods running
Pod: auth-service-abc123  [Running]
Pod: auth-service-def456  [Running]

# Pod 1 bị crash
Pod: auth-service-abc123  [Crashed] ❌

# Deployment tự động tạo pod mới
Pod: auth-service-xyz789  [Starting...]
Pod: auth-service-def456  [Running]

# Sau vài giây
Pod: auth-service-xyz789  [Running] ✅
Pod: auth-service-def456  [Running] ✅
```

### 3.4. Services

**Service** là "địa chỉ cố định" để truy cập Pods (vì Pods có thể thay đổi IP khi restart).

```
Service "auth-service" (ClusterIP: 10.96.1.5)
    │
    ├─────┬─────── Load Balancer
    │     │
    ▼     ▼
Pod 1   Pod 2
(IP: 10.244.1.5) (IP: 10.244.2.3)
```

**Các loại Service:**

1. **ClusterIP** (default): Chỉ truy cập được từ trong cluster
   ```yaml
   type: ClusterIP
   # Dùng cho: MongoDB, RabbitMQ (không cần expose ra ngoài)
   ```

2. **NodePort**: Expose ra ngoài qua port trên Node
   ```yaml
   type: NodePort
   ports:
   - port: 3000        # Port trong cluster
     targetPort: 3000  # Port của container
     nodePort: 30000   # Port trên host (30000-32767)
   # Truy cập: localhost:30000
   ```

3. **LoadBalancer**: Tạo external load balancer (cloud only)
   
4. **ExternalName**: Map tên DNS

**Ví dụ:**
```yaml
# Service cho Auth
apiVersion: v1
kind: Service
metadata:
  name: auth-service
spec:
  type: NodePort
  selector:
    app: auth-service  # Chọn pods có label này
  ports:
  - port: 3000         # Port service trong cluster
    targetPort: 3000   # Port container
    nodePort: 30000    # Port expose ra ngoài
```

**Service làm gì?**
- Cung cấp DNS name: `auth-service.default.svc.cluster.local`
- Load balancing giữa các pods
- Health checking: Chỉ route đến healthy pods
- Port mapping

### 3.5. ConfigMaps

**ConfigMap** lưu trữ configuration không nhạy cảm.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  AUTH_PORT: "3000"
  PRODUCT_PORT: "3001"
  ORDER_SERVICE_URL: "http://order-service:3002"
```

**Sử dụng trong Pod:**
```yaml
env:
- name: PORT
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: AUTH_PORT
```

**Tại sao cần ConfigMap?**
- ✅ Tách config ra khỏi code
- ✅ Thay đổi config không cần rebuild image
- ✅ Share config giữa nhiều pods
- ✅ Dễ quản lý môi trường (dev, staging, prod)

### 3.6. Secrets

**Secret** lưu trữ thông tin nhạy cảm (passwords, tokens, keys).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  jwt-secret: "your_jwt_secret_key_here"
  mongodb-uri: "mongodb://mongodb:27017/auth"
```

**Khác với ConfigMap:**
- ✅ Được encode base64
- ✅ Có thể encrypt at rest
- ✅ Access control chặt chẽ hơn
- ✅ Không hiển thị trong logs

### 3.7. PersistentVolumes (PV) và PersistentVolumeClaims (PVC)

**Vấn đề:** Khi Pod restart, data trong container bị mất.

**Giải pháp:** PersistentVolume - storage tồn tại độc lập với Pod lifecycle.

```
┌──────────────────────────────────┐
│    PersistentVolume (PV)         │
│    - Capacity: 5Gi               │
│    - Path: /mnt/data/mongodb     │
│    - StorageClass: manual        │
└──────────────────────────────────┘
              ▲
              │ Bound (liên kết)
              │
┌──────────────────────────────────┐
│  PersistentVolumeClaim (PVC)     │
│  - Request: 5Gi                  │
│  - AccessMode: ReadWriteOnce     │
└──────────────────────────────────┘
              ▲
              │ Mount
              │
┌──────────────────────────────────┐
│         MongoDB Pod              │
│  volumeMounts:                   │
│    - mountPath: /data/db         │
└──────────────────────────────────┘
```

**Luồng hoạt động:**
1. Admin tạo **PV**: "Tôi có 5GB storage tại path này"
2. User tạo **PVC**: "Tôi cần 5GB storage"
3. Kubernetes **bind** PVC với PV phù hợp
4. Pod **mount** PVC vào container

**Ví dụ thực tế:**
```yaml
# 1. PersistentVolume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
spec:
  capacity:
    storage: 5Gi
  hostPath:
    path: "/mnt/data/mongodb"  # Đường dẫn trên node

# 2. PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
spec:
  resources:
    requests:
      storage: 5Gi

# 3. Sử dụng trong Pod
spec:
  volumes:
  - name: mongodb-storage
    persistentVolumeClaim:
      claimName: mongodb-pvc
  containers:
  - name: mongodb
    volumeMounts:
    - name: mongodb-storage
      mountPath: /data/db  # MongoDB lưu data ở đây
```

**Kết quả:**
- ✅ MongoDB data được lưu tại `/mnt/data/mongodb` trên node
- ✅ Pod restart → data vẫn còn
- ✅ Delete pod → data vẫn còn
- ✅ Chỉ mất data khi delete PV

---

## 4. Luồng Triển Khai

### Bước 1: Build Docker Images

```bash
docker build -t auth-service:latest ./auth
```

**Điều gì xảy ra?**
1. Docker đọc Dockerfile
2. Pull base image (`node:18-alpine`)
3. Copy code vào image
4. Install dependencies
5. Tạo image với tag `auth-service:latest`
6. Lưu image vào Docker local registry

### Bước 2: Tạo Kind Cluster

```bash
kind create cluster --config=kind-config.yaml --name eproject-cluster
```

**Điều gì xảy ra?**

```
1. Kind đọc config file
   ↓
2. Tạo Docker network "kind"
   ↓
3. Pull Kind node image (kindest/node:v1.27.3)
   ↓
4. Tạo container cho Control Plane node
   - Chạy kubeadm init
   - Start API Server, Scheduler, Controller Manager, etcd
   - Cấu hình networking (CNI)
   ↓
5. Tạo container cho Worker node
   - Join cluster bằng token
   - Start kubelet, kube-proxy
   ↓
6. Setup port mappings (3000→30000, 3001→30001, etc.)
   ↓
7. Generate kubeconfig file
   ↓
8. Cluster sẵn sàng!
```

**Kiểm tra:**
```bash
docker ps
# Sẽ thấy 2 containers:
# - eproject-cluster-control-plane
# - eproject-cluster-worker

kubectl get nodes
# Sẽ thấy 2 nodes ở trạng thái Ready
```

### Bước 3: Load Images vào Cluster

```bash
kind load docker-image auth-service:latest --name eproject-cluster
```

**Tại sao cần bước này?**

```
┌─────────────────────────────────────────────┐
│         Docker Desktop                      │
│                                             │
│  Docker Images:                             │
│  - auth-service:latest       ✅ Có         │
│  - product-service:latest    ✅ Có         │
│                                             │
└─────────────────────────────────────────────┘
                    │
                    │ Kind cluster KHÔNG tự động
                    │ truy cập được images này!
                    ▼
┌─────────────────────────────────────────────┐
│      Kind Cluster                           │
│  (containers riêng biệt)                    │
│                                             │
│  Images trong cluster:                      │
│  - auth-service:latest       ❌ Chưa có    │
│                                             │
└─────────────────────────────────────────────┘
```

**kind load làm gì?**
1. Tar image từ Docker local
2. Copy tar file vào Kind node containers
3. Import image vào container runtime của nodes
4. Giờ pods có thể pull image từ local

**Sau khi load:**
```bash
docker exec -it eproject-cluster-control-plane crictl images
# Sẽ thấy auth-service:latest trong danh sách
```

### Bước 4: Deploy ConfigMaps & Secrets

```bash
kubectl apply -f k8s/configmap-secret.yaml
```

**Điều gì xảy ra?**

```
1. kubectl gửi YAML đến API Server
   ↓
2. API Server validate YAML
   ↓
3. Lưu vào etcd database
   ↓
4. ConfigMap & Secret được tạo
   ↓
5. Pods có thể reference chúng
```

### Bước 5: Deploy MongoDB

```bash
kubectl apply -f k8s/mongodb.yaml
```

**Điều gì xảy ra?**

```
1. kubectl apply → API Server
   ↓
2. API Server tạo PV, PVC, Deployment, Service
   ↓
3. Scheduler chọn node để chạy MongoDB pod
   - Kiểm tra resources available
   - Chọn worker node
   ↓
4. kubelet trên worker node:
   - Pull image mongo:6.0 (nếu chưa có)
   - Tạo và mount PersistentVolume
   - Start container
   - Inject environment variables
   ↓
5. Container start:
   - MongoDB khởi động
   - Lắng nghe port 27017
   ↓
6. Health checks:
   - kubelet kiểm tra container health
   - Pod status: Running
   ↓
7. Service được tạo:
   - DNS entry: mongodb.default.svc.cluster.local
   - ClusterIP assigned
   - Endpoints updated
   ↓
8. MongoDB sẵn sàng nhận connections!
```

### Bước 6: Deploy Microservices

```bash
kubectl apply -f k8s/auth-service.yaml
```

**Điều gì xảy ra?**

```
1. Deployment "auth-service" được tạo
   - Replicas: 2
   ↓
2. ReplicaSet được tạo
   ↓
3. Scheduler schedule 2 pods
   - Pod 1 → Control Plane node
   - Pod 2 → Worker node
   (hoặc cả 2 trên Worker, tùy thuộc vào resources)
   ↓
4. kubelet trên mỗi node:
   - Pull image auth-service:latest (từ local)
   - Tạo container với env vars từ ConfigMap/Secret
   - Start container
   ↓
5. Container start:
   - Node.js app khởi động
   - Kết nối MongoDB (qua service name "mongodb")
   - Listen port 3000
   ↓
6. Health checks bắt đầu:
   - Readiness probe: GET /health
   - Liveness probe: GET /health
   ↓
7. Khi probe thành công:
   - Pod status: Ready
   - Service endpoints updated
   - Traffic có thể route đến pod
   ↓
8. Service "auth-service" active
   - 2 pods healthy
   - Load balancing enabled
   - Accessible tại: http://auth-service:3000
                     http://localhost:30000
```

---

## 5. Networking - Mạng trong Kubernetes

### 5.1. Cluster Networking

```
┌────────────────────────────────────────────────┐
│                  Kind Cluster                  │
│         Network: 10.244.0.0/16 (Pod CIDR)      │
│         Services: 10.96.0.0/12 (Service CIDR)  │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Control Plane Node (10.244.0.0/24)     │ │
│  │    Pod: api-gateway (10.244.0.5)        │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  Worker Node (10.244.1.0/24)            │ │
│  │    Pod: auth-1 (10.244.1.5)             │ │
│  │    Pod: auth-2 (10.244.1.6)             │ │
│  │    Pod: product-1 (10.244.1.7)          │ │
│  │    Pod: mongodb (10.244.1.8)            │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  Services:                                     │
│    - auth-service: 10.96.1.5:3000            │
│    - mongodb: 10.96.2.10:27017               │
└────────────────────────────────────────────────┘
        │
        │ Port Mapping (Kind extraPortMappings)
        ▼
┌────────────────────────────────────────────────┐
│            Docker Host (localhost)             │
│                                                │
│   localhost:3000  → NodePort 30000 → auth     │
│   localhost:3003  → NodePort 30003 → gateway  │
│   localhost:27017 → NodePort 30017 → mongodb  │
└────────────────────────────────────────────────┘
```

### 5.2. DNS trong Kubernetes

Kubernetes tự động tạo DNS records cho Services.

**Format:** `<service-name>.<namespace>.svc.cluster.local`

```
Service: auth-service (namespace: default)
  │
  ├── Short name: auth-service
  ├── Namespace-qualified: auth-service.default
  └── FQDN: auth-service.default.svc.cluster.local
```

**Ví dụ trong code:**
```javascript
// Product service kết nối đến Order service
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL;
// Value: "http://order-service:3002"

// Kubernetes DNS resolve:
// order-service → 10.96.3.15 (Service ClusterIP)
```

**Test DNS:**
```bash
kubectl exec -it <pod-name> -- nslookup auth-service
# Output:
# Name: auth-service.default.svc.cluster.local
# Address: 10.96.1.5
```

### 5.3. Service-to-Service Communication

**Ví dụ: API Gateway gọi Auth Service**

```
1. Browser → http://localhost:3003/auth/login
   ↓
2. Request đến Kind control-plane container (port mapping)
   ↓
3. NodePort 30003 → Service "api-gateway"
   ↓
4. Service load-balance → API Gateway Pod
   ↓
5. API Gateway nhận request:
   - Path: /auth/login
   - Proxy to: AUTH_SERVICE_URL
   ↓
6. API Gateway gọi: http://auth-service:3000/login
   ↓
7. Kubernetes DNS:
   - Resolve "auth-service" → 10.96.1.5
   ↓
8. Request đến Service "auth-service"
   ↓
9. Service load-balance → Auth Pod (1 trong 2 replicas)
   ↓
10. Auth Pod xử lý login:
    - Kết nối MongoDB: mongodb:27017
    - DNS resolve: mongodb → 10.96.2.10
    - Query database
    - Generate JWT token
    ↓
11. Response trả về:
    Auth Pod → Service → API Gateway Pod → NodePort → Browser
```

### 5.4. External Access

**3 cách truy cập từ bên ngoài:**

1. **NodePort** (đang dùng)
   ```
   localhost:3000 → Node:30000 → Service → Pod
   ```
   - ✅ Đơn giản
   - ⚠️ Port range giới hạn (30000-32767)

2. **LoadBalancer** (cloud only)
   ```
   External IP → Cloud LB → Service → Pod
   ```
   - ✅ Production-ready
   - ❌ Cần cloud provider

3. **Ingress** (recommended cho production)
   ```
   example.com/auth → Ingress → Service → Pod
   ```
   - ✅ HTTP/HTTPS routing
   - ✅ SSL termination
   - ✅ Path-based routing

---

## 6. Storage - Lưu Trữ Dữ Liệu

### 6.1. Vấn Đề với Container Storage

```
┌─────────────────────────────────────┐
│     MongoDB Pod (v1)                │
│  - Data: /data/db                   │
│  - File: users.bson (100MB)         │
└─────────────────────────────────────┘
         │
         │ Pod crashed!
         ▼
┌─────────────────────────────────────┐
│     MongoDB Pod (v2) - NEW          │
│  - Data: /data/db                   │
│  - File: EMPTY ❌                   │
└─────────────────────────────────────┘
```

**Data mất vì:** Container filesystem là ephemeral (tạm thời)

### 6.2. PersistentVolume Solution

```
Host Filesystem (Kind Node)
/mnt/data/mongodb/
  ├── users.bson
  ├── products.bson
  └── orders.bson
        ▲
        │ Mount
        │
┌───────┴─────────────────────────────┐
│   PersistentVolume (5Gi)            │
│   - hostPath: /mnt/data/mongodb     │
└─────────────────────────────────────┘
        ▲
        │ Claim
        │
┌───────┴─────────────────────────────┐
│   PersistentVolumeClaim (5Gi)       │
└─────────────────────────────────────┘
        ▲
        │ Mount
        │
┌───────┴─────────────────────────────┐
│     MongoDB Pod (ANY version)       │
│  volumeMount: /data/db              │
│  → Points to /mnt/data/mongodb      │
└─────────────────────────────────────┘
```

**Lifecycle:**

```bash
# 1. Tạo PV
kubectl apply -f mongodb.yaml
# PV created: /mnt/data/mongodb exists on node

# 2. MongoDB pod starts
# - PVC binds to PV
# - Volume mounted to /data/db
# - MongoDB writes data → /mnt/data/mongodb

# 3. Pod crashes
kubectl delete pod mongodb-xxx
# - Pod deleted
# - PVC still exists
# - PV still exists
# - Data at /mnt/data/mongodb intact

# 4. New pod starts
# - Same PVC
# - Same PV
# - Mount same /mnt/data/mongodb
# - MongoDB sees existing data ✅
```

### 6.3. Access Modes

```yaml
accessModes:
  - ReadWriteOnce (RWO)  # 1 node, read-write
  - ReadOnlyMany (ROX)   # Nhiều nodes, read-only
  - ReadWriteMany (RWX)  # Nhiều nodes, read-write
```

**MongoDB/RabbitMQ dùng RWO vì:**
- Chỉ 1 pod ghi dữ liệu (stateful)
- Tránh race conditions
- Simpler locking

---

## 7. Service Discovery - Tìm Kiếm Dịch Vụ

### 7.1. Vấn Đề Cần Giải Quyết

```
# Trong Docker Compose:
services:
  auth:
    hostname: auth-service  # Cố định
  product:
    environment:
      AUTH_URL: http://auth-service:3000  # Hardcode OK

# Trong Kubernetes:
Pod: auth-service-abc123 (IP: 10.244.1.5)  # IP thay đổi!
Pod: auth-service-def456 (IP: 10.244.1.6)
Pod: auth-service-xyz789 (IP: 10.244.1.7)  # Replicas khác nhau

# Product service gọi địa chỉ nào? 🤔
```

### 7.2. Solution: Kubernetes Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: auth-service  # Tên cố định, DNS entry
spec:
  selector:
    app: auth-service  # Chọn tất cả pods có label này
  ports:
  - port: 3000
```

**Cách hoạt động:**

```
1. Product service cần gọi Auth
   ↓
2. Code: http://auth-service:3000/login
   ↓
3. DNS lookup: auth-service
   ↓
4. CoreDNS (Kubernetes DNS):
   - Tìm Service tên "auth-service"
   - Return ClusterIP: 10.96.1.5
   ↓
5. Request đến 10.96.1.5:3000
   ↓
6. kube-proxy (trên mỗi node):
   - Intercept request
   - Load-balance đến 1 trong các pod IPs:
     * 10.244.1.5 (auth-pod-1)
     * 10.244.1.6 (auth-pod-2)
   ↓
7. Request delivered đến pod được chọn
```

### 7.3. Endpoints

**Endpoints** = Danh sách IP:Port của pods behind service

```bash
kubectl get endpoints auth-service

# Output:
NAME           ENDPOINTS
auth-service   10.244.1.5:3000,10.244.1.6:3000
```

**Update tự động:**
```
# Initial state
Endpoints: 10.244.1.5:3000, 10.244.1.6:3000

# Pod 2 crashes
↓
# Endpoint controller removes unhealthy pod
Endpoints: 10.244.1.5:3000

# New pod starts
↓
# Readiness probe passes
↓
# Endpoint added
Endpoints: 10.244.1.5:3000, 10.244.1.7:3000
```

---

## 8. ConfigMaps và Secrets

### 8.1. Tại Sao Cần?

**Vấn đề với hardcode:**

```javascript
// ❌ BAD: Hardcode trong code
const MONGODB_URI = "mongodb://mongodb:27017/auth";
const JWT_SECRET = "my-super-secret-key";

// Vấn đề:
// 1. Thay đổi config → phải rebuild image
// 2. Secret lộ trong source code
// 3. Khác nhau giữa dev/prod → phải maintain nhiều images
```

**Giải pháp:**

```javascript
// ✅ GOOD: Đọc từ environment variables
const MONGODB_URI = process.env.MONGODB_AUTH_URI;
const JWT_SECRET = process.env.JWT_SECRET;

// Config inject từ Kubernetes ConfigMap/Secret
```

### 8.2. ConfigMap cho Non-Sensitive Data

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  AUTH_PORT: "3000"
  PRODUCT_PORT: "3001"
  ORDER_SERVICE_URL: "http://order-service:3002"
```

**Sử dụng:**
```yaml
spec:
  containers:
  - name: auth
    env:
    - name: PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: AUTH_PORT
```

**Trong container:**
```bash
echo $PORT
# Output: 3000
```

### 8.3. Secret cho Sensitive Data

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
stringData:
  jwt-secret: "your_jwt_secret_key_here"
  mongodb-uri: "mongodb://mongodb:27017/auth"
```

**Khác biệt:**
- ConfigMap: Plain text, visible
- Secret: Base64 encoded, có thể encrypt

**Security best practices:**
```bash
# ❌ Không commit secrets vào Git
git add k8s/secret.yaml  # BAD

# ✅ Dùng sealed-secrets hoặc external secret management
# ✅ Hoặc tạo secrets bằng kubectl:
kubectl create secret generic app-secrets \
  --from-literal=jwt-secret=xxx \
  --from-literal=mongodb-uri=xxx
```

### 8.4. Update Config Without Downtime

```bash
# 1. Update ConfigMap
kubectl edit configmap app-config
# Change: AUTH_PORT: "3000" → "8080"

# 2. Restart deployment
kubectl rollout restart deployment auth-service

# Rolling update:
# - Pod 1 (old): Running
# - Pod 3 (new): Starting with new config
# - Pod 3: Ready
# - Pod 1: Terminating
# - Pod 2 (old): Running
# - Pod 4 (new): Starting
# - Pod 4: Ready
# - Pod 2: Terminating
# ✅ No downtime!
```

---

## 9. Health Checks và Auto-healing

### 9.1. Liveness Probe

**Mục đích:** Phát hiện pod "zombie" (chạy nhưng không hoạt động)

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30  # Đợi 30s sau khi start
  periodSeconds: 10         # Check mỗi 10s
  failureThreshold: 3       # Fail 3 lần → restart
```

**Kịch bản:**

```
1. Pod starts → Auth service starting...
   ↓ (30 seconds delay)
2. First liveness check: GET /health
   ↓
3. Response 200 OK → Pod healthy ✅
   ↓ (10 seconds)
4. Second check: GET /health
   ↓
5. Response 200 OK → Pod healthy ✅
   ↓
   ... time passes ...
   ↓
6. App bug → Deadlock → Cannot respond
   ↓
7. Liveness check: GET /health
   ↓ (timeout)
8. No response → Failure count: 1
   ↓ (10 seconds)
9. Check again → No response → Failure count: 2
   ↓ (10 seconds)
10. Check again → No response → Failure count: 3
    ↓
11. Threshold reached → Kill container
    ↓
12. kubelet restarts container
    ↓
13. Fresh start → App healthy again ✅
```

### 9.2. Readiness Probe

**Mục đích:** Phát hiện pod chưa sẵn sàng nhận traffic

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

**Khác với Liveness:**
- Liveness fail → **Restart container**
- Readiness fail → **Remove from service endpoints** (không restart)

**Kịch bản:**

```
1. Pod starts
   ↓
2. Container running but:
   - MongoDB connection pending
   - Loading large dataset
   - Warming up cache
   ↓
3. Readiness probe: GET /health
   ↓
4. Response 503 Service Unavailable
   ↓
5. Pod status: Running but NOT Ready
   ↓
6. Service endpoints: Pod NOT included
   - No traffic routed to this pod
   ↓
7. App initialization completes
   - MongoDB connected
   - Ready to serve requests
   ↓
8. Readiness probe: GET /health
   ↓
9. Response 200 OK
   ↓
10. Pod status: Running and Ready ✅
    ↓
11. Service endpoints: Pod included
    ↓
12. Traffic starts flowing to pod
```

### 9.3. Health Endpoint Implementation

```javascript
// auth/src/app.js
setRoutes() {
  // Health check endpoint
  this.app.get("/health", (req, res) => {
    // Check dependencies
    const mongoStatus = mongoose.connection.readyState === 1 
      ? 'connected' 
      : 'disconnected';
    
    if (mongoStatus === 'connected') {
      res.status(200).json({
        status: "ok",
        service: "auth",
        timestamp: new Date().toISOString(),
        mongodb: mongoStatus
      });
    } else {
      res.status(503).json({
        status: "error",
        service: "auth",
        mongodb: mongoStatus
      });
    }
  });
}
```

**Best practices:**
- ✅ Check critical dependencies (DB, cache, etc.)
- ✅ Fast response (< 1s)
- ✅ Don't do heavy computation
- ✅ Return proper HTTP codes (200, 503)

---

## 10. Scaling và Load Balancing

### 10.1. Horizontal Scaling

**Ví dụ: Auth service có 2 replicas**

```yaml
spec:
  replicas: 2
```

**Tại sao cần nhiều replicas?**

1. **High Availability**: 1 pod crash → còn pod khác
2. **Load Distribution**: Chia traffic
3. **Rolling Updates**: Update không downtime

### 10.2. Load Balancing

```
┌────────────────────────────────────────┐
│      Service "auth-service"            │
│      ClusterIP: 10.96.1.5              │
│                                        │
│   ┌────────────────────────────┐      │
│   │    kube-proxy (iptables)   │      │
│   │    Load Balancing Algorithm│      │
│   └────────────────────────────┘      │
└────────────────────────────────────────┘
            │
            ├─────── Round Robin ───────┐
            │                           │
            ▼                           ▼
    ┌──────────────┐          ┌──────────────┐
    │  Auth Pod 1  │          │  Auth Pod 2  │
    │ 10.244.1.5   │          │ 10.244.1.6   │
    │ CPU: 40%     │          │ CPU: 35%     │
    └──────────────┘          └──────────────┘
```

**Traffic distribution:**
```
Request 1 → Pod 1
Request 2 → Pod 2
Request 3 → Pod 1
Request 4 → Pod 2
...
```

### 10.3. Manual Scaling

```bash
# Scale up
kubectl scale deployment auth-service --replicas=5

# Kubernetes will:
# 1. Create 3 new pods
# 2. Schedule them on available nodes
# 3. Add to service endpoints when ready
# 4. Start receiving traffic

# Scale down
kubectl scale deployment auth-service --replicas=2

# Kubernetes will:
# 1. Choose 3 pods to terminate
# 2. Remove from service endpoints
# 3. Gracefully shutdown pods
# 4. Delete pods
```

### 10.4. Auto-scaling (HPA - Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: auth-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: auth-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Target 70% CPU
```

**Cách hoạt động:**
```
1. Metrics server thu thập CPU usage
   ↓
2. Current: 2 pods, Average CPU: 85%
   ↓
3. HPA: 85% > 70% target → Need more pods
   ↓
4. Calculate: (85 / 70) × 2 = 2.4 → Round up = 3 pods
   ↓
5. Scale up: 2 → 3 pods
   ↓
6. Traffic distributes across 3 pods
   ↓
7. Average CPU drops to 60%
   ↓
8. HPA: 60% < 70% → Good ✅
```

---

## 11. Luồng Hoạt Động của Ứng Dụng

### 11.1. User Registration Flow

```
┌─────────┐
│ Browser │
└────┬────┘
     │
     │ POST /auth/register
     │ Body: {username, password, email}
     ▼
┌──────────────────────────────────────┐
│   localhost:3003                     │ 1. Request đến host
└──────────────────────────────────────┘
     │
     │ Port mapping (Kind)
     ▼
┌──────────────────────────────────────┐
│   NodePort 30003                     │ 2. Forward to NodePort
└──────────────────────────────────────┘
     │
     │ Service routing
     ▼
┌──────────────────────────────────────┐
│   Service: api-gateway               │ 3. Service load-balance
│   ClusterIP: 10.96.4.10              │
└──────────────────────────────────────┘
     │
     │ Select pod (round-robin)
     ▼
┌──────────────────────────────────────┐
│   Pod: api-gateway-abc123            │ 4. Pod nhận request
│   IP: 10.244.0.5                     │    Path: /auth/register
└──────────────────────────────────────┘
     │
     │ Proxy request
     │ To: http://auth-service:3000/register
     ▼
┌──────────────────────────────────────┐
│   DNS Resolution                     │ 5. Resolve service name
│   auth-service → 10.96.1.5           │
└──────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────┐
│   Service: auth-service              │ 6. Auth service
│   ClusterIP: 10.96.1.5               │
└──────────────────────────────────────┘
     │
     │ Load-balance to pod
     ▼
┌──────────────────────────────────────┐
│   Pod: auth-service-def456           │ 7. Auth pod processes
│   IP: 10.244.1.6                     │
└──────────────────────────────────────┘
     │
     │ Need to save user
     │ Connect: mongodb:27017
     ▼
┌──────────────────────────────────────┐
│   DNS: mongodb → 10.96.2.10          │ 8. Resolve MongoDB
└──────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────┐
│   Service: mongodb                   │ 9. MongoDB service
│   ClusterIP: 10.96.2.10              │
└──────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────┐
│   Pod: mongodb-xyz789                │ 10. MongoDB pod
│   IP: 10.244.1.8                     │     Saves user data
│   PV: /mnt/data/mongodb              │     to PersistentVolume
└──────────────────────────────────────┘
     │
     │ Data saved ✅
     ▼
Response flows back:
MongoDB → Auth Pod → API Gateway → Browser
```

### 11.2. Create Order Flow (với RabbitMQ)

```
1. User places order (via API Gateway)
   ↓
2. Request → Product Service
   ↓
3. Product Service:
   - Validates product exists
   - Creates order message
   - Publishes to RabbitMQ queue "orders"
   ↓
4. RabbitMQ:
   - Message stored in queue
   - Persistent (survives restart)
   ↓
5. Order Service (consumer):
   - Listens to queue "orders"
   - Receives message
   - Processes order
   - Saves to MongoDB
   ↓
6. Asynchronous processing complete ✅
```

**Tại sao dùng RabbitMQ?**
- ✅ Decoupling: Product không cần wait Order service
- ✅ Reliability: Message không mất nếu Order service down
- ✅ Scalability: Nhiều Order consumers xử lý parallel

---

## 12. So Sánh Docker Compose vs Kubernetes

### Docker Compose

```yaml
services:
  auth:
    build: ./auth
    ports:
      - "3000:3000"
    environment:
      - MONGODB_URI=mongodb://mongo:27017
```

**Đặc điểm:**
- ✅ Đơn giản, dễ setup
- ✅ Tốt cho development
- ❌ Single host only
- ❌ Không có auto-healing
- ❌ Không có load balancing
- ❌ Khó scale

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 2  # Multiple instances
  template:
    spec:
      containers:
      - name: auth
        image: auth-service:latest
```

**Đặc điểm:**
- ✅ Multi-host clustering
- ✅ Auto-healing (restart failed pods)
- ✅ Built-in load balancing
- ✅ Easy scaling
- ✅ Rolling updates
- ✅ Health checks
- ✅ Service discovery
- ⚠️ Phức tạp hơn
- ⚠️ Learning curve cao

### Khi Nào Dùng Gì?

**Docker Compose:**
- Local development
- Simple applications
- Single server deployment
- Quick prototyping

**Kubernetes:**
- Production environments
- Microservices architecture
- Need high availability
- Need auto-scaling
- Multi-server deployment
- CI/CD pipelines

---

## Tổng Kết

### Các Khái Niệm Chính

1. **Kind**: Kubernetes cluster chạy trong Docker containers
2. **Nodes**: Máy chủ trong cluster (control-plane + workers)
3. **Pods**: Đơn vị nhỏ nhất, chứa containers
4. **Deployments**: Quản lý pods, replicas, updates
5. **Services**: Networking, DNS, load balancing
6. **ConfigMaps/Secrets**: Configuration management
7. **PersistentVolumes**: Data persistence
8. **Health Checks**: Liveness & readiness probes

### Luồng Hoạt Động Tổng Quát

```
Build Images → Create Cluster → Load Images → 
Deploy Infrastructure → Deploy Services → 
Health Checks Pass → Services Ready → 
Handle Requests
```

### Lợi Ích của Kubernetes

1. **Reliability**: Auto-healing, self-recovery
2. **Scalability**: Easy horizontal scaling
3. **Availability**: Multiple replicas, zero downtime updates
4. **Portability**: Run anywhere (local, cloud, on-premise)
5. **Service Discovery**: Automatic DNS, networking
6. **Configuration**: Separate config from code
7. **Storage**: Persistent data management

### Best Practices

1. ✅ Luôn define health checks
2. ✅ Set resource limits
3. ✅ Use ConfigMaps/Secrets
4. ✅ Enable auto-scaling cho production
5. ✅ Use PersistentVolumes cho stateful apps
6. ✅ Multiple replicas cho high availability
7. ✅ Implement proper logging
8. ✅ Monitor metrics

---

**Chúc bạn học tốt Kubernetes! 🚀**
