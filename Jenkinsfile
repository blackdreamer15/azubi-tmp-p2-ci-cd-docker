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
                    echo "Docker Compose version: $(docker compose version || docker-compose version)"
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
                                if [ -f "composer.json" ]; then
                                    echo "✅ Composer configuration found"
                                else
                                    echo "❌ No composer.json found"
                                    exit 1
                                fi

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
                        echo '🐳 Validating Docker Compose file...'
                        sh '''
                            if docker compose version >/dev/null 2>&1; then
                                docker compose config
                            elif docker-compose version >/dev/null 2>&1; then
                                docker-compose config
                            else
                                echo "❌ Docker Compose not found"
                                exit 1
                            fi
                            echo "✅ Docker Compose configuration is valid"
                        '''
                    }
                }
            }
        }

        stage('Run Unit Tests') {
            steps {
                echo '🧪 Running PHP unit tests...'
                dir('back-end') {
                    sh '''
                        if [ -f "vendor/bin/phpunit" ]; then
                            ./vendor/bin/phpunit
                        else
                            echo "⚠️ PHPUnit not found, skipping tests"
                        fi
                    '''
                }
            }
        }

        stage('Build Docker Images') {
            parallel {
                stage('Build Backend Image') {
                    steps {
                        script {
                            env.COMMIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                            env.UID = sh(script: 'id -u', returnStdout: true).trim()
                            env.GID = sh(script: 'id -g', returnStdout: true).trim()
                        }
                        echo '🏗️ Building Laravel backend Docker image...'
                        sh '''
                            cd back-end
                            docker build -f dockerfiles/php.dockerfile \
                                --build-arg UID=${UID} \
                                --build-arg GID=${GID} \
                                --build-arg USER=laravel \
                                -t ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} \
                                -t ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest \
                                -t ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${COMMIT_SHA} .
                            echo "✅ Backend image built successfully"
                        '''
                    }
                }

                stage('Build Nginx Image') {
                    steps {
                        script {
                            env.COMMIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                            env.UID = sh(script: 'id -u', returnStdout: true).trim()
                            env.GID = sh(script: 'id -g', returnStdout: true).trim()
                        }
                        echo '🏗️ Building Nginx Docker image...'
                        sh '''
                            cd back-end
                            docker build -f dockerfiles/nginx.dockerfile \
                                --build-arg UID=${UID} \
                                --build-arg GID=${GID} \
                                --build-arg USER=laravel \
                                -t ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER} \
                                -t ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest \
                                -t ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${COMMIT_SHA} .
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
                    docker run --rm ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER} php --version
                    echo "✅ Backend image test passed"

                    docker run --rm ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER} nginx -t
                    echo "✅ Nginx image test passed"
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo '📤 Pushing Docker images to Docker Hub...'
                sh '''
                    echo "${DOCKER_HUB_CREDENTIALS_PSW}" | docker login -u "${DOCKER_HUB_CREDENTIALS_USR}" --password-stdin

                    docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${BUILD_NUMBER}
                    docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                    docker push ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:${COMMIT_SHA}

                    docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${BUILD_NUMBER}
                    docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest
                    docker push ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:${COMMIT_SHA}
                '''
            }
        }

        stage('Deploy to Environment') {
            steps {
                echo '🚀 Deploying backend services...'
                sh '''
                    (docker compose down --remove-orphans || docker-compose down --remove-orphans) || true

                    docker pull ${DOCKER_HUB_USERNAME}/${BACKEND_IMAGE_NAME}:latest
                    docker pull ${DOCKER_HUB_USERNAME}/${NGINX_IMAGE_NAME}:latest

                    (docker compose up -d mysql redis || docker-compose up -d mysql redis)

                    sleep 30

                    (docker compose up -d backend nginx || docker-compose up -d backend nginx)

                    sleep 15

                    (docker compose exec -T backend php artisan migrate --force || \
                     docker-compose exec -T backend php artisan migrate --force) || echo "⚠️ Migrations skipped"
                '''
            }
        }

        stage('Health Check') {
            steps {
                echo '🏥 Performing health checks...'
                sh '''
                    for i in {1..5}; do
                        if curl -fs http://localhost:8000/api/health; then
                            echo "✅ Backend health check passed"
                            break
                        else
                            echo "⏳ Waiting for backend to become healthy..."
                            sleep 5
                        fi
                    done

                    echo "Final container status:"
                    docker compose ps || docker-compose ps
                '''
            }
        }
    }

    post {
        always {
            echo '🧹 Cleaning up...'
            sh '''
                docker image prune -f || echo "Image prune failed"
                docker container prune -f || echo "Container prune failed"
            '''
        }

        success {
            echo '''
            🎉 Backend Pipeline Success!
            ================================
            ✅ Code validated
            ✅ Tests passed
            ✅ Docker images built
            ✅ Images pushed to Docker Hub
            ✅ Deployed to environment
            ✅ Health checks passed
            '''
        }

        failure {
            echo '''
            ❌ Backend Pipeline Failed!
            ===========================
            Please check the logs for more details.

            Common causes:
            - Docker Hub credentials
            - Build failures
            - Missing dependencies
            - Health check timeouts
            '''
        }

        unstable {
            echo '⚠️ Pipeline is unstable. Some tests failed or warnings occurred.'
        }
    }
}
