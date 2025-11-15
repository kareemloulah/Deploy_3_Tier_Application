pipeline {
  agent {
    kubernetes {
      label 'docker-helm'
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: docker
      image: docker:25-dind
      securityContext:
        privileged: true
      volumeMounts:
        - name: docker-graph-storage
          mountPath: /var/lib/docker
    - name: helm
      image: lachlanevenson/k8s-helm:v3.14.3
      command: [cat]
      tty: true
    - name: kubectl
      image: bitnami/kubectl:latest
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
          sh "docker build -t ${DOCKER_IMAGE} -f ./backend/."
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
        // If custom kubectl usage needed (e.g., pre-deployment logic or checks):
        container('kubectl') {
          sh "kubectl get pods -n $HELM_NAMESPACE"
        }
      }
    }
  }
}
