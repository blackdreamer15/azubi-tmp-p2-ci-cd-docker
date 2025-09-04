# Jenkins CI/CD Pipeline Setup Guide - Phase 3

This guide walks you through setting up Jenkins for automated backend deployment.

## 🎯 Phase 3 Objectives

- ✅ Install and configure Jenkins locally
- ✅ Create Jenkins pipeline for Laravel backend
- ✅ Automate Docker image building and pushing
- ✅ Deploy backend containers automatically
- ✅ Test the complete pipeline

## 🔧 Step 1: Install Jenkins

### Option A: Using Docker (Recommended for Development)

```bash
# Create Jenkins data directory
mkdir -p ~/jenkins_home

# Run Jenkins in Docker
docker run -d \
  --name jenkins-server \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(which docker):/usr/bin/docker \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword
```

### Option B: Using Homebrew (macOS)

```bash
# Install Jenkins
brew install jenkins

# Start Jenkins
brew services start jenkins

# Access Jenkins at http://localhost:8080
# Get initial password from: /usr/local/var/lib/jenkins/secrets/initialAdminPassword
```

### Option C: Using Package Manager (Ubuntu/Debian)

```bash
# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install
sudo apt-get update
sudo apt-get install jenkins

# Start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 🚀 Step 2: Initial Jenkins Configuration

1. **Access Jenkins**: Open [http://localhost:8080](http://localhost:8080)
2. **Enter Admin Password**: Use the password from Step 1
3. **Install Suggested Plugins**: Click "Install suggested plugins"
4. **Create Admin User**: Set up your admin credentials
5. **Configure Instance**: Use default Jenkins URL or customize

## 🔌 Step 3: Install Required Plugins

Navigate to **Manage Jenkins** → **Manage Plugins** → **Available** and install:

### Essential Plugins:

- ✅ **Docker Pipeline** - Docker integration
- ✅ **Git Plugin** - Git repository integration
- ✅ **GitHub Plugin** - GitHub webhook support
- ✅ **Pipeline: Stage View** - Visual pipeline stages
- ✅ **Blue Ocean** - Modern pipeline UI
- ✅ **Credentials Binding** - Secure credential management
- ✅ **Email Extension** - Email notifications

### Installation Commands:

```bash
# Install plugins via CLI (if using Docker)
docker exec jenkins-server jenkins-plugin-cli --plugins \
  docker-workflow:1.28 \
  git:4.8.3 \
  github:1.34.3 \
  pipeline-stage-view:2.21 \
  blueocean:1.25.2 \
  credentials-binding:1.27 \
  email-ext:2.84
```

## 🔐 Step 4: Configure Docker Hub Credentials

1. Navigate to **Manage Jenkins** → **Manage Credentials**
2. Click **(global)** → **Add Credentials**
3. Configure:
   - **Kind**: Username with password
   - **Scope**: Global
   - **Username**: `blackdreamer` (your Docker Hub username)
   - **Password**: Your Docker Hub access token
   - **ID**: `docker-hub-credentials`
   - **Description**: Docker Hub Access Token

## 📋 Step 5: Create Jenkins Pipeline Job

1. **New Item**: Click "New Item" in Jenkins dashboard
2. **Job Name**: `Backend-CI-CD-Pipeline`
3. **Type**: Select "Pipeline" → Click OK
4. **Configuration**:

### General Tab:

- ✅ **Description**: "Automated CI/CD pipeline for Laravel backend"
- ✅ **Discard old builds**: Keep 10 builds
- ✅ **GitHub project**: `https://github.com/blackdreamer15/tmp-azubi-p2-ci-cd-docker`

### Build Triggers:

- ✅ **GitHub hook trigger for GITScm polling**
- ✅ **Poll SCM**: `H/5 * * * *` (every 5 minutes)

### Pipeline Definition:

- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/blackdreamer15/tmp-azubi-p2-ci-cd-docker.git`
- **Branch**: `*/main`
- **Script Path**: `Jenkinsfile`

5. **Save** the configuration

## 🎮 Step 6: Test the Pipeline

### Manual Trigger:

1. Go to your pipeline job
2. Click **"Build Now"**
3. Monitor the **Console Output**

### Expected Pipeline Stages:

```bash
Pipeline Stages:
├── 🔄 Checkout
├── ⚙️ Environment Setup
├── 🔍 Code Quality Check
│   ├── Backend Validation
│   └── Docker Validation
├── 🏗️ Build Docker Images
│   ├── Build Backend Image
│   └── Build Nginx Image
├── 🧪 Test Images
├── 📤 Push to Docker Hub
├── 🚀 Deploy to Environment
└── 🏥 Health Check
```

## 🔗 Step 7: Configure GitHub Webhooks (Optional)

For automatic triggers on code push:

1. **Go to GitHub Repository**: [https://github.com/blackdreamer15/tmp-azubi-p2-ci-cd-docker](https://github.com/blackdreamer15/tmp-azubi-p2-ci-cd-docker)
2. **Settings** → **Webhooks** → **Add webhook**
3. **Payload URL**: `http://your-jenkins-url:8080/github-webhook/`
4. **Content type**: `application/json`
5. **Events**: Just the push event
6. **Active**: ✅ Checked

## 🧪 Step 8: Deployment Testing

### Test Commands:

```bash
# Check if services are running
docker-compose -f docker-compose.prod.yml ps

# Test backend API
curl http://localhost:8000/api/health

# Check Docker Hub images
docker images | grep blackdreamer

# View logs
docker-compose -f docker-compose.prod.yml logs backend
docker-compose -f docker-compose.prod.yml logs nginx
```

## 📊 Step 9: Monitor and Maintain

### Jenkins Dashboard Features:

- **Build History**: View all pipeline executions
- **Blue Ocean**: Modern pipeline visualization
- **Console Output**: Detailed build logs
- **Stage View**: Visual pipeline progress

### Health Monitoring:

```bash
# Jenkins service status
docker ps | grep jenkins  # If using Docker
# OR
sudo systemctl status jenkins  # If using system service

# Application health
curl http://localhost:8000/api/health
```

## 🚨 Troubleshooting

### Common Issues:

1. **Docker Permission Denied**

   ```bash
   # Add jenkins user to docker group
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   ```

2. **Port Conflicts**
   - Jenkins (8080) conflicts with backend (8000)
   - Solution: Use different ports or stop conflicting services

3. **Credential Issues**
   - Verify Docker Hub token is valid
   - Check credential ID matches Jenkinsfile

4. **Pipeline Fails at Build Stage**
   - Check Dockerfile paths
   - Verify build context

5. **Database Connection Issues**
   - Ensure MySQL container is running
   - Check environment variables

### Debug Commands:
```bash
# View Jenkins logs
docker logs jenkins-server

# Check Docker daemon
docker info

# Verify credentials
docker login

# Test local build
docker build -t test-backend -f back-end/dockerfiles/php.dockerfile back-end
```

## 🎉 Phase 3 Success Criteria

✅ **Jenkins Installed**: Jenkins running on localhost:8080  
✅ **Pipeline Created**: Backend CI/CD pipeline configured  
✅ **Docker Integration**: Images building and pushing automatically  
✅ **Deployment Working**: Backend containers deploying successfully  
✅ **Health Checks**: API endpoints responding correctly  
✅ **Notifications**: Build success/failure notifications working  

## 🔄 Next Steps: Phase 4

After completing Phase 3, you'll be ready for Phase 4:
- Full stack deployment orchestration
- Container monitoring and logging
- Automated update scripts
- Production environment setup

## 📚 Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Docker Pipeline Plugin](https://docs.jenkins.io/doc/book/pipeline/docker/)
- [Blue Ocean Documentation](https://www.jenkins.io/doc/book/blueocean/)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks)
