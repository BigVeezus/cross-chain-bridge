#!/bin/bash

# ZK NFT Bridge - Complete Setup Script
# This script will help you set up and run the entire cross-chain NFT bridge system

set -e

echo "🌉 ZK NFT Bridge - Complete Setup Script"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v forge &> /dev/null; then
        print_error "Foundry is not installed. Please install it first:"
        echo "curl -L https://foundry.paradigm.xyz | bash"
        echo "foundryup"
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    fi
    
    if ! command -v pnpm &> /dev/null; then
        print_warning "pnpm is not installed. Installing pnpm..."
        npm install -g pnpm
    fi
    
    print_success "All dependencies are installed!"
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Install contract dependencies
    cd contracts
    forge install
    print_success "Contract dependencies installed"
    
    # Install relayer dependencies
    cd ../relayer
    pnpm install
    print_success "Relayer dependencies installed"
    
    # Install frontend dependencies
    cd ../frontend
    pnpm install
    print_success "Frontend dependencies installed"
    
    cd ..
}

# Compile contracts
compile_contracts() {
    print_status "Compiling contracts..."
    cd contracts
    forge build
    print_success "Contracts compiled successfully"
    cd ..
}

# Run tests
run_tests() {
    print_status "Running contract tests..."
    cd contracts
    forge test
    print_success "All tests passed!"
    cd ..
}

# Deploy contracts
deploy_contracts() {
    print_status "Deploying contracts..."
    
    # Check if .env file exists
    if [ ! -f "contracts/.env" ]; then
        print_warning "Creating contracts/.env file..."
        cp contracts/env.example contracts/.env
        print_warning "Please update contracts/.env with your configuration"
    fi
    
    cd contracts
    
    print_status "Deploying to source chain (localhost:8545)..."
    
    # Deploy and capture output
    DEPLOY_OUTPUT=$(forge script script/Deploy.s.sol:DeployLocal \
        --rpc-url http://localhost:8545 \
        --broadcast \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 2>&1)
    
    echo "$DEPLOY_OUTPUT"
    
    # Extract contract addresses from deployment output
    MOCK_NFT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "MockNFT deployed at:" | sed 's/.*MockNFT deployed at: //')
    SOURCE_BRIDGE_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "SourceBridge deployed at:" | sed 's/.*SourceBridge deployed at: //')
    DEST_BRIDGE_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "DestinationBridge deployed at:" | sed 's/.*DestinationBridge deployed at: //')
    WRAPPED_NFT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "WrappedNFT deployed at:" | sed 's/.*WrappedNFT deployed at: //')
    
    cd ..
    
    # Update environment files with deployed addresses
    if [ ! -z "$MOCK_NFT_ADDR" ] && [ ! -z "$SOURCE_BRIDGE_ADDR" ] && [ ! -z "$DEST_BRIDGE_ADDR" ]; then
        print_status "Updating environment files with deployed addresses..."
        
        # Update relayer .env
        cat > relayer/.env << EOF
SOURCE_RPC=http://localhost:8545
DEST_RPC=http://localhost:8546
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SOURCE_BRIDGE=$SOURCE_BRIDGE_ADDR
DEST_BRIDGE=$DEST_BRIDGE_ADDR
POLL_INTERVAL=5000
EOF
        
        # Update frontend .env.local
        cat > frontend/.env.local << EOF
NEXT_PUBLIC_SOURCE_RPC=http://localhost:8545
NEXT_PUBLIC_DEST_RPC=http://localhost:8546
NEXT_PUBLIC_SOURCE_BRIDGE=$SOURCE_BRIDGE_ADDR
NEXT_PUBLIC_DEST_BRIDGE=$DEST_BRIDGE_ADDR
NEXT_PUBLIC_MOCK_NFT=$MOCK_NFT_ADDR
EOF
        
        print_success "Environment files updated with deployed addresses!"
        print_success "MockNFT: $MOCK_NFT_ADDR"
        print_success "SourceBridge: $SOURCE_BRIDGE_ADDR"
        print_success "DestinationBridge: $DEST_BRIDGE_ADDR"
        if [ ! -z "$WRAPPED_NFT_ADDR" ]; then
            print_success "WrappedNFT: $WRAPPED_NFT_ADDR"
        fi
    else
        print_warning "Could not extract contract addresses from deployment output"
        print_warning "Please manually update .env files with deployed addresses"
    fi
}

# Setup environment files
setup_env_files() {
    print_status "Setting up environment files..."
    
    # Create relayer .env with proper configuration
    cat > relayer/.env << 'EOF'
SOURCE_RPC=http://localhost:8545
DEST_RPC=http://localhost:8546
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SOURCE_BRIDGE=0x0000000000000000000000000000000000000000
DEST_BRIDGE=0x0000000000000000000000000000000000000000
POLL_INTERVAL=5000
EOF
    
    # Create frontend .env.local with proper configuration
    cat > frontend/.env.local << 'EOF'
NEXT_PUBLIC_SOURCE_RPC=http://localhost:8545
NEXT_PUBLIC_DEST_RPC=http://localhost:8546
NEXT_PUBLIC_SOURCE_BRIDGE=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_DEST_BRIDGE=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_MOCK_NFT=0x0000000000000000000000000000000000000000
EOF
    
    print_success "Environment files created with proper configuration!"
    print_warning "Note: Contract addresses are set to zero - update after deployment"
}

# Start local chains
start_chains() {
    print_status "Starting local chains..."
    
    print_status "Starting source chain (port 8545)..."
    anvil --port 8545 --chain-id 1 &
    SOURCE_CHAIN_PID=$!
    
    print_status "Starting destination chain (port 8546)..."
    anvil --port 8546 --chain-id 421614 &
    DEST_CHAIN_PID=$!
    
    print_success "Local chains started!"
    print_warning "Chain PIDs: Source=$SOURCE_CHAIN_PID, Dest=$DEST_CHAIN_PID"
    print_warning "To stop chains: kill $SOURCE_CHAIN_PID $DEST_CHAIN_PID"
}

# Start relayer
start_relayer() {
    print_status "Starting relayer service..."
    cd relayer
    pnpm start &
    RELAYER_PID=$!
    cd ..
    
    print_success "Relayer started! PID: $RELAYER_PID"
    print_warning "To stop relayer: kill $RELAYER_PID"
}

# Start frontend
start_frontend() {
    print_status "Starting frontend..."
    cd frontend
    pnpm dev &
    FRONTEND_PID=$!
    cd ..
    
    print_success "Frontend started! PID: $FRONTEND_PID"
    print_warning "Frontend available at: http://localhost:3000"
    print_warning "To stop frontend: kill $FRONTEND_PID"
}

# Main menu
show_menu() {
    echo ""
    echo "What would you like to do?"
    echo "1) Check dependencies"
    echo "2) Install all dependencies"
    echo "3) Compile contracts"
    echo "4) Run tests"
    echo "5) Deploy contracts"
    echo "6) Setup environment files"
    echo "7) Start local chains"
    echo "8) Start relayer"
    echo "9) Start frontend"
    echo "10) Full setup (1-6)"
    echo "11) Start all services (7-9)"
    echo "12) Complete setup (1-9)"
    echo "13) Fix and restart services"
    echo "0) Exit"
    echo ""
    read -p "Enter your choice: " choice
}

# Full setup
full_setup() {
    check_dependencies
    install_dependencies
    compile_contracts
    run_tests
    deploy_contracts
    setup_env_files
    print_success "Full setup completed!"
    print_warning "Next steps:"
    print_warning "1. Update .env files with deployed contract addresses"
    print_warning "2. Run 'Start all services' to begin testing"
}

# Start all services
start_all_services() {
    start_chains
    sleep 5
    start_relayer
    sleep 2
    start_frontend
    
    print_success "All services started!"
    print_warning "Services running:"
    print_warning "- Source Chain: http://localhost:8545"
    print_warning "- Destination Chain: http://localhost:8546"
    print_warning "- Frontend: http://localhost:3000"
    print_warning "- Relayer: Running in background"
}

# Fix and restart services
fix_and_restart_services() {
    print_status "Fixing configuration and restarting services..."
    
    # Kill existing processes
    print_status "Stopping existing services..."
    pkill -f "anvil" 2>/dev/null || true
    pkill -f "relayer" 2>/dev/null || true
    pkill -f "frontend" 2>/dev/null || true
    sleep 2
    
    # Setup environment files with fixes
    setup_env_files
    
    # Start services
    start_all_services
    
    print_success "Services restarted with fixed configuration!"
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) check_dependencies ;;
        2) install_dependencies ;;
        3) compile_contracts ;;
        4) run_tests ;;
        5) deploy_contracts ;;
        6) setup_env_files ;;
        7) start_chains ;;
        8) start_relayer ;;
        9) start_frontend ;;
        10) full_setup ;;
        11) start_all_services ;;
        12) complete_setup ;;
        13) fix_and_restart_services ;;
        0) print_success "Goodbye!"; exit 0 ;;
        *) print_error "Invalid choice. Please try again." ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
