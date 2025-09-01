pipeline {
    agent any
    
    environment {
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_HUB_USERNAME = 'blackdreamer'
        BACKEND_IMAGE_NAME = 'azubi-tmp-p2-ci-cd-docker-backend'
        NGINX_IMAGE_NAME = 'azubi-tmp-p2-ci-cd-docker-nginx'
        GIT_REPO = 'https://github.com/blackdreamer15/tmp-azubi-p2-ci-cd-docker.git'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '🔄 Checking out Laravel backend code...'
                checkout scm
                
                // Alternative: Checkout from specific repo
                // git branch: 'main', url: "${GIT_REPO}"
            }
        }
        
        stage('Environment Setup') {
            steps {
                echo '⚙️ Setting up build environment...'
                sh '''
                    echo "Node version: $(node --version)" || echo "Node not available"
                    echo "Docker version: $(docker --version)"
                    echo "Docker Compose version: $(docker compose version)"
                '''
            }
        }
        
        stage('Code Quality Check') {
            parallel {
                stage('Backend Validation') {
                    steps {
                        echo '🔍 Validating Laravel backend...'
                        dir('back-end') {
                            sh '''
                                # Check if composer.json exists
                                if [ -f "composer.json" ]; then
                                    echo "✅ Composer configuration found"
                                else
                                    echo "❌ No composer.json found"
                                    exit 1
                                fi
                                
                                # Validate Dockerfiles
                                if [ -f "dockerfiles/php.dockerfile" ]; then
                                    echo "✅ PHP Dockerfile found"
                                else
                                    echo "❌ PHP Dockerfile not found"
                                    exit 1
                                fi
                                
                                if [ -f "dockerfiles/nginx.dockerfile" ]; then
                                    echo "✅ Nginx Dockerfile found"
                                else
                                    echo "❌ Nginx Dockerfile not found"
                                    exit 1
                                fi
                            '''
                        }
                    }
                }
                
                stage('Docker Validation') {
                    steps {
                        echo '🐳 Validating Docker configurations...'
                        sh '''
                            # Validate Docker Compose file
                            docker compose config
                            echo "✅ Docker Compose configuration is valid"
                        '''
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Build Backend Image') {
                    steps {
                        echo '🏗️ Building Laravel backend Docker image...'
                        script {
                            def backendImage = docker.build(
                                "${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}",
                                "-f back-end/dockerfiles/php.dockerfile back-end"
                            )
                            
                            // Tag as latest
                            backendImage.tag("${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest")
                            backendImage.tag("${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:jenkins-${BUILD_NUMBER}")
                        }
                    }
                }
                
                stage('Build Nginx Image') {
                    steps {
                        echo '🏗️ Building Nginx Docker image...'
                        script {
                            def nginxImage = docker.build(
                                "${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER}",
                                "-f back-end/dockerfiles/nginx.dockerfile back-end"
                            )
                            
                            // Tag as latest
                            nginxImage.tag("${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest")
                            nginxImage.tag("${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:jenkins-${BUILD_NUMBER}")
                        }
                    }
                }
            }
        }
        
        stage('Test Images') {
            steps {
                echo '🧪 Testing built Docker images...'
                sh '''
                    # Test backend image
                    echo "Testing backend image..."
                    docker run --rm ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} php --version
                    
                    # Test nginx image  
                    echo "Testing nginx image..."
                    docker run --rm ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER} nginx -t
                '''
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                echo '📤 Pushing Docker images to Docker Hub...'
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'docker-hub-credentials') {
                        // Push backend images
                        sh """
                            docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                            docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:jenkins-${BUILD_NUMBER}
                        """
                        
                        // Push nginx images
                        sh """
                            docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest
                            docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:jenkins-${BUILD_NUMBER}
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Environment') {
            steps {
                echo '🚀 Deploying backend services...'
                sh '''
                    # Stop existing containers
                    docker compose down || true
                    
                    # Pull latest images
                    docker pull ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                    docker pull ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest
                    
                    # Start services with latest images
                    docker compose up -d mysql redis
                    
                    # Wait for database to be ready
                    sleep 30
                    
                    # Start backend services
                    docker compose up -d backend nginx
                    
                    # Wait for services to start
                    sleep 15
                    
                    # Run database migrations
                    docker compose exec -T backend php artisan migrate --force || echo "Migrations skipped"
                '''
            }
        }
        
        stage('Health Check') {
            steps {
                echo '🏥 Performing health checks...'
                sh '''
                    # Wait for services to be fully ready
                    sleep 10
                    
                    # Check backend health
                    if curl -f http://localhost:8000/api/health; then
                        echo "✅ Backend health check passed"
                    else
                        echo "❌ Backend health check failed"
                        exit 1
                    fi
                    
                    # Check container status
                    docker compose ps
                '''
            }
        }
    }
    
    post {
        always {
            echo '🧹 Cleaning up...'
            sh '''
                # Clean up dangling images
                docker image prune -f
            '''
        }
        
        success {
            echo '''
            🎉 Backend Pipeline Success!
            ================================
            ✅ Laravel backend deployed successfully
            ✅ Images pushed to Docker Hub
            ✅ Health checks passed
            
            🔗 Backend API: http://localhost:8000/api/health
            🐳 Docker Hub: https://hub.docker.com/u/blackdreamer
            '''
            
            // Optional: Send notification
            // emailext (
            //     subject: "✅ Backend Pipeline Success - Build #${BUILD_NUMBER}",
            //     body: "Backend deployment completed successfully!",
            //     to: "${env.CHANGE_AUTHOR_EMAIL}"
            // )
        }
        
        failure {
            echo '''
            ❌ Backend Pipeline Failed!
            ===========================
            Please check the logs for details.
            
            Common issues:
            - Docker Hub authentication
            - Database connection
            - Missing environment variables
            - Port conflicts
            '''
            
            // Optional: Send failure notification
            // emailext (
            //     subject: "❌ Backend Pipeline Failed - Build #${BUILD_NUMBER}",
            //     body: "Backend deployment failed. Please check Jenkins logs.",
            //     to: "${env.CHANGE_AUTHOR_EMAIL}"
            // )
        }
        
        unstable {
            echo '⚠️ Backend Pipeline Unstable - Some tests failed but build continued'
        }
    }
}
