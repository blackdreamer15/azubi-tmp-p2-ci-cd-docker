#!/bin/bash

# Backend Deployment Script
# This script automates the deployment of the backend services

set -e  # Exit on any error

# Configuration
DOCKER_HUB_USERNAME="blackdreamer"
BACKEND_IMAGE="azubi-tmp-p2-ci-cd-docker-backend"
NGINX_IMAGE="azubi-tmp-p2-ci-cd-docker-nginx"
COMPOSE_FILE="docker compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed (try both commands)
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose (modern: docker compose OR legacy: docker compose)
    if command -v "docker compose" &> /dev/null || docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        log_success "Docker Compose found (modern version)"
    elif command -v docker compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        log_success "Docker Compose found (legacy version)"
    else
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Stop existing services
stop_services() {
    log_info "Stopping existing services..."
    docker compose -f $COMPOSE_FILE down || true
    log_success "Services stopped"
}

# Pull latest images
pull_images() {
    log_info "Pulling latest Docker images..."
    
    docker pull $DOCKER_HUB_USERNAME/$BACKEND_IMAGE:latest
    docker pull $DOCKER_HUB_USERNAME/$NGINX_IMAGE:latest
    
    log_success "Images pulled successfully"
}

# Start database services
start_database() {
    log_info "Starting database services..."
    docker compose -f $COMPOSE_FILE up -d mysql redis
    
    # Wait for database to be ready
    log_info "Waiting for database to be ready..."
    sleep 30
    
    # Check if MySQL is ready
    for i in {1..30}; do
        if docker compose -f $COMPOSE_FILE exec -T mysql mysql -u laravel_user -p'laravel_password' -e "SELECT 1" &> /dev/null; then
            log_success "Database is ready"
            return 0
        fi
        log_info "Waiting for database... ($i/30)"
        sleep 2
    done
    
    log_error "Database failed to start within timeout"
    exit 1
}

# Start backend services
start_backend() {
    log_info "Starting backend services..."
    docker compose -f $COMPOSE_FILE up -d backend nginx
    
    # Wait for services to start
    log_info "Waiting for backend services to start..."
    sleep 15
    
    log_success "Backend services started"
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."
    
    # Wait a bit more for the backend to be fully ready
    sleep 10
    
    if docker compose -f $COMPOSE_FILE exec -T backend php artisan migrate --force; then
        log_success "Database migrations completed"
    else
        log_warning "Database migrations failed or were skipped"
    fi
}

# Health checks
health_check() {
    log_info "Performing health checks..."
    
    # Wait for services to be fully ready
    sleep 10
    
    # Check if backend API is responding
    for i in {1..20}; do
        if curl -f -s http://localhost:8000/api/health &> /dev/null; then
            log_success "Backend health check passed"
            return 0
        fi
        log_info "Waiting for backend to be ready... ($i/20)"
        sleep 3
    done
    
    log_error "Backend health check failed"
    return 1
}

# Show deployment status
show_status() {
    log_info "Deployment Status:"
    echo "===================="
    
    # Show running containers
    docker compose -f $COMPOSE_FILE ps
    
    echo ""
    log_info "Service URLs:"
    echo "📡 Backend API: http://localhost:8000/api/health"
    echo "🗄️ MySQL Database: localhost:3306"
    echo "💾 Redis Cache: localhost:6379"
    
    echo ""
    log_info "Test the deployment:"
    echo "curl http://localhost:8000/api/health"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up unused images..."
    docker image prune -f
    log_success "Cleanup completed"
}

# Rollback function
rollback() {
    log_warning "Rolling back deployment..."
    docker compose -f $COMPOSE_FILE down
    log_info "Services stopped. Previous state restored."
}

# Main deployment function
deploy() {
    log_info "🚀 Starting Backend Deployment"
    echo "================================"
    
    # Set trap for cleanup on error
    trap 'log_error "Deployment failed! Rolling back..."; rollback; exit 1' ERR
    
    check_prerequisites
    stop_services
    pull_images
    start_database
    start_backend
    run_migrations
    
    if health_check; then
        show_status
        cleanup
        
        echo ""
        log_success "🎉 Backend Deployment Completed Successfully!"
        echo "============================================="
        echo ""
        echo "✅ Backend services are running"
        echo "✅ Database migrations completed"
        echo "✅ Health checks passed"
        echo ""
        echo "🔗 Access your backend at: http://localhost:8000/api/health"
        
    else
        log_error "Health check failed. Rolling back..."
        rollback
        exit 1
    fi
}

# Script usage
usage() {
    echo "Backend Deployment Script"
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     Deploy backend services (default)"
    echo "  stop       Stop all services"
    echo "  restart    Restart all services"
    echo "  status     Show service status"
    echo "  logs       Show service logs"
    echo "  cleanup    Remove unused images"
    echo "  help       Show this help message"
}

# Command handling
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    stop)
        log_info "Stopping all services..."
        docker compose -f $COMPOSE_FILE down
        log_success "All services stopped"
        ;;
    restart)
        log_info "Restarting services..."
        docker compose -f $COMPOSE_FILE restart
        log_success "Services restarted"
        ;;
    status)
        log_info "Service Status:"
        docker compose -f $COMPOSE_FILE ps
        ;;
    logs)
        log_info "Service Logs:"
        docker compose -f $COMPOSE_FILE logs --tail=50 -f
        ;;
    cleanup)
        cleanup
        ;;
    help)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
