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

## Task :
    - Containarized application Setup 
    - Compose file with volumes to persist sql data and network
    - k8s deployment setup 
### The Basics 
####    Step 1: 
    Containarizing the go app >
    Notes to take from src code :
    Q1) Listening on which port.
    Q2) wants to connect to what and which port.
    Q3) is any creds needed and where.

pretty simple app listens on port 8000, needs to see 'db' from dns connects on port 3306, credintials are read from a file called 'db-password' in '/run/secrets/' directory 
```
# Stage 1: Builder
FROM golang:1.25.3-trixie AS builder

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

# Expose the port your application listens on
EXPOSE 8000

CMD ["./myapp"]
```

#### Step 2:
    Containarizing Nginx >
    what is needed is configuration for the reverse proxy listen on port 80 "http" or 443 "https" NEEDS SSL
    configuring nginx is pretty straight forward add server block that forwards traffic comming on port 443 to the go app :
```
 server {
        listen 443 ssl;
        server_name localhost;

        ssl_certificate /etc/nginx/certs/localhost.crt; 
        ssl_certificate_key /etc/nginx/certs/localhost.key; 


        ssl_session_cache    shared:SSL:1m;  # optional 
        ssl_session_timeout  5m;  # optional
        location / {
            proxy_pass http://goapp:8000; # your backend API
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
```
#### Step3 
    Create a compose file that has 3 services Nginx, go, db. 
    Note 1 : Database name has to match the name in the go src code. 
    Note 2 : mounting volume for mysql data # refrence DB docs to get dir. 
    Note 3 : mount db-password as env-from file to set db password.
    Note 4 : mount db-password in go app in needed dir as the src code. 

[Docker-compose.yml](docker-compose.yml)

    Note :  if you need to run without compose you have to do the same either on the run command or include in docker file >> port mapping for ports and COPY for the db-password

***Docker Compose up -d*** to run the compose file check files if facing errors 
### Kubernetes setup 
