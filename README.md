# Deploy 3 tier application (Proxy-server "Nginx", Back-End "go", DataBase "mysql")

```
# File Tree
📁 go-app-docker-k8s/
├── 📁 backend/
│   ├── 📄 db-password
│   ├── 📄 Dockerfile
│   ├── 📄 go.mod
│   ├── 📄 go.sum
│   └── 📄 main.go
├── 📄 compose.sh
├── 📄 compose.yml
├── 📄 docker-compose.yml
├── 📄 init.sql
├── 📁 k8s/
│   ├── 📄 configmap.yml
│   ├── 📄 deployment-db.yml
│   ├── 📄 deployment-go.yml
│   ├── 📄 deployment-nginx.yml
│   ├── 📄 namespace.yml
│   ├── 📄 pv-db.yml
│   ├── 📄 pvc-ns.yml
│   ├── 📄 secret-nginx.yaml
│   ├── 📄 secret.yml
│   └── 📄 start.sh
├── 📄 kindcluster.yml
├── 📁 nginx/
│   ├── 📄 Dockerfile
│   ├── 📄 generate-ssl.sh
│   ├── 📄 nginx.conf
│   └── 📁 ssl/
│       ├── 📄 localhost.crt
│       └── 📄 localhost.key
└── 📄 README.md
```

## Task:
- Containerized application setup
- Compose file with volumes to persist SQL data and networking
- Kubernetes deployment setup

---

## The Basics

### Step 1: Containerizing the Go App

**Notes to take from source code:**

**Q1)** Listening on which port?  
**Q2)** Wants to connect to what and which port?  
**Q3)** Are any credentials needed and where?

**Answer:** Pretty simple app that listens on port **8000**, needs to see **'db'** from DNS, connects on port **3306**, credentials are read from a file called **'db-password'** in the **'/run/secrets/'** directory.

**Dockerfile (Multi-stage Build):**

```dockerfile
# Stage 1: Builder
FROM golang:1.23.3-trixie AS builder

WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker's build cache
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go application
# CGO_ENABLED=0 creates a statically linked binary, making it more portable
# -o specifies the output binary name
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o myapp .

# Stage 2: Final image
FROM alpine:3.22.2

WORKDIR /root/

COPY --from=builder /app/myapp .

RUN apk add curl # FOR TESTING LATER

# RUN mkdir -p /run/secrets/ # optional if running without compose

# Expose the port your application listens on
EXPOSE 8000

CMD ["./myapp"]
```

---

### Step 2: Containerizing Nginx

What is needed is configuration for the reverse proxy. Listen on port **80** "http" or **443** "https" **NEEDS SSL**.

Configuring Nginx is pretty straightforward - add a server block that forwards traffic coming on port 443 to the Go app:

**nginx.conf:**

```nginx
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/certs/localhost.crt; 
    ssl_certificate_key /etc/nginx/certs/localhost.key; 

    ssl_session_cache shared:SSL:1m;  # optional 
    ssl_session_timeout 5m;  # optional
    
    location / {
        proxy_pass http://goapp:8000; # your backend API
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

### Step 3: Create a Compose File

Create a compose file that has 3 services: **Nginx**, **Go**, **DB**.

**Important Notes:**

- **Note 1:** Database name has to match the name in the Go source code
- **Note 2:** Mounting volume for MySQL data (reference DB docs to get directory)
- **Note 3:** Mount db-password as env-from file to set DB password
- **Note 4:** Mount db-password in Go app in the needed directory as specified in the source code

**Compose File:** [docker-compose.yml](docker-compose.yml)

**Note:** If you need to run without compose, you have to do the same either on the run command or include in the Dockerfile >> port mapping for ports and COPY for the db-password.

**Run the compose file:**

```bash
docker-compose up -d
```

Check files if facing errors.

---

## Kubernetes Setup

I like to start in Kubernetes from the smallest to largest:

1. Starting with the **namespace** setup if needed
2. **PV** > **PVC**
3. **ConfigMap** and **Secrets**
4. **Deployments** > **Services**

---

### Namespace

```bash
kubectl create namespace <name>
```

---

### PV, PVC

Has to be created in order:

- **PV:** Created globally in a cluster, no namespace needs specification
- **PVC:** Created in a specific namespace related to the deployment that needs it

**Files:**
- [Persistent Volume yaml](./k8s/pv-db.yml)
- [Persistent Volume Claim yaml](./k8s/pvc-ns.yml)

**Note:** Take note of the names - the PVC name is going to get mentioned in the Deployment yaml file.

---

### ConfigMap and Secrets

The setup has 2 ConfigMaps needed:

**1. For Nginx:**

```bash
kubectl create configmap <"name"> --from-env-file=./<"path_to_config.txt"> <"args"> --dry-run=client -o yaml > <filename>.yaml
```

**1 Secret for Nginx TLS:**

```bash
kubectl create secret tls <secret-name> --key=<Path_to_key> --cert=<path_to_Cert> --dry-run=client -o yaml > <filename>.yaml
```

[ConfigMap Nginx yaml](./k8s/deployment-nginx.yml) - found in the section of ConfigMap

**2. For DB:**

- [ConfigMap yaml](./k8s/configmap.yml)
- [Secret DB password](./k8s/secret.yml)

---

### Deployments

We have 3 deployments: **Nginx**, **Go**, **DB**

#### DB Deployment / Service:

```bash
kubectl create deployment <deployment_name> \
--image <Image/name:version> \
--replicas <num_of_pods> \
--port <container_port> \
-n <namespace> \
--dry-run=client -o yaml > filename.yaml

kubectl create svc clusterip <svc_name> \
--tcp=svc_port:container_port \
--dry-run=client -o yaml
```

**File:** [Deployment + Service yaml](./k8s/deployment-db.yml)

---

#### Go App Deployment / Service:

**File:** [Deployment + Service yaml](./k8s/deployment-go.yml)

---

#### Nginx Deployment / Service:

**File:** [Deployment + Service yaml](./k8s/deployment-nginx.yml)

---

## Caveats

- **Kubernetes Secret Permissions:** Kubernetes deployment by default sets permissions for the `/run/secrets` directory, i.e., containers don't have read access to files in that directory.
  
  **Solution:** To overwrite these settings, add `spec.automountServiceAccountToken: false` for both DB and Go deployments since both need access to this directory to get the DB password.

- **DB Root Access:** In the DB setup, you need to enable root access from any IP using the `init.sql` file. Check the MySQL documentation for details.

---

## Quick Commands Reference

### Docker Compose

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# Check running services
docker-compose ps
```

### Kubernetes

```bash
# Create namespace
kubectl create namespace app-ns

# Apply all resources
kubectl apply -f k8s/

# Check pods
kubectl get pods -n app-ns

# Check services
kubectl get svc -n app-ns

# View logs
kubectl logs -f <pod-name> -n app-ns

# Delete all resources
kubectl delete namespace app-ns
```

---

## Additional Notes

### Running Without Compose

If you want to run individual containers without Docker Compose, you'll need to:

1. Create a network manually
2. Run each container with proper network configuration
3. Mount volumes and secrets manually
4. Configure port mappings

### Network Configuration

The `compose.sh` script contains advanced network configuration using **ipvlan L3 mode** for custom network isolation. This is optional and provides more control over network routing.

---

**Last Updated:** October 2025