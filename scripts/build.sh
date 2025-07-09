#!/bin/bash

# 🛰️ IV&V Space Systems Framework - Build Script
# Build and compile all components of the IV&V framework

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Build configuration
BUILD_TYPE="Release"
CLEAN_BUILD=false
VERBOSE=false
BUILD_DOCS=false
BUILD_DOCKER=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --docs)
            BUILD_DOCS=true
            shift
            ;;
        --docker)
            BUILD_DOCKER=true
            shift
            ;;
        --all)
            BUILD_DOCS=true
            BUILD_DOCKER=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug          Build in debug mode"
            echo "  --clean          Clean build directory first"
            echo "  --verbose, -v    Verbose build output"
            echo "  --docs           Build documentation"
            echo "  --docker         Build Docker images"
            echo "  --all            Build everything"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "IV&V Framework Build System"

# Check if we're in the project root
if [ ! -f "README.md" ] || [ ! -d "src" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning build directory..."
    rm -rf build/
    rm -rf dist/
    rm -rf *.egg-info/
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
fi

# Create build directory
if [ ! -d "build" ]; then
    mkdir build
fi

# Python package build
print_header "Building Python Package"

# Check if virtual environment is activated
if [[ "$VIRTUAL_ENV" == "" ]]; then
    print_warning "Virtual environment not detected. Activating..."
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        print_status "Virtual environment activated"
    else
        print_error "Virtual environment not found. Run scripts/setup.sh first"
        exit 1
    fi
fi

print_status "Installing/updating build dependencies..."
pip install --upgrade build wheel setuptools

print_status "Building Python package..."
python -m build

if [ $? -eq 0 ]; then
    print_status "Python package build: PASSED ✓"
else
    print_error "Python package build: FAILED ✗"
    exit 1
fi

# C++ build
print_header "Building C++ Components"

if [ ! -f "CMakeLists.txt" ]; then
    print_warning "CMakeLists.txt not found, skipping C++ build"
else
    cd build
    
    print_status "Configuring CMake..."
    CMAKE_ARGS="-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    
    if [ "$VERBOSE" = true ]; then
        CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_VERBOSE_MAKEFILE=ON"
    fi
    
    cmake .. $CMAKE_ARGS
    
    if [ $? -ne 0 ]; then
        print_error "CMake configuration failed"
        cd ..
        exit 1
    fi
    
    print_status "Building C++ components..."
    
    # Determine number of parallel jobs
    NPROC=$(nproc 2>/dev/null || echo 4)
    
    if [ "$VERBOSE" = true ]; then
        make -j$NPROC VERBOSE=1
    else
        make -j$NPROC
    fi
    
    if [ $? -eq 0 ]; then
        print_status "C++ build: PASSED ✓"
    else
        print_error "C++ build: FAILED ✗"
        cd ..
        exit 1
    fi
    
    cd ..
fi

# Build documentation
if [ "$BUILD_DOCS" = true ]; then
    print_header "Building Documentation"
    
    if command -v mkdocs &> /dev/null; then
        print_status "Building MkDocs documentation..."
        
        # Create mkdocs.yml if it doesn't exist
        if [ ! -f "mkdocs.yml" ]; then
            print_status "Creating mkdocs.yml configuration..."
            cat > mkdocs.yml << 'EOF'
site_name: IV&V Space Systems Framework
site_description: Mission-Critical IV&V Toolkit for Space Systems
site_author: Space Systems Team
site_url: https://hkevin01.github.io/ivv-framework-space

repo_name: hkevin01/ivv-framework-space
repo_url: https://github.com/hkevin01/ivv-framework-space

theme:
  name: material
  palette:
    - scheme: default
      primary: indigo
      accent: indigo
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.highlight
    - search.share

plugins:
  - search
  - mermaid2

markdown_extensions:
  - admonition
  - codehilite
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.tabbed
  - pymdownx.details
  - toc:
      permalink: true

nav:
  - Home: index.md
  - User Guide:
    - Getting Started: user-guide/getting-started.md
    - Configuration: user-guide/configuration.md
    - Scenarios: user-guide/scenarios.md
  - API Reference:
    - Core: api/core.md
    - Simulation: api/simulation.md
    - Analysis: api/analysis.md
  - Standards:
    - NASA Standards: standards/nasa.md
    - DO-178C: standards/do-178c.md
    - ECSS: standards/ecss.md
  - Development:
    - Contributing: contributing.md
    - Architecture: development/architecture.md
    - Testing: development/testing.md
EOF
        fi
        
        mkdocs build --strict
        
        if [ $? -eq 0 ]; then
            print_status "Documentation build: PASSED ✓"
            print_status "Documentation available in site/"
        else
            print_error "Documentation build: FAILED ✗"
        fi
    else
        print_warning "mkdocs not found, skipping documentation build"
    fi
fi

# Build Docker images
if [ "$BUILD_DOCKER" = true ]; then
    print_header "Building Docker Images"
    
    if command -v docker &> /dev/null; then
        print_status "Building main Docker image..."
        
        docker build -t ivv-space-systems:latest .
        
        if [ $? -eq 0 ]; then
            print_status "Docker image build: PASSED ✓"
        else
            print_error "Docker image build: FAILED ✗"
        fi
        
        # Build development image if Dockerfile.dev exists
        if [ -f "Dockerfile.dev" ]; then
            print_status "Building development Docker image..."
            docker build -f Dockerfile.dev -t ivv-space-systems:dev .
            
            if [ $? -eq 0 ]; then
                print_status "Development Docker image build: PASSED ✓"
            else
                print_error "Development Docker image build: FAILED ✗"
            fi
        fi
    else
        print_warning "Docker not found, skipping Docker build"
    fi
fi

# Static analysis (optional)
print_header "Static Analysis"

if command -v cppcheck &> /dev/null && [ -d "src/cpp" ]; then
    print_status "Running C++ static analysis..."
    cppcheck --enable=all --xml --xml-version=2 src/cpp/ 2> cppcheck-report.xml
    print_status "C++ static analysis report saved to cppcheck-report.xml"
fi

# Build summary
print_header "Build Summary"

print_status "Build configuration: $BUILD_TYPE"
print_status "Python package: ✓"

if [ -f "build/Makefile" ]; then
    print_status "C++ components: ✓"
fi

if [ "$BUILD_DOCS" = true ] && [ -d "site" ]; then
    print_status "Documentation: ✓"
fi

if [ "$BUILD_DOCKER" = true ]; then
    print_status "Docker images: ✓"
fi

print_status "Build artifacts:"
echo "  - Python package: dist/"
echo "  - C++ binaries: build/"
if [ -d "site" ]; then
    echo "  - Documentation: site/"
fi

print_status "Build completed successfully! 🚀"
