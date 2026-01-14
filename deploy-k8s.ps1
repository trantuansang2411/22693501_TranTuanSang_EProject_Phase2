# Script tự động deploy Kubernetes cluster với Kind
# File: deploy-k8s.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   KUBERNETES DEPLOYMENT WITH KIND     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function để hiển thị thông báo
function Write-Step {
    param($Message)
    Write-Host "`n>>> $Message" -ForegroundColor Green
}

function Write-Error-Message {
    param($Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Write-Success {
    param($Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

# Kiểm tra Docker đang chạy
Write-Step "Bước 1: Kiểm tra Docker"
try {
    docker version | Out-Null
    Write-Success "Docker đang chạy"
} catch {
    Write-Error-Message "Docker không chạy. Vui lòng khởi động Docker Desktop!"
    exit 1
}

# Kiểm tra Kind đã cài đặt
Write-Step "Bước 2: Kiểm tra Kind"
try {
    kind version | Out-Null
    Write-Success "Kind đã được cài đặt"
} catch {
    Write-Error-Message "Kind chưa được cài đặt. Chạy: choco install kind"
    exit 1
}

# Kiểm tra kubectl đã cài đặt
Write-Step "Bước 3: Kiểm tra kubectl"
try {
    kubectl version --client | Out-Null
    Write-Success "kubectl đã được cài đặt"
} catch {
    Write-Error-Message "kubectl chưa được cài đặt. Chạy: choco install kubernetes-cli"
    exit 1
}

# Build Docker images
Write-Step "Bước 4: Build Docker Images"
$services = @("auth", "product", "order", "api-gateway")

foreach ($service in $services) {
    Write-Host "Building $service-service..." -ForegroundColor Yellow
    docker build -t "$service-service:latest" "./$service"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "$service-service image đã build thành công"
    } else {
        Write-Error-Message "Không thể build $service-service"
        exit 1
    }
}

# Tạo Kind cluster
Write-Step "Bước 5: Tạo Kind Cluster"
$clusterExists = kind get clusters | Select-String "eproject-cluster"
if ($clusterExists) {
    Write-Host "Cluster 'eproject-cluster' đã tồn tại. Bạn có muốn xóa và tạo lại? (y/n): " -NoNewline
    $answer = Read-Host
    if ($answer -eq "y") {
        Write-Host "Đang xóa cluster cũ..." -ForegroundColor Yellow
        kind delete cluster --name eproject-cluster
        Write-Success "Đã xóa cluster cũ"
    } else {
        Write-Host "Sử dụng cluster hiện tại" -ForegroundColor Yellow
    }
}

if (-not (kind get clusters | Select-String "eproject-cluster")) {
    Write-Host "Đang tạo cluster mới..." -ForegroundColor Yellow
    kind create cluster --config=kind-config.yaml --name eproject-cluster
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Cluster đã được tạo thành công"
    } else {
        Write-Error-Message "Không thể tạo cluster"
        exit 1
    }
}

# Kiểm tra nodes
Write-Host "`nDanh sách nodes:" -ForegroundColor Cyan
kubectl get nodes

# Load images vào cluster
Write-Step "Bước 6: Load Docker Images vào Kind Cluster"
foreach ($service in $services) {
    Write-Host "Loading $service-service:latest..." -ForegroundColor Yellow
    kind load docker-image "$service-service:latest" --name eproject-cluster
    if ($LASTEXITCODE -eq 0) {
        Write-Success "$service-service image đã được load vào cluster"
    } else {
        Write-Error-Message "Không thể load $service-service image"
    }
}

# Deploy ConfigMap và Secrets
Write-Step "Bước 7: Deploy ConfigMap và Secrets"
kubectl apply -f k8s/configmap-secret.yaml
Write-Success "ConfigMap và Secrets đã được tạo"

# Deploy Infrastructure
Write-Step "Bước 8: Deploy MongoDB"
kubectl apply -f k8s/mongodb.yaml
Write-Success "MongoDB deployment đã được tạo"

Write-Step "Bước 9: Deploy RabbitMQ"
kubectl apply -f k8s/rabbitmq.yaml
Write-Success "RabbitMQ deployment đã được tạo"

# Đợi infrastructure sẵn sàng
Write-Host "`nĐang đợi MongoDB và RabbitMQ sẵn sàng..." -ForegroundColor Yellow
Write-Host "Có thể mất 1-2 phút..." -ForegroundColor Yellow

Start-Sleep -Seconds 10

# Deploy Microservices
Write-Step "Bước 10: Deploy Auth Service"
kubectl apply -f k8s/auth-service.yaml
Write-Success "Auth Service đã được deploy"

Write-Step "Bước 11: Deploy Product Service"
kubectl apply -f k8s/product-service.yaml
Write-Success "Product Service đã được deploy"

Write-Step "Bước 12: Deploy Order Service"
kubectl apply -f k8s/order-service.yaml
Write-Success "Order Service đã được deploy"

Write-Step "Bước 13: Deploy API Gateway"
kubectl apply -f k8s/api-gateway.yaml
Write-Success "API Gateway đã được deploy"

# Hiển thị trạng thái
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "         DEPLOYMENT COMPLETED!          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nĐang đợi tất cả pods khởi động..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "`nTrạng thái Pods:" -ForegroundColor Cyan
kubectl get pods

Write-Host "`nTrạng thái Services:" -ForegroundColor Cyan
kubectl get services

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "          ENDPOINTS AVAILABLE           " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API Gateway:         http://localhost:3003" -ForegroundColor Green
Write-Host "Auth Service:        http://localhost:3000" -ForegroundColor Green
Write-Host "Product Service:     http://localhost:3001" -ForegroundColor Green
Write-Host "Order Service:       http://localhost:3002" -ForegroundColor Green
Write-Host "MongoDB:             mongodb://localhost:27017" -ForegroundColor Green
Write-Host "RabbitMQ AMQP:       amqp://localhost:5672" -ForegroundColor Green
Write-Host "RabbitMQ Management: http://localhost:15672 (admin/admin)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nCác lệnh hữu ích:" -ForegroundColor Yellow
Write-Host "  kubectl get pods              - Xem trạng thái pods"
Write-Host "  kubectl get services          - Xem services"
Write-Host "  kubectl logs <pod-name>       - Xem logs"
Write-Host "  kubectl describe pod <name>   - Xem chi tiết pod"
Write-Host "  kubectl get nodes             - Xem nodes"

Write-Host "`nĐể xóa cluster:" -ForegroundColor Yellow
Write-Host "  kind delete cluster --name eproject-cluster"

Write-Host "`n✓ Deployment hoàn tất! Chúc bạn phát triển tốt! 🚀" -ForegroundColor Green
