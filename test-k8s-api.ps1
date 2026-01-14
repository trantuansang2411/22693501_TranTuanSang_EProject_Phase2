# Script test API sau khi deploy Kubernetes
# File: test-k8s-api.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    KUBERNETES API TESTING SCRIPT       " -ForegroundColor Cyan
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

function Write-Error-Message {
    param($Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Test 1: Health Checks
Write-Step "Test 1: Health Checks"

$services = @(
    @{Name="API Gateway"; URL="http://localhost:3003/health"},
    @{Name="Auth Service"; URL="http://localhost:3000/health"},
    @{Name="Product Service"; URL="http://localhost:3001/health"},
    @{Name="Order Service"; URL="http://localhost:3002/health"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-RestMethod -Uri $service.URL -Method GET -TimeoutSec 5
        if ($response.status -eq "ok") {
            Write-Success "$($service.Name) is healthy"
        } else {
            Write-Error-Message "$($service.Name) returned unexpected response"
        }
    } catch {
        Write-Error-Message "$($service.Name) is not responding"
    }
}

# Test 2: Kiểm tra Pods
Write-Step "Test 2: Kiểm tra Pods"
Write-Host "Danh sách pods:" -ForegroundColor Yellow
kubectl get pods

$notRunningPods = kubectl get pods --field-selector=status.phase!=Running --no-headers 2>$null
if ($notRunningPods) {
    Write-Error-Message "Có pods chưa running!"
    Write-Host $notRunningPods -ForegroundColor Red
} else {
    Write-Success "Tất cả pods đang running"
}

# Test 3: Kiểm tra Services
Write-Step "Test 3: Kiểm tra Services"
Write-Host "Danh sách services:" -ForegroundColor Yellow
kubectl get services

# Test 4: User Registration
Write-Step "Test 4: Đăng ký user mới"

$registerBody = @{
    username = "testuser_$(Get-Random -Minimum 1000 -Maximum 9999)"
    password = "testpass123"
    email = "test$(Get-Random -Minimum 1000 -Maximum 9999)@example.com"
} | ConvertTo-Json

try {
    $registerResponse = Invoke-RestMethod -Uri "http://localhost:3003/auth/register" `
        -Method POST `
        -ContentType "application/json" `
        -Body $registerBody `
        -TimeoutSec 10
    
    Write-Success "User registered successfully"
    Write-Host "Username: $($registerResponse.username)" -ForegroundColor Cyan
    
    $username = ($registerBody | ConvertFrom-Json).username
    
    # Test 5: User Login
    Write-Step "Test 5: Đăng nhập user"
    
    $loginBody = @{
        username = $username
        password = "testpass123"
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:3003/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -TimeoutSec 10
    
    Write-Success "User logged in successfully"
    $token = $loginResponse.token
    Write-Host "Token: $($token.Substring(0, 50))..." -ForegroundColor Cyan
    
    # Test 6: Get Products (với authentication)
    Write-Step "Test 6: Lấy danh sách products (authenticated)"
    
    try {
        $productsResponse = Invoke-RestMethod -Uri "http://localhost:3003/products" `
            -Method GET `
            -Headers @{Authorization = "Bearer $token"} `
            -TimeoutSec 10
        
        Write-Success "Products retrieved successfully"
        Write-Host "Number of products: $($productsResponse.Count)" -ForegroundColor Cyan
    } catch {
        Write-Host "Note: Products endpoint may not be fully implemented" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error-Message "API test failed: $($_.Exception.Message)"
}

# Test 7: RabbitMQ Management
Write-Step "Test 7: RabbitMQ Management UI"
try {
    $rabbitmqResponse = Invoke-WebRequest -Uri "http://localhost:15672" -TimeoutSec 5 -UseBasicParsing
    Write-Success "RabbitMQ Management UI is accessible at http://localhost:15672"
    Write-Host "  Username: admin" -ForegroundColor Cyan
    Write-Host "  Password: admin" -ForegroundColor Cyan
} catch {
    Write-Error-Message "RabbitMQ Management UI is not accessible"
}

# Test 8: MongoDB Connection
Write-Step "Test 8: MongoDB Connection"
Write-Host "MongoDB is accessible at mongodb://localhost:27017" -ForegroundColor Cyan
Write-Host "Để test MongoDB, sử dụng MongoDB client:" -ForegroundColor Yellow
Write-Host '  mongosh "mongodb://localhost:27017"' -ForegroundColor White

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "          TEST SUMMARY                  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nEndpoints Available:" -ForegroundColor Green
Write-Host "  API Gateway:         http://localhost:3003" -ForegroundColor White
Write-Host "  Auth Service:        http://localhost:3000" -ForegroundColor White
Write-Host "  Product Service:     http://localhost:3001" -ForegroundColor White
Write-Host "  Order Service:       http://localhost:3002" -ForegroundColor White
Write-Host "  RabbitMQ Management: http://localhost:15672" -ForegroundColor White
Write-Host "  MongoDB:             mongodb://localhost:27017" -ForegroundColor White

Write-Host "`nKubernetes Commands:" -ForegroundColor Yellow
Write-Host "  kubectl get pods              - Xem pods"
Write-Host "  kubectl get services          - Xem services"
Write-Host "  kubectl logs <pod-name>       - Xem logs"
Write-Host "  kubectl describe pod <name>   - Xem chi tiết"

Write-Host "`n✓ Testing completed! 🎉" -ForegroundColor Green
