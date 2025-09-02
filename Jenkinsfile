pipeline {
    agent any
    
    environment {
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_HUB_USERNAME = 'blackdreamer'
        BACKEND_IMAGE_NAME = 'azubi-tmp-p2-ci-cd-docker-backend'
        NGINX_IMAGE_NAME = 'azubi-tmp-p2-ci-cd-docker-nginx'
        GIT_REPO = 'https://github.com/blackdreamer15/azubi-tmp-p2-ci-cd-docker.git'
        PATH = "/usr/local/bin:/opt/homebrew/bin:${env.PATH}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '🔄 Checking out Laravel backend code...'
                checkout scm
            }
        }
        
        stage('Environment Setup') {
            steps {
                echo '⚙️ Setting up build environment...'
                sh '''
                    echo "Current PATH: $PATH"
                    echo "Current USER: $(whoami)"
                    echo "Docker version: $(docker --version)"
                    echo "Docker Compose version: $(docker compose version)"
                    echo "Git version: $(git --version)"
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
                        sh '''
                            cd back-end
                            docker build -f dockerfiles/php.dockerfile \
                                --build-arg UID=1000 \
                                --build-arg GID=1000 \
                                --build-arg USER=laravel \
                                -t ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
                                -t ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest \
                                -t ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:jenkins-${BUILD_NUMBER} .
                            
                            echo "✅ Backend image built successfully"
                        '''
                    }
                }
                
                stage('Build Nginx Image') {
                    steps {
                        echo '🏗️ Building Nginx Docker image...'
                        sh '''
                            cd back-end
                            docker build -f dockerfiles/nginx.dockerfile \
                                --build-arg UID=1000 \
                                --build-arg GID=1000 \
                                --build-arg USER=laravel \
                                -t ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER} \
                                -t ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest \
                                -t ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:jenkins-${BUILD_NUMBER} .
                            
                            echo "✅ Nginx image built successfully"
                        '''
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
                    echo "✅ Backend image test passed"

                    # Test nginx image
                    echo "Testing nginx image..."
                    docker run --rm ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER} nginx -t
                    echo "✅ Nginx image test passed"
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo '📤 Pushing Docker images to Docker Hub...'
                sh '''
                    # Login to Docker Hub
                    echo "Logging into Docker Hub..."
                    echo "${DOCKER_HUB_CREDENTIALS_PSW}" | docker login -u "${DOCKER_HUB_CREDENTIALS_USR}" --password-stdin

                    # Push backend images
                    echo "Pushing backend images..."
                    docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}
                    docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                    docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:jenkins-${BUILD_NUMBER}
                    echo "✅ Backend images pushed successfully"

                    # Push nginx images
                    echo "Pushing nginx images..."
                    docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER}
                    docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest
                    docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:jenkins-${BUILD_NUMBER}
                    echo "✅ Nginx images pushed successfully"
                '''
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
                        # Show container status for debugging
                        docker compose ps
                        docker compose logs backend
                        exit 1
                    fi

                    # Check container status
                    echo "Final container status:"
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
                docker image prune -f || echo "Failed to prune images, continuing..."
            '''
        }
        
        success {
            echo '''
            🎉 Backend Pipeline Success!
            ================================
            All stages completed successfully!
            
            ✅ Code quality checks passed
            ✅ Docker images built and tested
            ✅ Images pushed to Docker Hub
            ✅ Services deployed successfully
            ✅ Health checks passed
            
            🚀 Backend is ready for use!
            '''
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
        }
        
        unstable {
            echo '⚠️ Backend Pipeline Unstable - Some tests failed but build continued'
        }
    }
}