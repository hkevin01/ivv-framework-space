#!/bin/bash

# 🛰️ IV&V Space Systems Framework - Setup Script
# This script sets up the development environment for the IV&V framework

set -e  # Exit on any error

echo "🚀 Setting up IV&V Space Systems Framework..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    echo -e "${BLUE}$1${NC}"
}

# Check if running from project root
if [ ! -f "README.md" ] || [ ! -d "src" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_header "🔍 Checking system requirements..."

# Check Python version
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)
    
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 9 ]; then
        print_status "Python $PYTHON_VERSION found ✓"
    else
        print_error "Python 3.9+ required, found $PYTHON_VERSION"
        exit 1
    fi
else
    print_error "Python 3 not found. Please install Python 3.9+"
    exit 1
fi

# Check for essential tools
REQUIRED_TOOLS=("git" "docker" "cmake" "gcc")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v $tool &> /dev/null; then
        print_status "$tool found ✓"
    else
        print_warning "$tool not found. Some features may not work."
    fi
done

print_header "📦 Setting up Python environment..."

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
print_status "Upgrading pip..."
pip install --upgrade pip

# Install requirements
print_status "Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    print_warning "requirements.txt not found, creating basic requirements..."
    cat > requirements.txt << EOF
# Core dependencies
numpy>=1.21.0
pandas>=1.3.0
matplotlib>=3.4.0
plotly>=5.0.0
dash>=2.0.0
pydantic>=1.8.0
typer>=0.4.0
pyyaml>=5.4.0
requests>=2.25.0

# Testing
pytest>=6.2.0
pytest-cov>=2.12.0
pytest-xdist>=2.3.0
pytest-benchmark>=3.4.0

# Code quality
black>=21.0.0
isort>=5.9.0
mypy>=0.910
pylint>=2.9.0
bandit>=1.7.0
safety>=1.10.0

# Documentation
mkdocs>=1.2.0
mkdocs-material>=7.0.0
mkdocs-mermaid2-plugin>=0.5.0

# Database
sqlalchemy>=1.4.0
psycopg2-binary>=2.9.0

# AI/ML (optional)
onnxruntime>=1.8.0
scikit-learn>=1.0.0
transformers>=4.10.0
EOF
    pip install -r requirements.txt
fi

# Install development requirements
if [ -f "requirements-dev.txt" ]; then
    print_status "Installing development dependencies..."
    pip install -r requirements-dev.txt
else
    print_warning "requirements-dev.txt not found, creating development requirements..."
    cat > requirements-dev.txt << EOF
# Development tools
pre-commit>=2.15.0
jupyter>=1.0.0
ipython>=7.25.0
notebook>=6.4.0

# Additional testing tools
hypothesis>=6.14.0
factory-boy>=3.2.0
responses>=0.13.0
freezegun>=1.1.0

# Performance profiling
py-spy>=0.3.0
memory-profiler>=0.58.0
line-profiler>=3.3.0

# Static analysis
vulture>=2.3.0
radon>=5.1.0
xenon>=0.7.0
EOF
    pip install -r requirements-dev.txt
fi

print_header "🏗️ Setting up C++ build environment..."

# Create build directory
if [ ! -d "build" ]; then
    print_status "Creating build directory..."
    mkdir build
fi

# Check if CMakeLists.txt exists
if [ ! -f "CMakeLists.txt" ]; then
    print_status "Creating CMakeLists.txt..."
    cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.16)
project(IVVSpaceSystems VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable testing
enable_testing()

# Find packages
find_package(GTest QUIET)
find_package(Threads REQUIRED)

# Include directories
include_directories(src/cpp)

# Add subdirectories
add_subdirectory(src/cpp)
add_subdirectory(tests/cpp)

# Compiler flags
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(-g -O0 --coverage)
        add_link_options(--coverage)
    endif()
endif()
EOF
fi

print_header "🐳 Setting up Docker environment..."

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    print_status "Creating Dockerfile..."
    cat > Dockerfile << 'EOF'
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libgtest-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements*.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 ivv && chown -R ivv:ivv /app
USER ivv

# Default command
CMD ["python", "ivv_runner.py", "--help"]
EOF
fi

# Create docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    print_status "Creating docker-compose.yml..."
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  ivv-framework:
    build: .
    volumes:
      - .:/app
      - ivv-data:/app/data
    environment:
      - PYTHONPATH=/app/src
    ports:
      - "8050:8050"  # Dashboard
    depends_on:
      - postgres
    networks:
      - ivv-network

  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: ivv_framework
      POSTGRES_USER: ivv_user
      POSTGRES_PASSWORD: ivv_password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - ivv-network

  redis:
    image: redis:6-alpine
    ports:
      - "6379:6379"
    networks:
      - ivv-network

volumes:
  postgres-data:
  ivv-data:

networks:
  ivv-network:
    driver: bridge
EOF
fi

print_header "🔧 Setting up Git hooks..."

# Install pre-commit hooks
if command -v pre-commit &> /dev/null; then
    if [ ! -f ".pre-commit-config.yaml" ]; then
        print_status "Creating pre-commit configuration..."
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: debug-statements

  - repo: https://github.com/psf/black
    rev: 22.12.0
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort

  - repo: https://github.com/pycqa/bandit
    rev: 1.7.4
    hooks:
      - id: bandit
        args: ["-r", "src/"]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v0.991
    hooks:
      - id: mypy
        additional_dependencies: [types-all]
EOF
    fi
    
    print_status "Installing pre-commit hooks..."
    pre-commit install
else
    print_warning "pre-commit not installed. Git hooks will not be set up."
fi

print_header "📁 Creating project structure..."

# Create source directories
DIRECTORIES=(
    "src/core"
    "src/simulation"
    "src/analysis"
    "src/rtm"
    "src/dashboard"
    "src/plugins"
    "src/cpp/core"
    "src/cpp/simulation"
    "tests/unit"
    "tests/integration"
    "tests/performance"
    "tests/cpp"
    "examples/scenarios"
    "examples/configs"
    "config/templates"
    "docs/api"
    "docs/user-guide"
    "docs/standards"
    "data/scenarios"
    "data/telemetry"
    "logs"
)

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_status "Created directory: $dir"
    fi
done

# Create __init__.py files
find src -type d -exec touch {}/__init__.py \; 2>/dev/null || true

print_header "📄 Creating essential configuration files..."

# Create pyproject.toml
if [ ! -f "pyproject.toml" ]; then
    cat > pyproject.toml << 'EOF'
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "ivv-space-systems"
version = "0.1.0"
description = "Mission-Critical IV&V Toolkit for Space Systems"
authors = [{name = "Space Systems Team", email = "team@space-systems.org"}]
license = {text = "MIT"}
readme = "README.md"
requires-python = ">=3.9"
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Science/Research",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Topic :: Scientific/Engineering :: Aerospace",
]

[project.scripts]
ivv-runner = "src.cli:main"

[tool.black]
line-length = 88
target-version = ['py39']
include = '\.pyi?$'

[tool.isort]
profile = "black"
multi_line_output = 3

[tool.mypy]
python_version = "3.9"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "-v --strict-markers"
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
    "performance: Performance tests",
    "slow: Slow running tests",
]

[tool.coverage.run]
source = ["src"]
omit = ["tests/*", "setup.py"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
]
EOF
fi

print_header "✅ Setup complete!"

print_status "Next steps:"
echo "  1. Activate the virtual environment: source venv/bin/activate"
echo "  2. Run tests: pytest tests/"
echo "  3. Start development: python ivv_runner.py --help"
echo "  4. Build documentation: mkdocs serve"
echo "  5. Start dashboard: python -m src.dashboard.app"

print_status "For Docker development:"
echo "  1. Build image: docker-compose build"
echo "  2. Run services: docker-compose up"

print_status "Happy coding! 🚀"
