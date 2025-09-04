#!/bin/bash

# =============================================================================
# Docker Hub Update Checker Script
# =============================================================================
# Checks for updates to Docker images on Docker Hub and optionally updates
# running services using docker-compose
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION
# =============================================================================

# Images to monitor (without :latest tag)
IMAGES=(
    "blackdreamer/azubi-tmp-p2-ci-cd-docker-backend"
    "blackdreamer/azubi-tmp-p2-ci-cd-docker-nginx" 
    # "blackdreamer/azubi-tmp-p2-ci-cd-docker-frontend"  # Commented out - no digest available
)

# Corresponding service names in docker-compose.yml
SERVICES=(
    "backend"
    "nginx"
    # "frontend"  # Commented out - no digest available
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="check-updates.log"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[LOG]${NC} $message"
    fi
}

print_usage() {
    cat << EOF
Docker Hub Update Checker

Usage: $0 [OPTIONS]

OPTIONS:
    --check             Check for updates only (default)
    --update-all        Update all services that have updates
    --update <service>  Update specific service (backend, nginx, frontend)
    --dry-run           Show what would be updated without making changes
    --verbose           Show detailed logging
    --help              Show this help message

Examples:
    $0 --check                    # Check for updates
    $0 --update-all              # Update all services
    $0 --update frontend         # Update only frontend
    $0 --dry-run --verbose       # Dry run with detailed output
EOF
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

check_dependencies() {
    local deps=("curl" "jq" "docker")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}"
        echo "Please install missing dependencies and try again."
        exit 1
    fi
}

get_dockerhub_digest() {
    local image_name="$1"
    local tag="${2:-latest}"
    
    log_message "Checking Docker Hub for $image_name:$tag"
    
    # Use Docker Hub API v2 to get image digest with timeout
    local api_url="https://hub.docker.com/v2/repositories/$image_name/tags/$tag/"
    local response
    
    # Use gtimeout on macOS if available, otherwise use a shorter connect timeout
    if command -v gtimeout >/dev/null 2>&1; then
        response=$(gtimeout 15 curl -s --connect-timeout 5 --max-time 10 "$api_url" 2>/dev/null)
    else
        response=$(curl -s --connect-timeout 5 --max-time 10 "$api_url" 2>/dev/null)
    fi
    
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo "ERROR_NETWORK"
        return 1
    fi
    
    # Extract digest from the first architecture (usually amd64)
    local digest
    digest=$(echo "$response" | jq -r '.images[0].digest // empty' 2>/dev/null)
    
    if [[ -z "$digest" || "$digest" == "null" ]]; then
        echo "ERROR_PARSE"
        return 1
    fi
    
    echo "$digest"
    return 0
}

get_local_digest() {
    local image_name="$1"
    local tag="${2:-latest}"
    local full_image="$image_name:$tag"
    
    # Get local image digest
    local digest
    digest=$(docker images --digests --format "{{.Digest}}" "$full_image" 2>/dev/null | head -n1)
    
    if [[ -z "$digest" || "$digest" == "<none>" ]]; then
        echo "NOT_FOUND"
        return 1
    fi
    
    echo "$digest"
    return 0
}

check_image_update() {
    local image_name="$1"
    local service_name="$2"
    
    echo -e "${BLUE}🔍 Checking $service_name ($image_name)...${NC}"
    
    # Get remote digest
    local remote_digest
    remote_digest=$(get_dockerhub_digest "$image_name")
    local remote_status=$?
    
    if [[ $remote_status -ne 0 ]]; then
        case "$remote_digest" in
            "ERROR_NETWORK")
                echo -e "${RED}  ⚠️  Network error - could not reach Docker Hub${NC}"
                log_message "ERROR: Network error checking $image_name"
                return 2
                ;;
            "ERROR_PARSE")
                echo -e "${RED}  ⚠️  Could not parse Docker Hub response${NC}"
                log_message "ERROR: Parse error checking $image_name"
                return 2
                ;;
        esac
    fi
    
    # Get local digest
    local local_digest
    local_digest=$(get_local_digest "$image_name")
    local local_status=$?
    
    if [[ $local_status -ne 0 ]]; then
        echo -e "${YELLOW}  📥 Image not found locally - will be pulled${NC}"
        log_message "INFO: $image_name not found locally"
        return 1  # Update needed
    fi
    
    # Compare digests
    if [[ "$remote_digest" == "$local_digest" ]]; then
        echo -e "${GREEN}  ✅ Up to date${NC}"
        log_message "INFO: $image_name is up to date"
        return 0  # No update needed
    else
        echo -e "${YELLOW}  🆕 Update available${NC}"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${BLUE}     Local:  ${local_digest}${NC}"
            echo -e "${BLUE}     Remote: ${remote_digest}${NC}"
        fi
        log_message "INFO: Update available for $image_name"
        return 1  # Update needed
    fi
}

update_service() {
    local image_name="$1"
    local service_name="$2"
    
    echo -e "${BLUE}🔄 Updating $service_name...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}  [DRY RUN] Would pull $image_name:latest${NC}"
        echo -e "${YELLOW}  [DRY RUN] Would restart service: $service_name${NC}"
        return 0
    fi
    
    # Pull latest image
    echo -e "${BLUE}  📥 Pulling latest image...${NC}"
    if docker pull "$image_name:latest" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✅ Image pulled successfully${NC}"
        log_message "SUCCESS: Pulled $image_name:latest"
    else
        echo -e "${RED}  ❌ Failed to pull image${NC}"
        log_message "ERROR: Failed to pull $image_name:latest"
        return 1
    fi
    
    # Restart service
    echo -e "${BLUE}  🔄 Restarting service...${NC}"
    if docker-compose up -d "$service_name" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✅ Service restarted successfully${NC}"
        log_message "SUCCESS: Restarted service $service_name"
        return 0
    else
        echo -e "${RED}  ❌ Failed to restart service${NC}"
        log_message "ERROR: Failed to restart service $service_name"
        return 1
    fi
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

check_all_updates() {
    echo -e "${BLUE}🔍 Checking for Docker Hub updates...${NC}"
    echo ""
    
    local updates_available=0
    local up_to_date=0
    local errors=0
    local services_to_update=()
    
    for i in "${!IMAGES[@]}"; do
        local image="${IMAGES[$i]}"
        local service="${SERVICES[$i]}"
        
        check_image_update "$image" "$service"
        local status=$?
        
        case $status in
            0) ((up_to_date++)) ;;
            1) 
                ((updates_available++))
                services_to_update+=("$service")
                ;;
            2) ((errors++)) ;;
        esac
        
        echo ""
    done
    
    # Summary
    echo -e "${BLUE}📊 Summary:${NC}"
    echo -e "   Updates available: ${YELLOW}$updates_available${NC}"
    echo -e "   Up to date: ${GREEN}$up_to_date${NC}"
    echo -e "   Errors: ${RED}$errors${NC}"
    
    if [[ $updates_available -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Services with updates: ${services_to_update[*]}${NC}"
        echo -e "${BLUE}Run with --update-all to update all services${NC}"
    fi
    
    log_message "SUMMARY: $updates_available updates, $up_to_date up-to-date, $errors errors"
}

update_all_services() {
    echo -e "${BLUE}🔄 Checking and updating all services...${NC}"
    echo ""
    
    local updated=0
    local failed=0
    
    for i in "${!IMAGES[@]}"; do
        local image="${IMAGES[$i]}"
        local service="${SERVICES[$i]}"
        
        check_image_update "$image" "$service"
        local needs_update=$?
        
        if [[ $needs_update -eq 1 ]]; then
            update_service "$image" "$service"
            if [[ $? -eq 0 ]]; then
                ((updated++))
            else
                ((failed++))
            fi
        fi
        
        echo ""
    done
    
    echo -e "${BLUE}📊 Update Summary:${NC}"
    echo -e "   Updated: ${GREEN}$updated${NC}"
    echo -e "   Failed: ${RED}$failed${NC}"
    
    log_message "UPDATE_SUMMARY: $updated updated, $failed failed"
}

update_specific_service() {
    local target_service="$1"
    local found=false
    
    for i in "${!SERVICES[@]}"; do
        if [[ "${SERVICES[$i]}" == "$target_service" ]]; then
            found=true
            local image="${IMAGES[$i]}"
            local service="${SERVICES[$i]}"
            
            echo -e "${BLUE}🔄 Checking and updating $service...${NC}"
            echo ""
            
            check_image_update "$image" "$service"
            local needs_update=$?
            
            if [[ $needs_update -eq 1 ]]; then
                echo ""
                update_service "$image" "$service"
            elif [[ $needs_update -eq 0 ]]; then
                echo -e "${GREEN}No update needed for $service${NC}"
            fi
            
            break
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        echo -e "${RED}❌ Service '$target_service' not found${NC}"
        echo -e "${BLUE}Available services: ${SERVICES[*]}${NC}"
        exit 1
    fi
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    # Initialize log
    log_message "=== Docker Hub Update Checker Started ==="
    
    # Check dependencies
    check_dependencies
    
    # Parse arguments
    local action="check"
    local target_service=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                action="check"
                shift
                ;;
            --update-all)
                action="update-all"
                shift
                ;;
            --update)
                action="update-service"
                target_service="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Execute action
    case $action in
        "check")
            check_all_updates
            ;;
        "update-all")
            update_all_services
            ;;
        "update-service")
            if [[ -z "$target_service" ]]; then
                echo -e "${RED}❌ Service name required with --update${NC}"
                print_usage
                exit 1
            fi
            update_specific_service "$target_service"
            ;;
    esac
    
    log_message "=== Docker Hub Update Checker Finished ==="
}

# Run main function with all arguments
main "$@"
