# KUBECTL CHEAT SHEET - COMMANDS HỮU ÍCH

## Quản Lý Cluster

```powershell
# Xem thông tin cluster
kubectl cluster-info

# Xem tất cả nodes
kubectl get nodes

# Chi tiết về node
kubectl describe node <node-name>

# Xem context hiện tại
kubectl config current-context

# Chuyển context
kubectl config use-context <context-name>
```

## Quản Lý Pods

```powershell
# Xem tất cả pods
kubectl get pods

# Xem pods với nhiều thông tin hơn
kubectl get pods -o wide

# Xem pods của một service cụ thể
kubectl get pods -l app=auth-service

# Theo dõi pods real-time
kubectl get pods -w

# Chi tiết pod
kubectl describe pod <pod-name>

# Xóa pod (sẽ tự tạo lại nếu có deployment)
kubectl delete pod <pod-name>

# Force delete pod
kubectl delete pod <pod-name> --force --grace-period=0
```

## Logs

```powershell
# Xem logs của pod
kubectl logs <pod-name>

# Follow logs real-time
kubectl logs -f <pod-name>

# Xem logs của container trước đó (khi pod restart)
kubectl logs <pod-name> --previous

# Xem logs của tất cả pods trong service
kubectl logs -l app=auth-service

# Xem logs với timestamp
kubectl logs <pod-name> --timestamps

# Xem 100 dòng logs gần nhất
kubectl logs <pod-name> --tail=100
```

## Exec vào Container

```powershell
# Exec vào pod với shell
kubectl exec -it <pod-name> -- /bin/sh

# Hoặc bash nếu có
kubectl exec -it <pod-name> -- /bin/bash

# Chạy một lệnh cụ thể
kubectl exec <pod-name> -- ls -la

# Xem biến môi trường
kubectl exec <pod-name> -- env

# Test kết nối đến service khác
kubectl exec <pod-name> -- wget -O- http://auth-service:3000/health
kubectl exec <pod-name> -- curl http://product-service:3001/health
```

## Quản Lý Deployments

```powershell
# Xem deployments
kubectl get deployments

# Chi tiết deployment
kubectl describe deployment <deployment-name>

# Scale deployment
kubectl scale deployment auth-service --replicas=3

# Restart deployment (rolling restart)
kubectl rollout restart deployment auth-service

# Xem trạng thái rollout
kubectl rollout status deployment auth-service

# Xem lịch sử rollout
kubectl rollout history deployment auth-service

# Rollback deployment
kubectl rollout undo deployment auth-service

# Rollback đến revision cụ thể
kubectl rollout undo deployment auth-service --to-revision=2

# Update image
kubectl set image deployment/auth-service auth-service=auth-service:v2
```

## Quản Lý Services

```powershell
# Xem services
kubectl get services

# Hoặc viết tắt
kubectl get svc

# Chi tiết service
kubectl describe service <service-name>

# Xem endpoints của service
kubectl get endpoints

# Xem endpoints của service cụ thể
kubectl get endpoints <service-name>

# Port forward để test local
kubectl port-forward service/auth-service 8080:3000
```

## ConfigMaps & Secrets

```powershell
# Xem ConfigMaps
kubectl get configmaps

# Chi tiết ConfigMap
kubectl describe configmap app-config

# Xem nội dung ConfigMap
kubectl get configmap app-config -o yaml

# Xem Secrets
kubectl get secrets

# Chi tiết Secret
kubectl describe secret app-secrets

# Xem nội dung Secret (base64 encoded)
kubectl get secret app-secrets -o yaml

# Decode secret
kubectl get secret app-secrets -o jsonpath="{.data.jwt-secret}" | base64 -d

# Edit ConfigMap
kubectl edit configmap app-config

# Edit Secret
kubectl edit secret app-secrets
```

## PersistentVolumes & Claims

```powershell
# Xem Persistent Volumes
kubectl get pv

# Xem Persistent Volume Claims
kubectl get pvc

# Chi tiết PV
kubectl describe pv <pv-name>

# Chi tiết PVC
kubectl describe pvc <pvc-name>

# Xóa PVC
kubectl delete pvc <pvc-name>
```

## Events & Debugging

```powershell
# Xem tất cả events
kubectl get events

# Sắp xếp events theo thời gian
kubectl get events --sort-by=.metadata.creationTimestamp

# Events của namespace cụ thể
kubectl get events -n default

# Events của pod cụ thể
kubectl get events --field-selector involvedObject.name=<pod-name>

# Xem events trong 1 giờ qua
kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 20
```

## Resource Usage

```powershell
# Xem resource usage của nodes (cần metrics-server)
kubectl top nodes

# Xem resource usage của pods
kubectl top pods

# Xem usage của pods trong namespace
kubectl top pods -n default

# Xem usage của pod cụ thể
kubectl top pod <pod-name>
```

## Apply & Delete Resources

```powershell
# Apply một file
kubectl apply -f k8s/mongodb.yaml

# Apply tất cả files trong thư mục
kubectl apply -f k8s/

# Apply với dry-run (kiểm tra trước)
kubectl apply -f k8s/mongodb.yaml --dry-run=client

# Delete resource
kubectl delete -f k8s/mongodb.yaml

# Delete tất cả resources trong thư mục
kubectl delete -f k8s/

# Delete với force
kubectl delete -f k8s/mongodb.yaml --force --grace-period=0
```

## Labels & Selectors

```powershell
# Xem pods với labels
kubectl get pods --show-labels

# Lọc pods theo label
kubectl get pods -l app=auth-service

# Lọc với nhiều labels
kubectl get pods -l app=auth-service,version=v1

# Lọc với label selector phức tạp
kubectl get pods -l 'app in (auth-service, product-service)'

# Thêm label
kubectl label pod <pod-name> environment=production

# Xóa label
kubectl label pod <pod-name> environment-

# Update label
kubectl label pod <pod-name> environment=staging --overwrite
```

## Namespace Management

```powershell
# Xem namespaces
kubectl get namespaces

# Tạo namespace
kubectl create namespace dev

# Xóa namespace
kubectl delete namespace dev

# Set default namespace
kubectl config set-context --current --namespace=dev

# Xem resources trong namespace cụ thể
kubectl get pods -n kube-system
```

## Troubleshooting Commands

```powershell
# Kiểm tra tại sao pod không start
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>

# Kiểm tra network connectivity
kubectl run test-pod --rm -it --image=busybox -- sh
# Trong pod: 
# wget -O- http://service-name:port/health
# nslookup service-name

# Kiểm tra DNS
kubectl exec <pod-name> -- nslookup auth-service
kubectl exec <pod-name> -- cat /etc/resolv.conf

# Test connectivity giữa pods
kubectl exec <source-pod> -- ping <target-pod-ip>
kubectl exec <source-pod> -- wget -O- http://<service-name>:<port>/health

# Kiểm tra image trong node
docker exec -it eproject-cluster-control-plane crictl images
docker exec -it eproject-cluster-worker crictl images

# Xem tất cả resources
kubectl get all

# Xem tất cả resources trong namespace
kubectl get all -n default
```

## Useful One-Liners

```powershell
# Restart tất cả deployments
kubectl get deployments -o name | ForEach-Object { kubectl rollout restart $_ }

# Xóa tất cả failed pods
kubectl delete pods --field-selector=status.phase=Failed

# Xóa tất cả evicted pods
kubectl get pods | Select-String "Evicted" | ForEach-Object { kubectl delete pod ($_ -split '\s+')[0] }

# Xem resource requests/limits của tất cả pods
kubectl get pods -o=custom-columns='NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory,CPU-LIM:.spec.containers[*].resources.limits.cpu,MEM-LIM:.spec.containers[*].resources.limits.memory'

# Xem images của tất cả pods
kubectl get pods -o=custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image'

# Tìm pods đang pending
kubectl get pods --field-selector=status.phase=Pending

# Xem tất cả container ports
kubectl get pods -o=custom-columns='NAME:.metadata.name,PORTS:.spec.containers[*].ports[*].containerPort'
```

## Kind Specific Commands

```powershell
# Xem clusters
kind get clusters

# Xem nodes trong cluster
kind get nodes --name eproject-cluster

# Load image vào cluster
kind load docker-image <image-name>:latest --name eproject-cluster

# Load archive vào cluster
kind load image-archive <archive-file> --name eproject-cluster

# Export logs từ cluster
kind export logs --name eproject-cluster ./logs

# Delete cluster
kind delete cluster --name eproject-cluster

# Xem kubeconfig của cluster
kind get kubeconfig --name eproject-cluster
```

## Advanced Debugging

```powershell
# Enable debug logging
kubectl <command> -v=8

# Explain resource
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers

# Get raw JSON/YAML
kubectl get pod <pod-name> -o json
kubectl get pod <pod-name> -o yaml

# Extract specific field with jsonpath
kubectl get pod <pod-name> -o jsonpath='{.status.podIP}'
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Watch specific resource
kubectl get pods <pod-name> -w

# Proxy to API server
kubectl proxy
# Then access: http://localhost:8001/api/v1/namespaces/default/pods
```

## Aliases (Tùy chọn)

Thêm vào PowerShell Profile để sử dụng aliases:

```powershell
# Thêm vào $PROFILE
function k { kubectl $args }
function kgp { kubectl get pods $args }
function kgs { kubectl get services $args }
function kgd { kubectl get deployments $args }
function kdp { kubectl describe pod $args }
function kl { kubectl logs $args }
function klf { kubectl logs -f $args }
function kex { kubectl exec -it $args -- /bin/sh }
```

Reload profile:
```powershell
. $PROFILE
```

---

**Tip**: Sử dụng tab completion cho kubectl commands trong PowerShell!
