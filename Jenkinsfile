pipeline {
    agent {
        kubernetes {
            label 'docker-helm'
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-admin
  containers:
    - name: docker
      image: docker:25-dind
      securityContext:
        privileged: true
      volumeMounts:
        - name: docker-graph-storage
          mountPath: /var/lib/docker
    - name: helm
      image: alpine/helm:3
      command: [cat]
      tty: true
  volumes:
    - name: docker-graph-storage
      emptyDir: {}
"""
        }
    }
    environment {
        DOCKER_IMAGE = "loulah/go_app:${BUILD_NUMBER}"
        HELM_NAMESPACE = "production"
    }
    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('docker') {
                    sh "docker build -t ${DOCKER_IMAGE} -f ./backend/Dockerfile ./backend"
                    withCredentials([usernamePassword(credentialsId: 'dockerlogin', passwordVariable: 'docker_pass', usernameVariable: 'docker_user')]) {
                        sh " echo ${docker_pass} | docker login -u ${docker_user} --password-stdin docker.io"
                        sh "docker push ${DOCKER_IMAGE}"
                    }
                }
            }
        }
        stage('Deploy with Helm') {
            steps {
                container('helm') {
                    sh """
            helm upgrade --install my-app ./k8s/app-chart/ \\
              --set images.go.tag=${BUILD_NUMBER} \\
              --namespace $HELM_NAMESPACE \\
              --create-namespace --wait
          """
                }
            }
        }
        stage('Smoke Test') {
            steps {
                sh """
            echo "SMOKE TEST START"
            curl -k https://nginx-svc.${HELM_NAMESPACE}.svc.cluster.local
            echo "SMOKE TEST PASSED"
          """
            }
        }
    }
}
