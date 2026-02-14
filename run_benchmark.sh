#!/bin/bash
set -e

#
# Run a single HDMapping LiDAR SLAM benchmark.
#
# Checks out the dataset branch, builds the Docker image, and runs the benchmark.
#
# Options:
#   --build-only  Only checkout branch and build Docker image, skip execution
#
# Usage:
#   ./run_benchmark.sh [--build-only] <benchmark_dir> <input> [output_dir]
#
# Examples:
#   ./run_benchmark.sh benchmarks/benchmark-FAST-LIO-to-HDMapping data/reg-1.bag
#   ./run_benchmark.sh benchmarks/benchmark-CT-ICP-to-HDMapping data/reg-1.bag-pc.bag
#   ./run_benchmark.sh --build-only benchmarks/benchmark-KISS-ICP-to-HDMapping
#

BRANCH="Bunker-DVI-Dataset-reg-1"
BUILD_ONLY=false

# --- Parse flags ---
while [[ $# -gt 0 && "$1" == --* ]]; do
    case $1 in
        --build-only) BUILD_ONLY=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if $BUILD_ONLY; then
    if [ $# -lt 1 ] || [ $# -gt 1 ]; then
        echo "Usage: $0 --build-only <benchmark_dir>"
        echo ""
        echo "  <benchmark_dir>  Path to a benchmark-*-to-HDMapping repo"
        exit 1
    fi
else
    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        echo "Usage: $0 [--build-only] <benchmark_dir> <input> [output_dir]"
        echo ""
        echo "  --build-only     Only checkout and build, skip benchmark execution"
        echo "  <benchmark_dir>  Path to a benchmark-*-to-HDMapping repo"
        echo "  <input>          Input bag file or directory"
        echo "  <output_dir>     Output directory for results (default: outputs)"
        exit 1
    fi
fi

REPO_DIR=$(realpath "$1")
REPO_NAME=$(basename "$REPO_DIR")
NAME=$(echo "$REPO_NAME" | sed 's/^benchmark-//; s/-to-HDMapping$//')

# --- Validate ---
if [ ! -d "$REPO_DIR" ]; then
    echo "ERROR: Benchmark directory not found: $REPO_DIR"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    exit 1
fi

if ! $BUILD_ONLY; then
    INPUT=$(realpath "$2")
    OUTPUT_DIR=$(realpath "${3:-outputs}")

    if [ ! -f "$INPUT" ] && [ ! -d "$INPUT" ]; then
        echo "ERROR: Input not found: $INPUT"
        exit 1
    fi

    mkdir -p "$OUTPUT_DIR"
fi

echo "========================================"
echo " $NAME"
echo "========================================"
echo "Repo:   $REPO_DIR"
if ! $BUILD_ONLY; then
    echo "Input:  $INPUT"
    echo "Output: $OUTPUT_DIR"
fi
echo ""

# --- Checkout branch ---
cd "$REPO_DIR"
if ! git checkout "$BRANCH" 2>/dev/null; then
    echo "ERROR: Branch $BRANCH not found in $REPO_NAME"
    exit 1
fi

# --- Find run script ---
RUN_SCRIPT=$(find "$REPO_DIR" -maxdepth 1 -name "docker_session_run-*.sh" | head -1)
if [ -z "$RUN_SCRIPT" ]; then
    echo "ERROR: No docker_session_run-*.sh found in $REPO_NAME"
    exit 1
fi
RUN_SCRIPT_NAME=$(basename "$RUN_SCRIPT")

# --- Docker tag from run script name ---
ALGO=$(echo "$RUN_SCRIPT_NAME" | sed 's/docker_session_run-ros[12]-//; s/\.sh//')
if [[ "$RUN_SCRIPT_NAME" == *"ros2"* ]]; then
    DOCKER_TAG="${ALGO}_humble"
else
    DOCKER_TAG="${ALGO}_noetic"
fi

# --- Build ---
echo ">> Building Docker image: $DOCKER_TAG ..."
if ! docker build -t "$DOCKER_TAG" .; then
    echo "ERROR: Docker build failed for $NAME"
    exit 1
fi

if $BUILD_ONLY; then
    echo ""
    echo ">> Build complete: $NAME (--build-only, skipping execution)"
    exit 0
fi

# --- Run ---
chmod +x "$RUN_SCRIPT"
echo ">> Running $NAME ..."
cd "$OUTPUT_DIR"
"$RUN_SCRIPT" "$INPUT" .

echo ""
echo ">> Done: $NAME"
echo ">> Output: $OUTPUT_DIR"
