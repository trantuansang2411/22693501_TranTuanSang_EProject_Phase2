# HƯỚNG DẪN XÂY DỰNG HỆ THỐNG KUBERNETES TỪ ĐẦU

## Mục Lục
1. [Phân tích yêu cầu hệ thống](#1-phân-tích-yêu-cầu-hệ-thống)
2. [Chuẩn bị môi trường](#2-chuẩn-bị-môi-trường)
3. [Tạo Dockerfiles cho các services](#3-tạo-dockerfiles-cho-các-services)
4. [Tạo cấu hình Kind cluster](#4-tạo-cấu-hình-kind-cluster)
5. [Tạo ConfigMaps và Secrets](#5-tạo-configmaps-và-secrets)
6. [Tạo manifests cho Infrastructure](#6-tạo-manifests-cho-infrastructure)
7. [Tạo manifests cho Microservices](#7-tạo-manifests-cho-microservices)
8. [Thêm Health Checks vào code](#8-thêm-health-checks-vào-code)
9. [Tạo scripts tự động hóa](#9-tạo-scripts-tự-động-hóa)
10. [Deploy và kiểm tra](#10-deploy-và-kiểm-tra)
11. [Troubleshooting](#11-troubleshooting)
12. [Checklist hoàn thành](#12-checklist-hoàn-thành)

---

## 1. Phân Tích Yêu Cầu Hệ Thống

### 1.1. Inventory Services Hiện Có

Trước tiên, hãy liệt kê các services bạn đã có:

```
Ví dụ hệ thống của tôi:
├── auth/           → Auth Service (Node.js + Express)
├── product/        → Product Service (Node.js + Express)  
├── order/          → Order Service (Node.js + Express)
└── api-gateway/    → API Gateway (Node.js + http-proxy)
```

**Câu hỏi cần trả lời:**
- ✓ Mỗi service chạy trên port nào?
- ✓ Service nào cần database?
- ✓ Service nào communicate với nhau?
- ✓ Service nào cần message queue?
- ✓ Có service nào lưu trữ data không?

### 1.2. Xác Định Dependencies

**Service Dependencies Map:**

```
API Gateway (Port 3003)
    ├── → Auth Service (Port 3000)
    ├── → Product Service (Port 3001)
    └── → Order Service (Port 3002)

Auth Service
    └── → MongoDB

Product Service
    ├── → MongoDB
    ├── → RabbitMQ (publish messages)
    └── → Order Service (HTTP calls)

Order Service
    ├── → MongoDB
    └── → RabbitMQ (consume messages)
```

**Infrastructure cần thiết:**
- MongoDB: Database cho auth, product, order
- RabbitMQ: Message broker giữa product và order

### 1.3. Quyết Định Kiến Trúc

**Cluster design:**
```
Kind Cluster:
  - 1 Control Plane Node (master)
  - 1 Worker Node (chạy workload)

Replicas:
  - Microservices: 2 replicas mỗi service (HA)
  - MongoDB: 1 replica (stateful)
  - RabbitMQ: 1 replica (stateful)

Storage:
  - MongoDB: PersistentVolume 5Gi
  - RabbitMQ: PersistentVolume 2Gi

Networking:
  - Internal: ClusterIP services
  - External: NodePort cho access từ host
```

---

## 2. Chuẩn Bị Môi Trường

### 2.1. Cài Đặt Docker Desktop

```powershell
# Tải từ: https://www.docker.com/products/docker-desktop/

# Sau khi cài, kiểm tra:
docker --version
# Output: Docker version 24.0.x

docker ps
# Không lỗi = OK
```

### 2.2. Cài Đặt Kind

```powershell
# Option 1: Chocolatey (recommended)
choco install kind

# Option 2: Manual download
# Windows PowerShell
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe C:\Windows\System32\kind.exe

# Verify
kind --version
# Output: kind v0.20.0 go1.20.4 windows/amd64
```

### 2.3. Cài Đặt kubectl

```powershell
# Option 1: Chocolatey
choco install kubernetes-cli

# Option 2: Manual download
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
Move-Item .\kubectl.exe C:\Windows\System32\

# Verify
kubectl version --client
# Output: Client Version: v1.28.0
```

### 2.4. Cấu Trúc Thư Mục

Tạo cấu trúc thư mục cho Kubernetes configs:

```powershell
# Trong thư mục project của bạn
mkdir k8s
cd k8s

# Tạo các thư mục con (optional, để organize)
# mkdir infrastructure
# mkdir services
# mkdir config
```

**Cấu trúc đề xuất:**
```
your-project/
├── auth/
├── product/
├── order/
├── api-gateway/
├── k8s/                      # ← Kubernetes manifests
│   ├── configmap-secret.yaml
│   ├── mongodb.yaml
│   ├── rabbitmq.yaml
│   ├── auth-service.yaml
│   ├── product-service.yaml
│   ├── order-service.yaml
│   └── api-gateway.yaml
├── kind-config.yaml          # ← Kind cluster config
└── deploy-k8s.ps1           # ← Deployment script
```

---

## 3. Tạo Dockerfiles cho Các Services

### 3.1. Phân Tích Service để Tạo Dockerfile

Với mỗi service, xác định:
- Base image nào? (node, python, java, etc.)
- Dependencies gì? (package.json, requirements.txt, etc.)
- Port nào?
- Command để start?

### 3.2. Template Dockerfile cho Node.js Service

**File: `auth/Dockerfile`**

```dockerfile
# Chọn base image - Alpine version nhẹ hơn
FROM node:18-alpine

# Set working directory trong container
WORKDIR /app

# Copy package files trước (leverage Docker cache)
COPY package*.json ./

# Install dependencies
# --only=production: không cài devDependencies
# ci: clean install, faster và reliable hơn npm install
RUN npm ci --only=production

# Copy source code
COPY . .

# Expose port mà service lắng nghe
EXPOSE 3000

# Command để start service
CMD ["npm", "start"]
```

**Giải thích từng dòng:**

```dockerfile
FROM node:18-alpine
# - node:18 = Node.js version 18
# - alpine = Linux distribution nhẹ nhất (5MB vs 900MB)
# - Kết quả: Image nhỏ hơn, build nhanh hơn

WORKDIR /app
# - Tạo và cd vào /app trong container
# - Tất cả commands sau sẽ chạy trong /app

COPY package*.json ./
# - Copy package.json và package-lock.json
# - Copy riêng để tận dụng Docker layer caching
# - Nếu package.json không đổi → layer cached → faster build

RUN npm ci --only=production
# - npm ci = clean install, không modify package-lock.json
# - --only=production = không cài devDependencies (test, linter, etc.)
# - Kết quả: Image nhỏ hơn, security tốt hơn

COPY . .
# - Copy tất cả source code vào /app
# - Làm sau để tận dụng cache của npm install

EXPOSE 3000
# - Document port 3000
# - Không thực sự "mở" port, chỉ là metadata

CMD ["npm", "start"]
# - Command chạy khi container start
# - Phải có "start" script trong package.json
```

### 3.3. Tạo Dockerfile cho Tất Cả Services

**Auth Service (`auth/Dockerfile`):**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

**Product Service (`product/Dockerfile`):**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

**Order Service (`order/Dockerfile`):**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3002
CMD ["npm", "start"]
```

**API Gateway (`api-gateway/Dockerfile`):**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3003
CMD ["npm", "start"]
```

### 3.4. Kiểm Tra package.json

**Đảm bảo mỗi service có `start` script:**

```json
{
  "name": "auth-service",
  "scripts": {
    "start": "node index.js"  // ← PHẢI có dòng này
  }
}
```

### 3.5. Test Build Locally

```powershell
# Build từng service
docker build -t auth-service:latest ./auth
docker build -t product-service:latest ./product
docker build -t order-service:latest ./order
docker build -t api-gateway:latest ./api-gateway

# Kiểm tra images đã build
docker images | Select-String "service"

# Output mong đợi:
# auth-service       latest    abc123    2 minutes ago   150MB
# product-service    latest    def456    1 minute ago    155MB
# order-service      latest    ghi789    1 minute ago    152MB
# api-gateway        latest    jkl012    30 seconds ago  145MB
```

**Nếu build lỗi:**
- Kiểm tra Dockerfile syntax
- Kiểm tra package.json có đúng không
- Kiểm tra có file .dockerignore chưa (optional nhưng recommended)

**Tạo `.dockerignore`:** (trong mỗi service folder)
```
node_modules
npm-debug.log
.env
.git
.gitignore
README.md
.vscode
coverage
.nyc_output
```

---

## 4. Tạo Cấu Hình Kind Cluster

### 4.1. Thiết Kế Cluster

**Quyết định:**
- Số nodes: 2 (1 control-plane + 1 worker)
- Ports cần expose: Tất cả service ports
- Tên cluster: tên-project-cluster

### 4.2. Tạo File kind-config.yaml

**File: `kind-config.yaml`** (trong root project)

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: eproject-cluster  # ← Đổi tên theo project của bạn
nodes:
  # Control plane node
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    # API Gateway - Port chính để user access
    - containerPort: 30003
      hostPort: 3003
      protocol: TCP
    # Auth Service
    - containerPort: 30000
      hostPort: 3000
      protocol: TCP
    # Product Service
    - containerPort: 30001
      hostPort: 3001
      protocol: TCP
    # Order Service
    - containerPort: 30002
      hostPort: 3002
      protocol: TCP
    # MongoDB
    - containerPort: 30017
      hostPort: 27017
      protocol: TCP
    # RabbitMQ AMQP
    - containerPort: 30672
      hostPort: 5672
      protocol: TCP
    # RabbitMQ Management UI
    - containerPort: 31672
      hostPort: 15672
      protocol: TCP
  
  # Worker node
  - role: worker
```

### 4.3. Giải Thích Port Mapping

**Format:**
```yaml
- containerPort: 30000  # Port trong Kind container
  hostPort: 3000        # Port trên máy host (localhost)
  protocol: TCP
```

**Ý nghĩa:**
```
Khi truy cập localhost:3000
  ↓
Được forward đến containerPort 30000 trong Kind
  ↓
containerPort 30000 là NodePort của Kubernetes Service
  ↓
Được route đến Pod
```

**Lưu ý:**
- hostPort = port bạn muốn access từ browser
- containerPort = phải match với nodePort trong Service YAML

### 4.4. Port Planning Worksheet

Liệt kê tất cả ports cần expose:

| Service | Container Port | NodePort | Host Port | Purpose |
|---------|---------------|----------|-----------|---------|
| API Gateway | 3003 | 30003 | 3003 | Main entry point |
| Auth | 3000 | 30000 | 3000 | Auth API |
| Product | 3001 | 30001 | 3001 | Product API |
| Order | 3002 | 30002 | 3002 | Order API |
| MongoDB | 27017 | 30017 | 27017 | Database |
| RabbitMQ AMQP | 5672 | 30672 | 5672 | Message queue |
| RabbitMQ UI | 15672 | 31672 | 15672 | Management |

---

## 5. Tạo ConfigMaps và Secrets

### 5.1. Phân Loại Configuration

**ConfigMap (non-sensitive):**
- Port numbers
- Service URLs
- Queue names
- Environment names (dev, prod)
- Feature flags

**Secret (sensitive):**
- Database URIs (có credentials)
- JWT secrets
- API keys
- Passwords
- Certificates

### 5.2. Thu Thập Environment Variables

**Xem env vars hiện tại trong docker-compose.yml:**

```yaml
# docker-compose.yml
environment:
  - PORT=3000
  - JWT_SECRET=your_jwt_secret_key_here
  - MONGODB_AUTH_URI=mongodb://mongodb:27017/auth
```

**List tất cả env vars cần thiết:**

```
Auth Service:
  - PORT (ConfigMap)
  - JWT_SECRET (Secret)
  - MONGODB_AUTH_URI (Secret)

Product Service:
  - PORT (ConfigMap)
  - JWT_SECRET (Secret)
  - MONGODB_PRODUCT_URI (Secret)
  - RABBITMQ_URI (Secret)
  - RABBITMQ_QUEUE_PRODUCT (ConfigMap)
  - RABBITMQ_QUEUE_ORDER (ConfigMap)
  - ORDER_SERVICE_URL (ConfigMap)

Order Service:
  - PORT (ConfigMap)
  - JWT_SECRET (Secret)
  - MONGODB_ORDER_URI (Secret)
  - RABBITMQ_URI (Secret)
  - RABBITMQ_QUEUE_ORDER (ConfigMap)
  - RABBITMQ_QUEUE_PRODUCT (ConfigMap)

API Gateway:
  - PORT (ConfigMap)
  - AUTH_SERVICE_URL (ConfigMap)
  - PRODUCT_SERVICE_URL (ConfigMap)
  - ORDER_SERVICE_URL (ConfigMap)
```

### 5.3. Tạo File configmap-secret.yaml

**File: `k8s/configmap-secret.yaml`**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: default
type: Opaque
stringData:
  # JWT Secret - Thay đổi thành secret của bạn
  jwt-secret: "your_jwt_secret_key_here_change_me"
  
  # MongoDB URIs
  # Format: mongodb://<service-name>:<port>/<database-name>
  mongodb-auth-uri: "mongodb://mongodb:27017/auth"
  mongodb-product-uri: "mongodb://mongodb:27017/product"
  mongodb-order-uri: "mongodb://mongodb:27017/order"
  
  # RabbitMQ URI
  # Format: amqp://<user>:<pass>@<service-name>:<port>
  rabbitmq-uri: "amqp://admin:admin@rabbitmq:5672"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  # Service Ports
  AUTH_PORT: "3000"
  PRODUCT_PORT: "3001"
  ORDER_PORT: "3002"
  GATEWAY_PORT: "3003"
  
  # RabbitMQ Queue Names
  RABBITMQ_QUEUE_PRODUCT: "products"
  RABBITMQ_QUEUE_ORDER: "orders"
  
  # Service-to-Service URLs
  # Format: http://<service-name>:<port>
  AUTH_SERVICE_URL: "http://auth-service:3000"
  PRODUCT_SERVICE_URL: "http://product-service:3001"
  ORDER_SERVICE_URL: "http://order-service:3002"
```

**Giải thích:**

```yaml
stringData:  # Dùng stringData thay vì data
  jwt-secret: "plain-text-value"
  # Kubernetes tự động encode sang base64

# VS

data:  # Nếu dùng data, phải encode manual
  jwt-secret: "eW91cl9qd3Rfc2VjcmV0X2tleQ=="  # base64 encoded
```

**Service URLs:**
```yaml
mongodb-auth-uri: "mongodb://mongodb:27017/auth"
#                           ↑         ↑      ↑
#                       service    port  database
#                         name

# "mongodb" = Service name trong Kubernetes
# Kubernetes DNS sẽ resolve thành ClusterIP
```

---

## 6. Tạo Manifests cho Infrastructure

### 6.1. MongoDB với PersistentVolume

**Tại sao cần PersistentVolume?**
- MongoDB lưu data
- Container restart → data mất
- PV = data tồn tại độc lập

**File: `k8s/mongodb.yaml`**

```yaml
# Step 1: PersistentVolume (Storage trên node)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 5Gi  # Kích thước storage
  accessModes:
    - ReadWriteOnce  # 1 node có thể mount read-write
  hostPath:
    path: "/mnt/data/mongodb"  # Path trên node

---
# Step 2: PersistentVolumeClaim (Request storage)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: default
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi  # Must match hoặc <= PV capacity

---
# Step 3: Deployment (Pod definition)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: default
  labels:
    app: mongodb
spec:
  replicas: 1  # Stateful app = 1 replica
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:6.0  # Official MongoDB image
        ports:
        - containerPort: 27017
          name: mongodb
        env:
        - name: MONGO_INITDB_DATABASE
          value: "eproject"  # Database khởi tạo
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db  # MongoDB lưu data ở đây
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: mongodb-storage
        persistentVolumeClaim:
          claimName: mongodb-pvc  # Link đến PVC

---
# Step 4: Service (Networking)
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: default
  labels:
    app: mongodb
spec:
  type: NodePort
  ports:
  - port: 27017        # Port trong cluster
    targetPort: 27017  # Port của container
    nodePort: 30017    # Port expose ra ngoài
    protocol: TCP
    name: mongodb
  selector:
    app: mongodb  # Select pods với label này
```

**Giải thích Resources:**

```yaml
resources:
  requests:  # Minimum resources cần
    memory: "512Mi"  # 512 Megabytes
    cpu: "250m"      # 250 millicores = 0.25 CPU
  limits:    # Maximum resources allowed
    memory: "1Gi"    # 1 Gigabyte
    cpu: "500m"      # 0.5 CPU
```

**Tại sao cần requests/limits?**
- requests: Scheduler dùng để quyết định pod chạy trên node nào
- limits: Prevent pod dùng hết resources node
- Best practice: limits = 2x requests

### 6.2. RabbitMQ với PersistentVolume

**File: `k8s/rabbitmq.yaml`**

```yaml
# PersistentVolume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rabbitmq-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/rabbitmq"

---
# PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rabbitmq-pvc
  namespace: default
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi

---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: default
  labels:
    app: rabbitmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3.11-management  # Include management UI
        ports:
        - containerPort: 5672   # AMQP port
          name: amqp
        - containerPort: 15672  # Management UI port
          name: management
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: "admin"
        - name: RABBITMQ_DEFAULT_PASS
          value: "admin"
        volumeMounts:
        - name: rabbitmq-storage
          mountPath: /var/lib/rabbitmq
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: rabbitmq-storage
        persistentVolumeClaim:
          claimName: rabbitmq-pvc

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: default
  labels:
    app: rabbitmq
spec:
  type: NodePort
  ports:
  - port: 5672
    targetPort: 5672
    nodePort: 30672
    protocol: TCP
    name: amqp
  - port: 15672
    targetPort: 15672
    nodePort: 31672
    protocol: TCP
    name: management
  selector:
    app: rabbitmq
```

---

## 7. Tạo Manifests cho Microservices

### 7.1. Template Chung

**Cấu trúc Deployment + Service:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
  labels:
    app: <service-name>
spec:
  replicas: 2  # High availability
  selector:
    matchLabels:
      app: <service-name>
  template:
    metadata:
      labels:
        app: <service-name>
    spec:
      containers:
      - name: <service-name>
        image: <service-name>:latest
        imagePullPolicy: Never  # Use local image
        ports:
        - containerPort: <port>
        env:
        - name: ENV_VAR
          valueFrom:
            configMapKeyRef:  # Hoặc secretKeyRef
              name: app-config
              key: KEY_NAME
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: <port>
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: <port>
          initialDelaySeconds: 10
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
  labels:
    app: <service-name>
spec:
  type: NodePort
  ports:
  - port: <port>
    targetPort: <port>
    nodePort: <nodePort>
  selector:
    app: <service-name>
```

### 7.2. Auth Service

**File: `k8s/auth-service.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  namespace: default
  labels:
    app: auth-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
    spec:
      containers:
      - name: auth-service
        image: auth-service:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: AUTH_PORT
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        - name: MONGODB_AUTH_URI
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: mongodb-auth-uri
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: default
  labels:
    app: auth-service
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30000
    protocol: TCP
    name: http
  selector:
    app: auth-service
```

### 7.3. Product Service

**File: `k8s/product-service.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: default
  labels:
    app: product-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: product-service:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3001
          name: http
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: PRODUCT_PORT
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        - name: MONGODB_PRODUCT_URI
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: mongodb-product-uri
        - name: RABBITMQ_URI
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: rabbitmq-uri
        - name: RABBITMQ_QUEUE_PRODUCT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: RABBITMQ_QUEUE_PRODUCT
        - name: RABBITMQ_QUEUE_ORDER
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: RABBITMQ_QUEUE_ORDER
        - name: ORDER_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: ORDER_SERVICE_URL
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: default
  labels:
    app: product-service
spec:
  type: NodePort
  ports:
  - port: 3001
    targetPort: 3001
    nodePort: 30001
    protocol: TCP
    name: http
  selector:
    app: product-service
```

### 7.4. Order Service

**File: `k8s/order-service.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: default
  labels:
    app: order-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: order-service:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3002
          name: http
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: ORDER_PORT
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: jwt-secret
        - name: MONGODB_ORDER_URI
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: mongodb-order-uri
        - name: RABBITMQ_URI
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: rabbitmq-uri
        - name: RABBITMQ_QUEUE_ORDER
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: RABBITMQ_QUEUE_ORDER
        - name: RABBITMQ_QUEUE_PRODUCT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: RABBITMQ_QUEUE_PRODUCT
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: default
  labels:
    app: order-service
spec:
  type: NodePort
  ports:
  - port: 3002
    targetPort: 3002
    nodePort: 30002
    protocol: TCP
    name: http
  selector:
    app: order-service
```

### 7.5. API Gateway

**File: `k8s/api-gateway.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: default
  labels:
    app: api-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: api-gateway:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 3003
          name: http
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: GATEWAY_PORT
        - name: AUTH_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: AUTH_SERVICE_URL
        - name: PRODUCT_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: PRODUCT_SERVICE_URL
        - name: ORDER_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: ORDER_SERVICE_URL
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3003
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 3003
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: default
  labels:
    app: api-gateway
spec:
  type: NodePort
  ports:
  - port: 3003
    targetPort: 3003
    nodePort: 30003
    protocol: TCP
    name: http
  selector:
    app: api-gateway
```

---

## 8. Thêm Health Checks vào Code

### 8.1. Tại Sao Cần Health Checks?

Kubernetes cần biết:
- Pod đã sẵn sàng nhận traffic chưa? (Readiness)
- Pod có đang hoạt động bình thường không? (Liveness)

### 8.2. Implement Health Endpoint

**Cho Express.js Apps (Auth, Product, Order):**

Thêm vào file `src/app.js`:

```javascript
setRoutes() {
  // Health check endpoint
  this.app.get("/health", (req, res) => {
    res.status(200).json({ 
      status: "ok", 
      service: "auth",  // Đổi tên service tương ứng
      timestamp: new Date().toISOString()
    });
  });
  
  // Các routes khác...
  this.app.use("/", AuthRoutes);
}
```

**Cho API Gateway:**

Thêm vào file `index.js`:

```javascript
const express = require("express");
const httpProxy = require("http-proxy");
const app = express();

// Health check endpoint
app.get("/health", (req, res) => {
  res.status(200).json({ 
    status: "ok", 
    service: "api-gateway",
    timestamp: new Date().toISOString()
  });
});

// Proxy routes...
app.use("/auth", (req, res) => {
  // ...
});
```

### 8.3. Advanced Health Check (Optional)

**Check dependencies:**

```javascript
const mongoose = require("mongoose");

app.get("/health", (req, res) => {
  // Check MongoDB connection
  const dbStatus = mongoose.connection.readyState === 1 
    ? "connected" 
    : "disconnected";
  
  if (dbStatus === "connected") {
    res.status(200).json({
      status: "ok",
      service: "auth",
      dependencies: {
        mongodb: "healthy"
      }
    });
  } else {
    res.status(503).json({
      status: "error",
      service: "auth",
      dependencies: {
        mongodb: "unhealthy"
      }
    });
  }
});
```

### 8.4. Test Health Endpoints Locally

```powershell
# Test với Docker Compose trước
docker compose up -d

# Test endpoints
curl http://localhost:3000/health
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health

# Tất cả phải return 200 OK với JSON response

docker compose down
```

---

## 9. Tạo Scripts Tự Động Hóa

### 9.1. Script Deploy

**File: `deploy-k8s.ps1`**

```powershell
# Automated Kubernetes Deployment Script

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   KUBERNETES DEPLOYMENT SCRIPT        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Write-Step {
    param($Message)
    Write-Host "`n>>> $Message" -ForegroundColor Green
}

function Write-Success {
    param($Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

# Step 1: Check Docker
Write-Step "Checking Docker..."
try {
    docker version | Out-Null
    Write-Success "Docker is running"
} catch {
    Write-Host "ERROR: Docker is not running!" -ForegroundColor Red
    exit 1
}

# Step 2: Build images
Write-Step "Building Docker images..."
$services = @("auth", "product", "order", "api-gateway")

foreach ($service in $services) {
    Write-Host "Building $service-service..." -ForegroundColor Yellow
    docker build -t "$service-service:latest" "./$service"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "$service-service built successfully"
    } else {
        Write-Host "ERROR: Failed to build $service-service" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Create Kind cluster
Write-Step "Creating Kind cluster..."
$clusterExists = kind get clusters | Select-String "eproject-cluster"
if (-not $clusterExists) {
    kind create cluster --config=kind-config.yaml --name eproject-cluster
    Write-Success "Cluster created"
} else {
    Write-Host "Cluster already exists" -ForegroundColor Yellow
}

# Step 4: Load images to Kind
Write-Step "Loading images to Kind cluster..."
foreach ($service in $services) {
    Write-Host "Loading $service-service..." -ForegroundColor Yellow
    kind load docker-image "$service-service:latest" --name eproject-cluster
    Write-Success "$service-service loaded"
}

# Step 5: Deploy Kubernetes manifests
Write-Step "Deploying ConfigMaps and Secrets..."
kubectl apply -f k8s/configmap-secret.yaml

Write-Step "Deploying MongoDB..."
kubectl apply -f k8s/mongodb.yaml

Write-Step "Deploying RabbitMQ..."
kubectl apply -f k8s/rabbitmq.yaml

Write-Step "Deploying Auth Service..."
kubectl apply -f k8s/auth-service.yaml

Write-Step "Deploying Product Service..."
kubectl apply -f k8s/product-service.yaml

Write-Step "Deploying Order Service..."
kubectl apply -f k8s/order-service.yaml

Write-Step "Deploying API Gateway..."
kubectl apply -f k8s/api-gateway.yaml

# Step 6: Wait and show status
Write-Host "`n" -NoNewline
Start-Sleep -Seconds 10

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         DEPLOYMENT COMPLETED           " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nPods:" -ForegroundColor Cyan
kubectl get pods

Write-Host "`nServices:" -ForegroundColor Cyan
kubectl get services

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "          ENDPOINTS                     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API Gateway:         http://localhost:3003" -ForegroundColor Green
Write-Host "Auth Service:        http://localhost:3000" -ForegroundColor Green
Write-Host "Product Service:     http://localhost:3001" -ForegroundColor Green
Write-Host "Order Service:       http://localhost:3002" -ForegroundColor Green
Write-Host "RabbitMQ Management: http://localhost:15672" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n✓ Deployment complete! 🚀" -ForegroundColor Green
```

### 9.2. Script Cleanup

**File: `cleanup-k8s.ps1`**

```powershell
Write-Host "Kubernetes Cleanup Script" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Delete all deployments (keep cluster)" -ForegroundColor White
Write-Host "2. Delete entire cluster" -ForegroundColor White
Write-Host "3. Cancel" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Choose (1/2/3)"

switch ($choice) {
    "1" {
        Write-Host "`nDeleting all deployments..." -ForegroundColor Yellow
        kubectl delete -f k8s/ --ignore-not-found=true
        Write-Host "✓ Deployments deleted" -ForegroundColor Green
    }
    "2" {
        $confirm = Read-Host "Delete cluster 'eproject-cluster'? (y/n)"
        if ($confirm -eq "y") {
            kind delete cluster --name eproject-cluster
            Write-Host "✓ Cluster deleted" -ForegroundColor Green
        }
    }
    "3" {
        Write-Host "Cancelled" -ForegroundColor Yellow
    }
}
```

---

## 10. Deploy và Kiểm Tra

### 10.1. Run Deployment Script

```powershell
# Chạy script
.\deploy-k8s.ps1

# Hoặc deploy thủ công:
```

### 10.2. Manual Deployment Steps

```powershell
# 1. Build images
docker build -t auth-service:latest ./auth
docker build -t product-service:latest ./product
docker build -t order-service:latest ./order
docker build -t api-gateway:latest ./api-gateway

# 2. Create cluster
kind create cluster --config=kind-config.yaml --name eproject-cluster

# 3. Verify cluster
kubectl get nodes
# Should show 2 nodes: control-plane and worker

# 4. Load images
kind load docker-image auth-service:latest --name eproject-cluster
kind load docker-image product-service:latest --name eproject-cluster
kind load docker-image order-service:latest --name eproject-cluster
kind load docker-image api-gateway:latest --name eproject-cluster

# 5. Deploy configs
kubectl apply -f k8s/configmap-secret.yaml

# 6. Deploy infrastructure
kubectl apply -f k8s/mongodb.yaml
kubectl apply -f k8s/rabbitmq.yaml

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s

# 7. Deploy services
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/product-service.yaml
kubectl apply -f k8s/order-service.yaml
kubectl apply -f k8s/api-gateway.yaml

# 8. Watch pods starting
kubectl get pods -w
# Press Ctrl+C to stop watching
```

### 10.3. Verify Deployment

```powershell
# Check pods
kubectl get pods

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# auth-service-xxx-xxx              1/1     Running   0          1m
# auth-service-xxx-xxx              1/1     Running   0          1m
# product-service-xxx-xxx           1/1     Running   0          1m
# product-service-xxx-xxx           1/1     Running   0          1m
# order-service-xxx-xxx             1/1     Running   0          1m
# order-service-xxx-xxx             1/1     Running   0          1m
# api-gateway-xxx-xxx               1/1     Running   0          1m
# api-gateway-xxx-xxx               1/1     Running   0          1m
# mongodb-xxx-xxx                   1/1     Running   0          2m
# rabbitmq-xxx-xxx                  1/1     Running   0          2m

# Check services
kubectl get services

# Expected output:
# NAME              TYPE       CLUSTER-IP      PORT(S)
# auth-service      NodePort   10.96.x.x       3000:30000/TCP
# product-service   NodePort   10.96.x.x       3001:30001/TCP
# order-service     NodePort   10.96.x.x       3002:30002/TCP
# api-gateway       NodePort   10.96.x.x       3003:30003/TCP
# mongodb           NodePort   10.96.x.x       27017:30017/TCP
# rabbitmq          NodePort   10.96.x.x       5672:30672/TCP,15672:31672/TCP

# Check if all pods are ready
kubectl get pods --field-selector=status.phase!=Running
# Should return empty (no pods)
```

### 10.4. Test Health Endpoints

```powershell
# Test all services
curl http://localhost:3003/health
curl http://localhost:3000/health
curl http://localhost:3001/health
curl http://localhost:3002/health

# Expected: All return 200 OK with JSON
```

### 10.5. Test API Flow

```powershell
# Register user
$registerBody = @{
    username = "testuser"
    password = "testpass123"
    email = "test@example.com"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3003/auth/register" `
    -Method POST `
    -ContentType "application/json" `
    -Body $registerBody

# Login
$loginBody = @{
    username = "testuser"
    password = "testpass123"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:3003/auth/login" `
    -Method POST `
    -ContentType "application/json" `
    -Body $loginBody

Write-Host "Token: $($response.token)"
```

---

## 11. Troubleshooting

### 11.1. Pods Not Starting

**Problem:** Pods stuck in `Pending`, `ImagePullBackOff`, hoặc `CrashLoopBackOff`

**Check:**
```powershell
# Describe pod để xem lỗi
kubectl describe pod <pod-name>

# Xem logs
kubectl logs <pod-name>

# Xem events
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Common Issues:**

#### ImagePullBackOff
```
Error: Failed to pull image "auth-service:latest"
```
**Solution:**
```powershell
# Image chưa load vào Kind
kind load docker-image auth-service:latest --name eproject-cluster

# Verify image trong cluster
docker exec -it eproject-cluster-control-plane crictl images | Select-String "auth-service"
```

#### CrashLoopBackOff
```
Error: Container exits immediately
```
**Solution:**
```powershell
# Check logs
kubectl logs <pod-name>

# Common causes:
# 1. Missing environment variables
# 2. Cannot connect to MongoDB/RabbitMQ
# 3. Port already in use
# 4. Missing dependencies

# Check if MongoDB is ready
kubectl get pods -l app=mongodb
```

#### Pending
```
Status: Pending
Reason: Insufficient resources
```
**Solution:**
```powershell
# Check node resources
kubectl describe nodes

# Reduce replicas or resource requests
kubectl scale deployment auth-service --replicas=1
```

### 11.2. Service Not Accessible

**Problem:** `curl http://localhost:3000/health` không kết nối được

**Check:**

```powershell
# 1. Check service exists
kubectl get service auth-service

# 2. Check endpoints
kubectl get endpoints auth-service
# Should show pod IPs

# 3. Check port-forward
kubectl port-forward service/auth-service 8080:3000
# Then test: curl http://localhost:8080/health

# 4. Check Kind port mapping
docker ps
# Verify ports are mapped correctly
```

**Common Issues:**

- **NodePort mismatch**: NodePort trong YAML phải match với containerPort trong kind-config.yaml
- **Service selector wrong**: Label trong Deployment phải match selector trong Service
- **Pod not ready**: Readiness probe failing

### 11.3. ConfigMap/Secret Not Found

**Problem:**
```
Error: configmap "app-config" not found
```

**Solution:**
```powershell
# Check if ConfigMap exists
kubectl get configmap

# If not, create it
kubectl apply -f k8s/configmap-secret.yaml

# Verify
kubectl describe configmap app-config
```

### 11.4. PersistentVolume Issues

**Problem:**
```
PVC status: Pending
```

**Check:**
```powershell
# Check PV
kubectl get pv

# Check PVC
kubectl get pvc

# Describe PVC
kubectl describe pvc mongodb-pvc
```

**Common Issues:**
- **StorageClass mismatch**: PV và PVC phải có cùng storageClassName
- **Capacity mismatch**: PVC request > PV capacity
- **AccessMode incompatible**: RWO, ROX, RWX phải match

### 11.5. Health Check Failing

**Problem:**
```
Readiness probe failed: HTTP probe failed with statuscode: 404
```

**Solution:**
```powershell
# 1. Verify /health endpoint exists
kubectl exec -it <pod-name> -- wget -O- http://localhost:3000/health

# 2. Check if service is listening on correct port
kubectl exec -it <pod-name> -- netstat -tlnp

# 3. Check logs for errors
kubectl logs <pod-name>

# 4. Temporarily disable probes để debug
# Edit deployment và comment out probes
kubectl edit deployment auth-service
```

### 11.6. Debugging Commands

```powershell
# Get all resources
kubectl get all

# Describe problematic pod
kubectl describe pod <pod-name>

# Logs với follow
kubectl logs -f <pod-name>

# Previous logs (nếu pod restart)
kubectl logs <pod-name> --previous

# Exec vào container
kubectl exec -it <pod-name> -- /bin/sh

# Test connectivity từ trong pod
kubectl exec -it <pod-name> -- wget -O- http://mongodb:27017
kubectl exec -it <pod-name> -- nslookup mongodb

# Port forward để test
kubectl port-forward <pod-name> 8080:3000

# Delete và recreate pod
kubectl delete pod <pod-name>
# Deployment sẽ tự tạo pod mới
```

---

## 12. Checklist Hoàn Thành

### ✅ Pre-deployment

- [ ] Docker Desktop installed và running
- [ ] Kind installed
- [ ] kubectl installed
- [ ] All services có Dockerfile
- [ ] All services có package.json với "start" script
- [ ] All services có /health endpoint
- [ ] kind-config.yaml created
- [ ] k8s/ folder created

### ✅ Configuration Files

- [ ] configmap-secret.yaml created với đầy đủ env vars
- [ ] mongodb.yaml với PV/PVC/Deployment/Service
- [ ] rabbitmq.yaml với PV/PVC/Deployment/Service
- [ ] auth-service.yaml với Deployment/Service
- [ ] product-service.yaml với Deployment/Service
- [ ] order-service.yaml với Deployment/Service
- [ ] api-gateway.yaml với Deployment/Service

### ✅ Deployment

- [ ] Images built successfully
- [ ] Kind cluster created (2 nodes)
- [ ] Images loaded vào cluster
- [ ] ConfigMaps/Secrets deployed
- [ ] MongoDB deployed và running
- [ ] RabbitMQ deployed và running
- [ ] All microservices deployed
- [ ] All pods ở status Running
- [ ] All pods ở status Ready

### ✅ Verification

- [ ] `kubectl get nodes` shows 2 nodes Ready
- [ ] `kubectl get pods` shows all pods Running
- [ ] `kubectl get services` shows all services
- [ ] Health checks return 200 OK
- [ ] User registration works
- [ ] User login works và returns token
- [ ] Authenticated requests work
- [ ] RabbitMQ UI accessible at localhost:15672

### ✅ Documentation

- [ ] README.md updated với Kubernetes instructions
- [ ] Environment variables documented
- [ ] Port mappings documented
- [ ] Troubleshooting guide created

---

## Tổng Kết

### Các Bước Chính

1. **Analyze**: Hiểu services và dependencies
2. **Prepare**: Install tools (Docker, Kind, kubectl)
3. **Containerize**: Tạo Dockerfiles
4. **Configure Cluster**: Tạo kind-config.yaml
5. **Configure Apps**: Tạo ConfigMaps/Secrets
6. **Create Manifests**: Tạo YAML files cho infrastructure và services
7. **Add Health Checks**: Implement /health endpoints
8. **Automate**: Tạo deployment scripts
9. **Deploy**: Run deployment
10. **Verify**: Test tất cả endpoints
11. **Debug**: Troubleshoot issues
12. **Document**: Update documentation

### Key Principles

1. **Separation of Concerns**: Config riêng, code riêng
2. **Declarative**: YAML files describe desired state
3. **Idempotent**: `kubectl apply` có thể run nhiều lần
4. **Self-healing**: Kubernetes tự restart failed pods
5. **Scalable**: Dễ dàng thay đổi replicas
6. **Observable**: Logs, events, metrics

### Best Practices

1. ✅ Luôn dùng PersistentVolumes cho stateful apps
2. ✅ Set resource requests/limits
3. ✅ Implement health checks (liveness + readiness)
4. ✅ Use ConfigMaps/Secrets cho config
5. ✅ Multiple replicas cho high availability
6. ✅ Use NodePort cho development, Ingress cho production
7. ✅ Tag images properly (không dùng :latest trong prod)
8. ✅ Test locally với Docker Compose trước
9. ✅ Document tất cả environment variables
10. ✅ Keep secrets out of Git

### Next Steps

Sau khi master Kubernetes basics, học tiếp:

1. **Ingress**: HTTP routing thay vì NodePort
2. **Helm**: Package manager cho Kubernetes
3. **Monitoring**: Prometheus + Grafana
4. **Logging**: EFK stack (Elasticsearch + Fluentd + Kibana)
5. **CI/CD**: GitHub Actions + ArgoCD
6. **Service Mesh**: Istio hoặc Linkerd
7. **Autoscaling**: HPA và VPA
8. **StatefulSets**: Cho databases
9. **Operators**: Custom controllers
10. **Security**: RBAC, Network Policies, Pod Security

---

**Chúc bạn build thành công hệ thống Kubernetes! 🚀**

*Nếu gặp vấn đề, hãy review lại từng bước và check Troubleshooting section.*
