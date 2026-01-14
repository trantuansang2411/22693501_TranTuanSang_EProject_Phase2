# Script dọn dẹp Kubernetes deployment
# File: cleanup-k8s.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "      KUBERNETES CLEANUP SCRIPT         " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Write-Step {
    param($Message)
    Write-Host "`n>>> $Message" -ForegroundColor Yellow
}

function Write-Success {
    param($Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

# Hỏi người dùng
Write-Host "Bạn muốn:" -ForegroundColor Cyan
Write-Host "  1. Xóa tất cả deployments (giữ cluster)" -ForegroundColor White
Write-Host "  2. Xóa hoàn toàn cluster" -ForegroundColor White
Write-Host "  3. Hủy" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Chọn (1/2/3)"

switch ($choice) {
    "1" {
        Write-Step "Xóa tất cả deployments..."
        
        Write-Host "Xóa API Gateway..." -ForegroundColor Yellow
        kubectl delete -f k8s/api-gateway.yaml --ignore-not-found=true
        
        Write-Host "Xóa Order Service..." -ForegroundColor Yellow
        kubectl delete -f k8s/order-service.yaml --ignore-not-found=true
        
        Write-Host "Xóa Product Service..." -ForegroundColor Yellow
        kubectl delete -f k8s/product-service.yaml --ignore-not-found=true
        
        Write-Host "Xóa Auth Service..." -ForegroundColor Yellow
        kubectl delete -f k8s/auth-service.yaml --ignore-not-found=true
        
        Write-Host "Xóa RabbitMQ..." -ForegroundColor Yellow
        kubectl delete -f k8s/rabbitmq.yaml --ignore-not-found=true
        
        Write-Host "Xóa MongoDB..." -ForegroundColor Yellow
        kubectl delete -f k8s/mongodb.yaml --ignore-not-found=true
        
        Write-Host "Xóa ConfigMap và Secrets..." -ForegroundColor Yellow
        kubectl delete -f k8s/configmap-secret.yaml --ignore-not-found=true
        
        Write-Success "Đã xóa tất cả deployments"
        
        Write-Host "`nTrạng thái hiện tại:" -ForegroundColor Cyan
        kubectl get all
        
        Write-Host "`nCluster vẫn đang chạy. Để xóa cluster, chạy:" -ForegroundColor Yellow
        Write-Host "  kind delete cluster --name eproject-cluster" -ForegroundColor White
    }
    
    "2" {
        Write-Step "Xóa hoàn toàn cluster..."
        
        $confirm = Read-Host "Bạn có chắc chắn muốn xóa cluster 'eproject-cluster'? (y/n)"
        if ($confirm -eq "y") {
            kind delete cluster --name eproject-cluster
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Cluster đã được xóa hoàn toàn"
                
                Write-Host "`nDanh sách clusters còn lại:" -ForegroundColor Cyan
                kind get clusters
            } else {
                Write-Host "ERROR: Không thể xóa cluster" -ForegroundColor Red
            }
        } else {
            Write-Host "Đã hủy" -ForegroundColor Yellow
        }
    }
    
    "3" {
        Write-Host "Đã hủy" -ForegroundColor Yellow
        exit 0
    }
    
    default {
        Write-Host "Lựa chọn không hợp lệ" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n✓ Hoàn tất!" -ForegroundColor Green
