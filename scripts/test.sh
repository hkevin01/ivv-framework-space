#!/bin/bash

# 🛰️ IV&V Space Systems Framework - Testing Script
# Comprehensive testing suite for the IV&V framework

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

# Default values
RUN_UNIT=true
RUN_INTEGRATION=false
RUN_PERFORMANCE=false
RUN_COVERAGE=true
VERBOSE=false
FAIL_FAST=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            RUN_INTEGRATION=false
            RUN_PERFORMANCE=false
            shift
            ;;
        --integration)
            RUN_INTEGRATION=true
            shift
            ;;
        --performance)
            RUN_PERFORMANCE=true
            shift
            ;;
        --all)
            RUN_INTEGRATION=true
            RUN_PERFORMANCE=true
            shift
            ;;
        --no-coverage)
            RUN_COVERAGE=false
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --fail-fast|-x)
            FAIL_FAST=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --unit-only      Run only unit tests (default)"
            echo "  --integration    Include integration tests"
            echo "  --performance    Include performance tests"
            echo "  --all            Run all test types"
            echo "  --no-coverage    Skip coverage reporting"
            echo "  --verbose, -v    Verbose output"
            echo "  --fail-fast, -x  Stop on first failure"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "IV&V Framework Test Suite"

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

# Prepare pytest arguments
PYTEST_ARGS=""
if [ "$VERBOSE" = true ]; then
    PYTEST_ARGS="$PYTEST_ARGS -v"
fi
if [ "$FAIL_FAST" = true ]; then
    PYTEST_ARGS="$PYTEST_ARGS -x"
fi
if [ "$RUN_COVERAGE" = true ]; then
    PYTEST_ARGS="$PYTEST_ARGS --cov=src --cov-report=html --cov-report=term"
fi

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0

run_test_suite() {
    local test_name="$1"
    local test_path="$2"
    local additional_args="$3"
    
    print_header "Running $test_name"
    
    if [ ! -d "$test_path" ]; then
        print_warning "Test directory $test_path not found, skipping..."
        return 0
    fi
    
    if pytest $test_path $PYTEST_ARGS $additional_args; then
        print_status "$test_name passed ✓"
        ((TESTS_PASSED++))
        return 0
    else
        print_error "$test_name failed ✗"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Code quality checks
print_header "Code Quality Checks"

print_status "Running Black formatting check..."
if black --check src/ tests/ 2>/dev/null; then
    print_status "Code formatting: PASSED ✓"
else
    print_warning "Code formatting issues found. Run 'black src/ tests/' to fix"
fi

print_status "Running isort import check..."
if isort --check-only src/ tests/ 2>/dev/null; then
    print_status "Import sorting: PASSED ✓"
else
    print_warning "Import sorting issues found. Run 'isort src/ tests/' to fix"
fi

print_status "Running MyPy type checking..."
if mypy src/ 2>/dev/null; then
    print_status "Type checking: PASSED ✓"
else
    print_warning "Type checking issues found"
fi

print_status "Running Bandit security check..."
if bandit -r src/ -f json -o bandit-report.json 2>/dev/null; then
    print_status "Security scan: PASSED ✓"
else
    print_warning "Security issues found. Check bandit-report.json"
fi

# Unit tests
if [ "$RUN_UNIT" = true ]; then
    run_test_suite "Unit Tests" "tests/unit" "-m 'not slow'"
fi

# Integration tests
if [ "$RUN_INTEGRATION" = true ]; then
    run_test_suite "Integration Tests" "tests/integration" "-m integration"
fi

# Performance tests
if [ "$RUN_PERFORMANCE" = true ]; then
    run_test_suite "Performance Tests" "tests/performance" "--benchmark-only"
fi

# C++ tests (if available)
if [ -d "build" ] && [ -f "build/Makefile" ]; then
    print_header "Running C++ Tests"
    cd build
    if make test; then
        print_status "C++ tests passed ✓"
        ((TESTS_PASSED++))
    else
        print_error "C++ tests failed ✗"
        ((TESTS_FAILED++))
    fi
    cd ..
fi

# Memory leak detection (if valgrind is available)
if command -v valgrind &> /dev/null && [ -d "build" ]; then
    print_header "Memory Leak Detection"
    print_status "Running Valgrind memory check..."
    
    if [ -f "build/tests/unit_tests" ]; then
        valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all \
                 --track-origins=yes --xml=yes --xml-file=valgrind-report.xml \
                 ./build/tests/unit_tests &>/dev/null
        
        if [ $? -eq 0 ]; then
            print_status "Memory leak check: PASSED ✓"
        else
            print_warning "Memory issues detected. Check valgrind-report.xml"
        fi
    fi
fi

# Security vulnerability check
print_header "Security Vulnerability Scan"
print_status "Checking for known vulnerabilities..."
if safety check --json --output safety-report.json 2>/dev/null; then
    print_status "Vulnerability scan: PASSED ✓"
else
    print_warning "Vulnerabilities found. Check safety-report.json"
fi

# Generate coverage report
if [ "$RUN_COVERAGE" = true ] && [ -f ".coverage" ]; then
    print_header "Coverage Report"
    coverage report --show-missing
    print_status "Coverage report generated in htmlcov/"
fi

# Final summary
print_header "Test Summary"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

if [ $TOTAL_TESTS -eq 0 ]; then
    print_warning "No tests were run"
    exit 0
fi

print_status "Tests passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    print_error "Tests failed: $TESTS_FAILED"
    echo ""
    print_error "Some tests failed. Check the output above for details."
    exit 1
else
    echo ""
    print_status "All tests passed! 🎉"
    exit 0
fi
