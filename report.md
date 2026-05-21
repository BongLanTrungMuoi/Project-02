---
title: Đồ án 2 — Xây dựng hệ thống CD cho YAS (Yet Another Shop)

---

# Đồ án 2 - Xây dựng hệ thống CD cho YAS (Yet Another Shop)

> **Môn học**: DevOps  
> **Đề tài**: Xây dựng pipeline CI/CD và Service Mesh cho hệ thống microservice YAS  
> **Nguồn tham khảo ứng dụng**: https://github.com/nashtech-garage/yas 
> **Repo Source Code**: https://github.com/BongLanTrungMuoi/Project-02
> **Repo GitOps**: https://github.com/BongLanTrungMuoi/yas-gitops  
> **Nhóm**:
> | Họ và tên | MSSV |
> | - | - |
> | Mai Thị Kim Duyên | 23127185 |
> | Nguyễn Văn Minh | 23127423 | 
> | Huỳnh Hạo Nam | 23127431 |
> | Lê Thanh Phong | 23127452 |

---

## Mục lục

[1. Tổng quan](#sec-1)
[2. Kiến trúc và công nghệ](#sec-2)
[3. Cấu trúc thư mục](#sec-3)
[4. Hạ tầng Kubernetes](#sec-4)
[5. CI Pipeline - GitHub Actions](#sec-5)
[6. CD Pipeline - Jenkins](#sec-6)
[7. Destroy Pipeline](#sec-7)
[8. ArgoCD Continuous Delivery (GitOps)](#sec-8)
[9. Service Mesh - Istio và Kiali](#sec-9)
[10. Giám sát hệ thống - Observability](#sec-10)

---

<a name="sec-1"></a>
## 1. Tổng quan

YAS (Yet Another Shop) là ứng dụng e-commerce dạng microservice. Hệ thống gồm các service backend Spring Boot, frontend Next.js, Keycloak để xác thực, PostgreSQL làm database, Kafka/Debezium cho event và CDC, Elasticsearch cho search, Redis cho cache.

Trong đồ án này, nhóm xây dựng hệ thống CI/CD và triển khai YAS lên Kubernetes bằng Minikube. Ngoài phần cơ bản, nhóm triển khai thêm Service Mesh bằng Istio và Kiali để bật mTLS, quan sát topology, cấu hình retry và giới hạn service-to-service bằng AuthorizationPolicy.

| Hạng mục | Trạng thái |
|---|---|
| Kubernetes cluster bằng Minikube | Hoàn thành |
| Helm chart deploy ứng dụng | Hoàn thành |
| CI GitHub Actions build image và push Docker Hub | Hoàn thành |
| Jenkins CD job chọn branch từng service | Hoàn thành |
| Jenkins destroy job xóa namespace theo build | Hoàn thành |
| Istio mTLS, Kiali, retry, AuthorizationPolicy | Hoàn thành |
| Observability  | Hoàn thành | 

---

<a name="sec-2"></a>
## 2. Kiến trúc và công nghệ

### 2.1. Stack ứng dụng

| Thành phần | Công nghệ |
|---|---|
| Backend | Java 21, Spring Boot 3.2, Spring Cloud Gateway |
| Frontend | Next.js |
| Identity | Keycloak, realm `Yas` |
| Database | PostgreSQL, Zalando Postgres Operator |
| Messaging | Kafka, Strimzi Operator, Debezium Connect |
| Search | Elasticsearch, ECK Operator |
| Cache | Redis |
| API Gateway/BFF | `storefront-bff`, `backoffice-bff` |

### 2.2. Stack DevOps

| Thành phần | Công nghệ |
|---|---|
| Kubernetes | Minikube 1 node |
| Package manager | Helm 3 |
| Ingress | NGINX Ingress Controller |
| CI | GitHub Actions |
| CD | Jenkins Pipeline |
| Service Mesh | Istio |
| Mesh visualization | Kiali |
| Metrics | Prometheus |
| TLS/cert | cert-manager |

---

<a name="sec-3"></a>
## 3. Cấu trúc thư mục dự án (Project-02)

Dưới đây là cấu trúc thư mục thực tế của dự án **Project-02** sau khi tích hợp toàn bộ các thành phần **GitOps (ArgoCD)**, **Service Mesh (Istio)** và **Observability (LGTM Stack & OpenTelemetry)**:

```text
Project-02/
├── .github/workflows/              # CI pipelines (GitHub Actions) cho các services
├── Jenkinsfile                     # CD pipeline triển khai ứng dụng (developer_build)
├── Jenkinsfile-destroy            # Pipeline xóa toàn bộ môi trường (cleanup)
├── report.md                      # Báo cáo đồ án chính
├── screenshots/                   # Hình ảnh minh chứng triển khai hệ thống
│
├── k8s-cd/                        # Toàn bộ tài nguyên Kubernetes & DevOps
│   ├── deploy/                   # Scripts & manifests triển khai hạ tầng
│   │   ├── 01-setup-operators.sh     # Cài đặt operators (cert-manager, postgres, kafka, elastic, monitoring)
│   │   ├── 02-setup-service-mesh.sh  # Cài đặt Istio, Kiali và cấu hình mesh
│   │   ├── 03-setup-argocd.sh        # Cài đặt ArgoCD và bootstrap GitOps apps
│   │   ├── cluster-config.yaml       # Cấu hình chung cluster (domain, credentials,...)
│   │   ├── DeployCLI.md             # Hướng dẫn deploy bằng CLI
│   │   |
│   │   ├── argocd/                 # GitOps Applications (ArgoCD)
│   │   │   ├── app-dev.yaml
│   │   │   └── app-staging.yaml
│   │   │
│   │   ├── kafka/ postgres/ elasticsearch/ keycloak/ zookeeper/
│   │   │   # Hạ tầng dữ liệu & authentication (operators + configs)
│   │   │
│   │   ├── istio/                  # Service Mesh configuration
│   │   │   ├── mtls.yaml               # Bật mTLS STRICT
│   │   │   ├── destination-rule.yaml   # TLS policy giữa services
│   │   │   ├── auth-policy.yaml        # Authorization policy
│   │   │   ├── virtual-service-retry-template.yaml # Retry/traffic policy
│   │   │   ├── keycloak-internal-dns.yaml         # ServiceEntry cho Keycloak
│   │   │   ├── telemetry-monitor.yaml  # Metrics/monitoring mesh
│   │   │   └── script/                 # Scripts test & vận hành mesh
│   │   │
│   │   ├── observability/         # LGTM stack (Logs, Metrics, Traces)
│   │   │   ├── loki.values.yaml
│   │   │   ├── promtail.values.yaml
│   │   │   ├── tempo.values.yaml
│   │   │   ├── prometheus.values.yaml
│   │   │   ├── opentelemetry/
│   │   │   └── grafana/
│   │   │
│   │   └── evidence/              # Kết quả test Service Mesh & observability
│   │       ├── auth-policy-test-3.txt
│   │       ├── retry-failure-evidence.txt
│   │       └── retry-success-evidence.txt
│   │
├── charts/                       # Helm charts cho toàn bộ hệ thống YAS
│   ├── backend/ ui/              # Base charts cho backend & frontend
│   ├── yas-configuration/        # ConfigMap/Secret dùng chung
│   ├── backoffice-* / storefront-* / swagger-ui
│   └── microservices/            # Các service độc lập (cart, order, payment, ...)
```

```text
yas-gitops/
├── templates/                    # Helm templates cho ArgoCD Applications
│   └── applications.yaml         # Template generate Application resources
│
├── Chart.yaml                    # Metadata Helm chart của GitOps repo
├── README.md                     # Hướng dẫn sử dụng và triển khai GitOps
├── value-dev.yaml                # Values cho môi trường development
└── value-staging.yaml            # Values cho môi trường staging
```

---

<a name="sec-4"></a>
## 4. Hạ tầng Kubernetes & Kiến trúc GitOps (Hybrid)

Triển khai hạ tầng K8s được thực hiện một cách tự động và đồng bộ qua 5 giai đoạn chính (Phases).

### 4.1. Khởi tạo Minikube

Minikube được cấu hình với tài nguyên lớn để đảm bảo vận hành ổn định hệ thống microservice YAS cùng toàn bộ cụm công cụ bổ trợ (PostgreSQL, Kafka, Elasticsearch, ArgoCD, Istio, Grafana...):

```bash
minikube delete
minikube start --driver=docker \
  --disk-size='80000mb' \
  --memory='18g' \
  --cpus='12' \
  --kubernetes-version=v1.29.0
minikube addons enable ingress
```

Addon `ingress` của Minikube được kích hoạt để tự động cài đặt NGINX Ingress Controller. Ingress Controller này sẽ chạy ở dạng Service có type là **NodePort** trên cụm, ánh xạ cổng HTTP/HTTPS (80/443) ra ngoài máy Host của developer.

**Hình 1: Trạng thái Minikube và Cluster Nodes**
![01_minikube_status_nodes](https://hackmd.io/_uploads/SkPK42dJfg.png)
*Hình 1: Giao diện terminal chạy lệnh `minikube status` và `kubectl get nodes -o wide` xác nhận cấu hình cluster.*

---

### 4.2. Phase 1 - Operators và Observability (Giám sát hệ thống)

Script khởi chạy:
```bash
cd k8s-cd/deploy/
./01-setup-operators.sh
```
*Để kích hoạt cụm công cụ giám sát đầy đủ (mặc định tắt để tiết kiệm RAM/CPU khi debug):*
```bash
ENABLE_OBSERVABILITY=true ./01-setup-operators.sh
```

Giai đoạn này cài đặt các **CRD (Custom Resource Definitions)** và các **Operators** nền tảng để tự động hóa việc quản lý cơ sở dữ liệu và giám sát:

| Thành phần (Component) | Namespace | Vai trò trong hệ thống |
|---|---|---|
| **cert-manager** | `cert-manager` | Tự động phát hành và quản lý chứng chỉ TLS/SSL nội bộ |
| **Postgres Operator** (Zalando) | `postgres` | Quản lý cụm cơ sở dữ liệu PostgreSQL có tính sẵn sàng cao |
| **Strimzi Kafka Operator** | `kafka` | Tự động quản lý cụm Apache Kafka và Kafka Connectors |
| **ECK Operator** (Elastic Cloud) | `elasticsearch` | Quản lý cụm lưu trữ và tìm kiếm Elasticsearch + Kibana |
| **Keycloak Operator** | `keycloak` | Tự động cấu hình và vận hành Identity Provider Keycloak |
| **OpenTelemetry Operator** * | `observability` | Thu thập và xử lý tự động dữ liệu giám sát (Metrics & Traces) |
| **Loki, Tempo, Promtail** * | `observability` | Stack giám sát logs tập trung (Loki) và truy vết phân tán (Tempo) |
| **Kube-Prometheus Stack** * | `observability` | Thu thập chỉ số hệ thống (Prometheus) và giao diện hiển thị (Grafana) |
| **Grafana Operator** * | `observability` | Tự động cấu hình các Grafana Dashboards và Datasources |

*\* Lưu ý: Chỉ được cài đặt khi biến `ENABLE_OBSERVABILITY=true`.*

---

### 4.3. Phase 2 - Service Mesh (Istio & Kiali)

Script khởi chạy:
```bash
./02-setup-service-mesh.sh
```

Giai đoạn này triển khai **Istio Service Mesh** để thiết lập các chính sách bảo mật mạng và kiểm soát lưu lượng giữa các microservices:

1. **Khởi tạo Control Plane:** Cài đặt `istio-base` và `istiod` vào namespace `istio-system`.
2. **Cấu hình Sidecar Injection:** Gán nhãn `istio-injection=enabled` cho các namespace ứng dụng mục tiêu (`yas-dev` và `yas-staging`) và namespace `ingress-nginx` để tích hợp Ingress Controller vào Mesh.
3. **Kích hoạt Kiali (Nâng cao):** Cài đặt `kiali-server` (nếu có Observability) để trực quan hóa topology luồng đi của request.
4. **Áp dụng các chính sách Mesh:**
   * `mtls.yaml`: Bật chế độ bảo mật **mTLS STRICT** cho traffic nội bộ namespace.
   * `destination-rule.yaml`: Cấu hình chế độ kết nối `ISTIO_MUTUAL` mặc định.
   * `ingress-mtls.yaml`: Cấu hình Ingress Nginx bảo mật đi vào Mesh.
   * `auth-policy.yaml`: Thiết lập chính sách **AuthorizationPolicy** giới hạn nghiêm ngặt các service được phép giao tiếp với nhau.
   * `virtual-service-retry-template.yaml`: Áp dụng chính sách **Tự động Retry (3 lần nếu trả về lỗi 5xx)** cho các API.
   * `keycloak-internal-dns.yaml`: Áp dụng DNS nội bộ giải quyết vấn đề issuer của Keycloak.

**Hình 2: Trạng thái Inject Sidecar và Pods chạy trong Namespace**
![03_kubectl_get_pods_yas52](https://hackmd.io/_uploads/ByA3NhOJGx.png)
*Hình 2: Danh sách Pods có Envoy sidecar được tiêm (2/2 containers ở trạng thái READY).*

---

### 4.4. Phase 3 - GitOps Bootstrap bằng ArgoCD

Script khởi chạy:
```bash
./03-setup-argocd.sh
```

Để chuyển đổi hoàn toàn sang mô hình khai báo khai triển **GitOps**, nhóm cài đặt **ArgoCD** và áp dụng mô hình **Application-of-Applications (Root App)**:

1. **Cài đặt ArgoCD Server:** Triển khai lên namespace `argocd` với tham số `--insecure`.
2. **Nạp các Root Application khai báo:**
   * `app-dev.yaml`: Khai báo ứng dụng gốc `yas-root-dev`, trỏ về GitOps repository, nhánh `main`, nạp giá trị từ file cấu hình `value-dev.yaml` và đồng bộ vào namespace `yas-dev` (môi trường dev).
   * `app-staging.yaml`: Khai báo ứng dụng gốc `yas-root-staging`, trỏ về cùng repository GitOps, nhánh `main`, nạp giá trị từ file cấu hình `value-staging.yaml` và đồng bộ tự động vào namespace `yas-staging` (môi trường staging).

**Hình 3: ArgoCD Applications Dashboard**
![04_argocd_applications_dashboard](https://hackmd.io/_uploads/SyU6V2ukMg.png)
*Hình 3: Giao diện ArgoCD Dashboard quản trị các ứng dụng ở trạng thái Healthy & Synced.*

---

### 4.5. Phase 4 - Data Layer (Được quản lý tự động bởi ArgoCD)

Data Layer được ArgoCD quét từ thư mục Helm chart của repo GitOps và tự động triển khai đồng bộ vào namespace ứng dụng. Giai đoạn này cài đặt toàn bộ hệ thống cơ sở dữ liệu và hàng đợi thông điệp bao gồm:

* **PostgreSQL:** Tạo các cụm DB cho từng microservice qua Postgres Operator.
* **Apache Kafka & Connectors:** Tạo cụm Kafka bằng Strimzi Operator, kết hợp Kafka Connect và Debezium connector thực hiện đồng bộ CDC (Change Data Capture).
* **Elasticsearch & Kibana:** Triển khai dịch vụ tìm kiếm tối ưu qua ECK Operator.
* **Redis:** Caching cho các dịch vụ frontend/backend.
* **Keycloak:** Hệ thống xác thực danh tính tập trung (SSO) và tự động nạp Yas Realm Import.

**Hình 4: Trạng thái các Pods Data Layer trong Mesh**
![03_kubectl_get_pods_yas52](https://hackmd.io/_uploads/SJnzwhuJzx.png)
*Hình 4: Danh sách Pods data layer (postgres, kafka, zookeeper, elasticsearch) chạy ổn định.*

---

### 4.6. Phase 5 - Application layer (Được quản lý tự động bởi ArgoCD)

ArgoCD tự động kích hoạt đồng bộ hóa và deploy các thành phần thuộc tầng ứng dụng (Application Layer):

1. **yas-configuration:** Helm chart tổng hợp cấu hình ConfigMap/Secret kết hợp Stakater Reloader tự động reload Pod khi config thay đổi.
2. **API Gateways & BFF:** Deploy `backoffice-bff` và `storefront-bff`.
3. **Frontend UIs:** Deploy `backoffice-ui`, `storefront-ui`, và công cụ khám phá API `swagger-ui`.
4. **Tầng Microservices Core (9 dịch vụ):** Deploy `cart`, `customer`, `inventory`, `media`, `order`, `product`, `search`, `tax`, `sampledata`.
5. **Populate Media Data:** Tự động sao chép dữ liệu ảnh mẫu vào pod `media`.

**Hình 5: Trạng thái Pods tầng ứng dụng hoạt động ổn định**
![03_kubectl_get_pods_yas52](https://hackmd.io/_uploads/SyyMH2OyGe.png)
*Hình 5: Toàn bộ 9 microservices core và UIs hoạt động với sidecar Envoy chạy ổn định.*

---

<a name="sec-5"></a>
## 5. CI Pipeline - GitHub Actions

Hệ thống tích hợp liên tục (CI) được tự động hóa hoàn toàn bằng GitHub Actions. Mỗi dịch vụ thành phần (microservice) có một file workflow riêng biệt đặt tại `.github/workflows/<service-name>.yaml`.

### 5.1. Cấu hình và Kích hoạt Pipeline

Pipeline được kích hoạt (trigger) tự động theo hai điều kiện:
* Có thao tác **Push** hoặc **Pull Request** vào nhánh chính `main` liên quan đến thư mục của service tương ứng.
* Kích hoạt thủ công qua cơ chế `workflow_dispatch`.

**Hình 6: Danh sách Pipeline GitHub Actions đã chạy thành công**
![05_github_actions_workflow_runs](https://hackmd.io/_uploads/rJfmB3OJfg.png)
*Hình 6: Danh sách các lần chạy thành công (green) của pipeline CI trên các nhánh.*

### 5.2. Các bước triển khai trong Pipeline (Build Steps)

Một chu kỳ CI đầy đủ gồm các bước sau:
1. **Checkout Code:** Sử dụng `actions/checkout@v4` để lấy mã nguồn mới nhất.
2. **Setup JDK / Node environment:** 
   * Đối với backend Spring Boot: Thiết lập Java 21 bằng `actions/setup-java@v4`.
   * Đối với frontend Next.js: Thiết lập Node.js 20 bằng `actions/setup-node@v4`.
3. **Lint & Code Formatting:** Kiểm tra cú pháp, format mã nguồn thông qua Prettier và Linter để bảo đảm chất lượng code.
4. **Build Code:**
   * Backend Spring Boot: Chạy lệnh `mvn clean install -pl <service> -am` để đóng gói file JAR.
   * Frontend: Thực thi `npm ci && npm run build` để đóng gói giao diện sản phẩm.
5. **Build & Push Docker Image:** 
   * Đăng nhập vào Docker Hub bằng `docker/login-action@v3` sử dụng Secrets lưu trữ trong GitHub Settings (`DOCKERHUB_USERNAME` và `DOCKERHUB_TOKEN`).
   * Xây dựng Docker Image bằng `docker/build-push-action@v6` và gắn nhãn (tag) tự động.

**Hình 7: Các bước thực thi chi tiết của GitHub Actions Workflow**
![06_github_actions_build_steps](https://hackmd.io/_uploads/SydXBndyfg.png)
*Hình 7: Chi tiết các bước checkout, login Docker Hub, compile code và push image.*

### 5.3. Quy tắc Đặt tên và Quản lý Tag Image trên Docker Hub

Để quản lý chính xác phiên bản image và tránh ghi đè mã nguồn không mong muốn, nhóm áp dụng quy tắc gắn thẻ (Docker Tag) động dựa trên nhánh git:
* Nếu code được đẩy lên nhánh **`main`**, tag image được đặt cố định là **`latest`** và **`commit SHA`** đại diện cho bản build ổn định nhất hiện tại.
* Nếu code được đẩy lên **nhánh phát triển khác (feature/bugfix)**, tag image sẽ lấy mã hash của commit (tức **`commit SHA`**) để định danh độc bản.

Quy trình tự động hóa thẻ tag được khai báo trong GitHub Actions:
```yaml
- name: Determine Docker Tag
  run: |
    if [ "${{ github.ref_name }}" == "main" ]; then
      echo "DOCKER_TAG=latest" >> $GITHUB_ENV
    else
      echo "DOCKER_TAG=${{ github.sha }}" >> $GITHUB_ENV
    fi
```
**Hình 8: Image được build từ branch main**
![27_main_branch_tag](https://hackmd.io/_uploads/rkSSBhd1Me.png)
*Hình 8: Image được build từ brach main có hai phiên bản là `latest` và `commit SHA`.*

**Hình 9: Image được build từ branch khác main**
![28_other_branch_tag](https://hackmd.io/_uploads/rk2BBhuyzl.png)
*Hình 9: Image được build từ các branch khác ngoài main có dạng `commit SHA`.*

---

<a name="sec-6"></a>
## 6. CD Pipeline - Jenkins

Sau khi CI đẩy image thành công lên Docker Hub, CD Pipeline trên Jenkins được kích hoạt để triển khai (Deploy) ứng dụng lên cụm Kubernetes. CD được thiết kế dưới dạng **Parameterized Pipeline** linh hoạt (job `developer_build`), cho phép nhà phát triển triển khai độc lập hoặc đồng thời nhiều service.

### 6.1. Tham số hóa CD (Parameterized CD)

Nhà phát triển có thể tùy biến cấu hình các tham số khi chạy Job:
* `BUILD_ID`: Mã ID định danh cho đợt build (ví dụ: `52`). Mã này dùng để cô lập môi trường bằng cách tạo một namespace riêng biệt `yas-<BUILD_ID>`.
* `DEPLOY_<SERVICE>`: Tùy chọn boolean kích hoạt deploy service tương ứng.
* `BRANCH_<SERVICE>`: Dropdown hoặc textbox nhập nhánh git hoặc commit SHA của service đó để Jenkins tự động phân giải tag image tương ứng.

**Hình 10: Jenkins Job Parameter Select Form**
![08_jenkins_developer_build_params](https://hackmd.io/_uploads/S1pLBnO1Gx.png)
*Hình 10: Giao diện form tham số Jenkins CD cho phép chọn nhánh và ID đợt build cụ thể.*

### 6.2. Phân giải Tag Image động (Dynamic Image Tag Resolution)

Khi bắt đầu job, Jenkins kiểm tra tham số branch của từng service được bật deploy:
* Nếu branch là `main`, Jenkins tự động cấu hình Helm deploy tag `latest`.
* Nếu branch khác `main`, Jenkins thực thi lệnh truy vấn git từ xa (`git ls-remote`) để tìm mã SHA commit mới nhất của nhánh đó trên GitHub và gán làm tag deploy:
  ```groovy
  if (branchName != 'main') {
      tag = sh(
          script: "git ls-remote https://github.com/Hownameee/yas.git ${branchName} | cut -f1",
          returnStdout: true
      ).trim()
  }
  ```
Cách này đảm bảo môi trường kiểm thử luôn phản ánh chính xác commit code mới nhất của nhà phát triển.

### 6.3. Tự động hóa triển khai bằng Helm và Thiết lập Ingress

Jenkins CD thực thi tải repo mã nguồn cấu hình Helm và chạy nâng cấp ứng dụng tự động trên Kubernetes cluster:
```bash
helm upgrade --install yas-storefront k8s-cd/charts/storefront-ui \
  --namespace yas-${BUILD_ID} \
  --create-namespace \
  --set image.tag=${TAG} \
  --set ingress.host=storefront-dev-${BUILD_ID}.yas.local.com
```

Mỗi đợt triển khai sẽ sinh ra các domain Ingress riêng biệt được định dạng theo cấu trúc: `*-dev-<BUILD_ID>.yas.local.com`. Cuối Job, Jenkins hiển thị bảng hướng dẫn ánh xạ IP Minikube và domain Ingress để nhà phát triển cấu hình file `/etc/hosts` trên máy host cá nhân.

**Hình 11: Terminal xác nhận Helm deployment thành công trong Namespace cô lập**
![10_helm_list_deployed_releases](https://hackmd.io/_uploads/Hklor3O1Gl.png)
*Hình 11: Trạng thái pods và Helm releases đã cài đặt thành công trên namespace yas-dev.*

**Hình 12: Giao diện Storefront UI truy cập thành công qua Ingress Host**
![11_yas_storefront_ui_verification](https://hackmd.io/_uploads/Hy_qS3_Jze.png)
*Hình 12: Trang chủ Storefront YAS hiển thị dữ liệu đầy đủ qua domain Ingress nội bộ.*

---

<a name="sec-7"></a>
## 7. Destroy Pipeline -  Jenkins

Nhằm tối ưu hóa tài nguyên cụm Minikube khi nhà phát triển hoàn tất công việc kiểm thử, nhóm xây dựng CD Job dọn dẹp tự động (Undeploy) mang tên `Jenkinsfile-destroy`.

### 7.1. Cấu hình Tham số Dọn dẹp
* `TARGET_BUILD_ID`: Mã ID của đợt deploy cần dọn dẹp (ví dụ: `52`).
* `CONFIRM_DESTROY`: Boolean bắt buộc click check để xác nhận hành vi phá hủy tài nguyên, tránh rủi ro xóa nhầm namespace.

### 7.2. Logic thực thi Cleanup trong Jenkins

Jenkins dọn dẹp triệt để tài nguyên Helm release chạy trong namespace mục tiêu, sau đó thực thi xóa namespace để giải phóng hoàn toàn CPU, RAM và IP:
```bash
# Gỡ cài đặt tất cả các Helm releases trong namespace
helm list -n yas-${TARGET_BUILD_ID} -q | xargs -r helm uninstall -n yas-${TARGET_BUILD_ID}

# Xóa namespace
kubectl delete ns yas-${TARGET_BUILD_ID} --ignore-not-found=true
```

**Hình 13: Console Log của Jenkins Destroy Job hoàn thành dọn dẹp sạch cụm**
![12_jenkins_destroy_build_console_logs](https://hackmd.io/_uploads/BJ75r3OyGl.png)
*Hình 13: Logs xác nhận xóa namespace yas-52 và thu hồi các dịch vụ.*

---

<a name="sec-8"></a>
## 8. ArgoCD Continuous Delivery (GitOps)

Đồ án cải tiến mạnh mẽ hạ tầng CD thông qua việc tích hợp hệ thống **ArgoCD** theo mô hình **GitOps khai báo (Declarative)**. Toàn bộ kiến trúc và trạng thái mong muốn của cụm (Desired State) được định nghĩa trong GitOps repository (`yas-gitops`). ArgoCD chịu trách nhiệm đồng bộ hóa liên tục trạng thái thực tế trên cụm với mã nguồn trên Git.

### 8.1. Cấu trúc GitOps Repository
GitOps repo được tổ chức thành các thư mục môi trường riêng biệt:
* `value-dev.yaml`: Khai báo giá trị cấu hình cho môi trường phát triển (Namespace `yas-dev`).
* `value-staging`: Khai báo cấu hình riêng biệt cho Staging (Namespace `yas-staging`).

**Hình 14: Cấu trúc tệp tin khai báo tài nguyên trong GitOps Repository**
![13_github_yas_gitops_repo](https://hackmd.io/_uploads/HkojB3_JMl.png)
*Hình 14: Cấu trúc thư mục của repository `yas-gitops` lưu trữ Helm values.*

### 8.2. Root Application Pattern (Application-of-Applications)

Nhóm áp dụng mô hình thiết kế **Application-of-Applications** để quản lý dễ dàng toàn bộ tài nguyên. Một Root Application duy nhất sẽ quản lý các Application con (Postgres, Kafka, microservices).
* **Trạng thái môi trường Dev (`yas-dev`):** Trỏ về nhánh `main` của repo GitOps. Môi trường này cấu hình tự động đồng bộ (**Auto-Sync** kèm **Self-Heal** và **Prune Resources**), lập tức phát hiện thay đổi trên Git và cập nhật ứng dụng.
* **Trạng thái môi trường Staging (`yas-staging`):** Trỏ về các thẻ phiên bản Git (**Git Tags** ví dụ: `v1.2.3`). Quá trình đồng bộ yêu cầu sự phê duyệt thủ công (Manual Sync) từ DevOps Engineer hoặc QC để bảo đảm an toàn.

**Hình 15: ArgoCD triển khai App cho môi trường Staging**
![17_argocd_root_app_healthy](https://hackmd.io/_uploads/S1TnBndkzx.png)
*Hình 15: ArgoCD hiển thị app staging (tương tự với app dev)*

Quy trình GitOps của ArgoCD trong môi trường staging được thực hiện theo cơ chế tự động đồng bộ trạng thái mong muốn (desired state) từ Git Repository xuống Kubernetes cluster.

Ban đầu, ứng dụng root staging đang ở trạng thái đã đồng bộ hoàn toàn (`Synced & Healthy`). ArgoCD liên tục theo dõi repository GitOps theo chu kỳ để phát hiện thay đổi cấu hình mới.

**Hình 16: Trạng thái ban đầu của Root App Staging trước khi triển khai**
![18_argocd_root_app_dev_values](https://hackmd.io/_uploads/H1yRShd1Gx.png)
*Hình 16: Ứng dụng root staging đang ở trạng thái Synced & Healthy trước khi có thay đổi cấu hình mới từ GitOps repository.*

Sau đó, pipeline CI/CD hoặc developer thực hiện cập nhật cấu hình triển khai trong GitOps repository và tạo commit mới chứa thay đổi version image hoặc manifest Kubernetes.

**Hình 17: Commit mới được đẩy lên GitOps Repository**
![13_github_yas_gitops_repo](https://hackmd.io/_uploads/HJq0SnuyMe.png)
*Hình 17: Repository GitOps xuất hiện commit mới chứa thay đổi cấu hình triển khai cho môi trường staging.*

Khi ArgoCD phát hiện repository có thay đổi mới, hệ thống sẽ chuyển ứng dụng sang trạng thái `OutOfSync` và bắt đầu quá trình đồng bộ cấu hình mới từ Git xuống Kubernetes cluster.

**Hình 18: ArgoCD phát hiện thay đổi và bắt đầu quá trình đồng bộ**
![16_argocd_root_app_syncing](https://hackmd.io/_uploads/SJ_yU3_1Gl.png)
*Hình 18: ArgoCD chuyển ứng dụng sang trạng thái OutOfSync/Syncing và tiến hành áp dụng cấu hình mới vào cluster Kubernetes.*

Sau khi quá trình đồng bộ hoàn tất thành công, ArgoCD cập nhật trạng thái ứng dụng thành `Synced & Healthy`, thể hiện rằng toàn bộ tài nguyên Kubernetes đã khớp với trạng thái mong muốn được khai báo trong GitOps repository.

**Hình 19: ArgoCD hoàn tất đồng bộ Root App Staging**
![17_argocd_root_app_healthy](https://hackmd.io/_uploads/H10l83O1Ge.png)
*Hình 19: Root App Staging đạt trạng thái Synced & Healthy sau khi hoàn tất quá trình đồng bộ tự động.*

Cuối cùng, có thể kiểm tra chi tiết deployment của service sau khi đồng bộ thành công để xác nhận image version mới và trạng thái hoạt động của workload trong cluster.

**Hình 20: Chi tiết deployment của service sau khi đồng bộ**
![15_argocd_product_staging_healthy](https://hackmd.io/_uploads/BkE-8nOJzx.png)
*Hình 20: Giao diện chi tiết service trên ArgoCD hiển thị deployment đã được cập nhật thành công và đang hoạt động ổn định trong môi trường staging.*

---

<a name="sec-9"></a>
## 9. Service Mesh - Istio và Kiali

### 9.1. Thiết lập Bảo mật STRICT mTLS nội cụm

Nhóm áp dụng chính sách **STRICT mTLS** (Mutual TLS) bảo mật kênh truyền tin cậy 2 chiều giữa tất cả các pod chạy sidecar trong namespace ứng dụng.
* `PeerAuthentication STRICT` chặn đứng hoàn toàn các request plain-text chưa mã hóa đi vào namespace.
* `DestinationRule ISTIO_MUTUAL` cấu hình các sidecar tự động bắt tay TLS khi giao tiếp.

File cấu hình:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: ${NAMESPACE}
spec:
  mtls:
    mode: STRICT
```

**Hình 21: Lệnh xác minh mTLS STRICT hoạt động trên cụm**
![19_istio_peerauthentication_strict](https://hackmd.io/_uploads/Sy4GInu1fl.png)
*Hình 21: Tệp tin PeerAuthentication mTLS STRICT chi tiết bảo mật mạng nội bộ.*

### 9.2. Trực quan hóa Topology kết nối bằng Kiali

Kiali scrape metrics từ sidecar thông qua Prometheus để vẽ đồ thị topology cuộc gọi thời gian thực, hiển thị trực quan các khóa bảo mật (biểu tượng padlock) chứng minh mTLS STRICT đang hoạt động.

**Hình 22: Kiali Dashboard trực quan hóa sơ đồ kết nối nội cụm**
![21_kiali_mesh_topology](https://hackmd.io/_uploads/r1n7U3_yzg.png)
*Hình 22: Bản đồ topo kết nối có biểu tượng khóa mTLS giữa các microservices YAS.*

**Hình 23: Kiali Graph toàn vẹn luồng traffic có mTLS bảo mật**
![22_kiali_full_mesh_topology](https://hackmd.io/_uploads/SkpNU2d1Ml.png)
*Hình 23: Bản đồ mesh dark mode hiển thị toàn bộ luồng traffic nghiệp vụ từ Ingress Gateway.*

### 9.3. Chính sách Tự động Retry khi lỗi Flaky (5xx)

Nhóm cấu hình chính sách **VirtualService Retry** cho phép tự động gọi
lại 3 lần nếu service đích trả về lỗi 5xx. Cơ chế này giúp cô lập và
triệt tiêu lỗi mạng tạm thời (flaky network).

``` yaml
retries:
  attempts: 3
  perTryTimeout: 3s
  retryOn: 5xx,connect-failure,refused-stream,gateway-error
```

Để chứng minh, nhóm dựng service giả lập `retry-flaky` (trả về lỗi
`500 -> 500 -> 200`). Khi client gọi qua Istio, sidecar Envoy tự động âm
thầm retry 2 lần lỗi 500 và nhận về kết quả thành công 200 ở lần thứ 3.

**Hình 24: Terminal cấu hình VirtualService Retry của Product service**
![23_istio_virtualservice_retry](https://hackmd.io/_uploads/ry9rI3_kzl.png)
*Hình 24: Cấu hình VirtualService chi tiết với tham số retry attempts.*

**Hình 25: Trạng thái sinh traffic thành công nhờ cơ chế Retry tự động** 
![24_kiali_traffic_retry_graph](https://hackmd.io/_uploads/BynLL2Oyzl.png)
*Hình 25: Kiali ghi nhận traffic phục hồi thành công (HTTP 200) sau chuỗi retry.*

Để làm rõ và minh chứng cho sự vận hành hoàn hảo của chính sách tự động
Retry tại tầng mạng Sidecar Proxy (Envoy), nhóm đã tiến hành các kịch
bản thực nghiệm thực tế trên hệ thống và thu thập các bản ghi logs/chỉ
số (metrics) hệ thống dưới đây:

**Kịch bản 1: Bằng chứng về "Retry Thành Công" (Retry Success
Evidence)**

Đây là bằng chứng trực quan cho thấy khi xảy ra lỗi Flaky (lỗi mạng chập
chờn, dịch vụ gián đoạn tạm thời), hệ thống tự động phục hồi mà không
ảnh hưởng tới client:

-   **Bản ghi logs thực tế từ Terminal:**

``` text
[RETRY SUCCESS] One client request should finish as 200 after upstream returns 500 twice.
HTTP/1.1 200 OK
server: envoy
date: Sat, 16 May 2026 06:48:01 GMT
x-envoy-upstream-service-time: 54
transfer-encoding: chunked

flaky 200 attempt 3
```

-   **Phân tích kỹ thuật chi tiết:**
    -   **Mô tả hiện tượng:** Dịch vụ giả lập `retry-flaky` được lập
        trình để trả về liên tiếp các mã lỗi:
        `500 (Lần gọi 1) -> 500 (Lần gọi 2) -> 200 OK (Lần gọi 3)`.
    -   **Vai trò của Envoy:** Khi client gửi **duy nhất 1 request**,
        sidecar Envoy phía gọi đi đã tự động đánh chặn phản hồi 500 của
        2 lần đầu và tiến hành gửi lại request dựa trên cấu hình khai
        báo `attempts: 3` của VirtualService.
    -   **Kết quả:** Ở lần gọi thứ 3, dịch vụ phản hồi thành công.
        Client nhận về mã **`200 OK`** với nội dung body
        **`flaky 200 attempt 3`**. Toàn bộ quá trình lỗi và tự động gọi
        lại này hoàn toàn trong suốt (transparent) và diễn ra âm thầm ở
        tầng sidecar proxy, giúp bảo vệ ứng dụng (Application Layer)
        khỏi các sự cố chập chờn tạm thời.

**Kịch bản 2: Bằng chứng về "Retry Thất Bại do vượt giới hạn" (Retry
Failure Evidence)**

Trong trường hợp dịch vụ thượng nguồn gặp lỗi nặng liên tục không thể
phục hồi (hoặc endpoint không hỗ trợ retry), Envoy sẽ thực thi chính
sách giới hạn số lần thử để tránh gây ra hiện tượng nghẽn luồng mạng
(Cascading Failures):

-   **Bản ghi logs thực tế từ Terminal:**

``` text
[TRIGGER 500] retry-test serviceAccount=storefront-bff -> product actuator endpoint
HTTP/1.1 500 Internal Server Error
vary: Origin,Access-Control-Request-Method,Access-Control-Request-Headers
x-content-type-options: nosniff
x-xss-protection: 0
cache-control: no-cache, no-store, max-age=0, must-revalidate
pragma: no-cache
expires: 0
x-frame-options: DENY
content-type: application/json
date: Sat, 16 May 2026 06:48:00 GMT
x-envoy-upstream-service-time: 85
server: envoy
transfer-encoding: chunked

{"statusCode":"500 INTERNAL_SERVER_ERROR","title":"Internal Server Error","detail":"No static resource actuator/health.","fieldErrors":null}
```

-   **Bằng chứng chỉ số (Envoy/Prometheus Stats Evidence):**

``` text
istiocustom.istio_requests_total...destination_workload.product...response_code.500.grpc_response_status.response_flags.URX.connection_security_policy.unknown: 21
```

-   **Phân tích kỹ thuật chi tiết:**
    -   **Mô tả hiện tượng:** Client `retry-test` gọi tới endpoint
        `/actuator/health` của microservice `product`. Do endpoint này
        không được định nghĩa tài nguyên tĩnh, microservice trả về lỗi
        **`500 Internal Server Error`** liên tục.
    -   **Giải thích về cờ `URX`:** Trong chỉ số giám sát
        `istio_requests_total` của Envoy proxy, cuộc gọi này ghi nhận cờ
        phản hồi (Response Flag) là **`URX`**:
        -   **`UR` (Upstream Reset):** Chỉ ra kết nối thượng nguồn gặp
            sự cố hoặc bị đóng đột ngột.
        -   **`URX` (Upstream Retry Limit Exceeded):** Đây là bằng chứng
            đắt giá cấp hệ thống chứng minh Envoy đã **gọi lại đầy đủ 3
            lần** theo đúng cấu hình VirtualService, nhưng dịch vụ đích
            vẫn trả về lỗi. Sau khi vượt quá giới hạn 3 lần thử
            (`attempts: 3`), Envoy chấm dứt retry để giải phóng tài
            nguyên và trả về lỗi 500 cuối cùng cho client.

### 9.4. Giới hạn Service-to-Service bằng AuthorizationPolicy

Nhóm áp dụng chính sách **AuthorizationPolicy** giới hạn nghiêm ngặt
quyền gọi API giữa các microservice. Ví dụ: Dịch vụ `product` chỉ cho
phép Ingress Gateway, `backoffice-bff`, và `storefront-bff` kết nối. Bất
kỳ kết nối trái phép nào từ các pod khác sẽ bị Envoy sidecar chặn ngay
lập tức và trả về mã lỗi **`403 Forbidden` (RBAC: access denied)**.

``` yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-product-callers
  namespace: yas-52
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: product
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/ingress-nginx/sa/ingress-nginx
              - cluster.local/ns/yas-52/sa/storefront-bff
```

**Hình 26: Danh sách các chính
sách AuthorizationPolicy cài đặt trên namespace**
![20_kubectl_get_authorizationpolicies](https://hackmd.io/_uploads/rkaD8nukGe.png)
*Hình 2: Danh sách AuthorizationPolicy phân quyền chi tiết cho từng microservice.*

Để kiểm thử thực tế, nhóm chạy script tạo 2 Pod: `auth-allowed-storefront-bff` (giao diện bff hợp lệ) và `auth-blocked-default` (pod tự do). Kết quả `curl` từ 2 pod chứng minh tính năng bảo mật:
* Pod hợp lệ -> gọi product API -> trả về **`200 OK`**.
* Pod không phận sự -> gọi product API -> trả về **`403 Forbidden (RBAC: access denied)`**.

**Hình 27: Kiali trực quan hóa luồng traffic lỗi bị AuthorizationPolicy chặn lại**
![25_kiali_error_traffic_retry](https://hackmd.io/_uploads/Bk6Ko2_1fg.png)
*Hình 27: Sơ đồ Kiali mô tả chi tiết đường đi của traffic lạ bị hệ thống Service Mesh chặn đứng với mã lỗi.*

---

<a name="sec-10"></a>
## 10. Giám sát hệ thống - Observability

Phần giám sát và quan sát hệ thống (Observability) được thiết lập ở cuối cùng như một cấu trúc bao quát, tích hợp toàn bộ dữ liệu chỉ số sức khỏe của hạ tầng Kubernetes, Service Mesh và mã nguồn ứng dụng YAS.

Nhóm cài đặt bộ công cụ giám sát hiện đại **LGTM Stack** kết hợp **OpenTelemetry Operator**:
* **Prometheus:** Thu thập chỉ số tài nguyên hệ thống và metrics sinh ra từ Istio Sidecar.
* **Loki:** Thu thập, lưu trữ log tập trung từ các container (thông qua Promtail agent).
* **Tempo:** Quản lý trace phân tán phục vụ truy vết đường đi của request qua các microservice.
* **Grafana:** Giao diện Dashboard hiển thị biểu đồ chỉ số tổng hợp.

**Hình 28: Danh sách Pods hệ thống giám sát đang chạy hoạt động**
![02_kubectl_observability_pods](https://hackmd.io/_uploads/r1o_Und1Gg.png)
*Hình 28: Pods của loki, prometheus, grafana và opentelemetry chạy ổn định trong namespace.*

**Hình 29: Grafana Dashboard hiển thị hiệu năng sức khỏe và luồng dữ liệu của cụm**
![26_grafana_availability_dashboard](https://hackmd.io/_uploads/HJNt82dyfx.png)
*Hình 29: Chỉ số hiệu năng, tỷ lệ đáp ứng thành công dịch vụ hiển thị trực quan.*