#!/bin/bash
set -e

#
# Prepare LiDAR bag data in multiple formats for benchmarking.
#
# Converts a Livox CustomMsg ROS1 bag into standardized formats:
#   --ros1    PointCloud2 ROS1 bag   (livox_bag_aggregate Docker)
#   --ros2    PointCloud2 ROS2 bag   (rosbags-convert, requires --ros1 first)
#   --livox-ros2  Livox CustomMsg ROS2   (mandeye_to_bag Docker + rosbags-convert)
#   --all     All of the above
#
# Without flags, only copies the original bag (Livox CustomMsg ROS1).
#
# Requirements:
#   --ros1    Docker + livox_bag_aggregate_noetic image
#   --ros2    Docker + rosbags-convert image (built automatically)
#   --livox-ros2  Docker + mandeye-ws_noetic & mandeye-ws_humble & rosbags-convert images
#
# Usage:
#   ./prepare_benchmark_data.sh [--ros1] [--ros2] [--livox-ros2] [--all] <input.bag> [output_dir]
#
# Examples:
#   ./prepare_benchmark_data.sh --all data/reg-1.bag
#   ./prepare_benchmark_data.sh --ros1 --ros2 data/reg-1.bag
#   ./prepare_benchmark_data.sh --livox-ros2 data/reg-1.bag
#

DO_ROS1=false
DO_ROS2=false
DO_LIVOX_ROS2=false

# --- Parse arguments ---
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --ros1)   DO_ROS1=true;   shift ;;
        --ros2)   DO_ROS2=true;   shift ;;
        --livox-ros2) DO_LIVOX_ROS2=true; shift ;;
        --all)    DO_ROS1=true; DO_ROS2=true; DO_LIVOX_ROS2=true; shift ;;
        -h|--help)
            sed -n '3,30s/^# \?//p' "$0"
            exit 0
            ;;
        *)        POSITIONAL+=("$1"); shift ;;
    esac
done

INPUT_BAG="${POSITIONAL[0]}"
OUTPUT_DIR="${POSITIONAL[1]}"

if [ -z "$INPUT_BAG" ]; then
    echo "Usage: $0 [--ros1] [--ros2] [--livox-ros2] [--all] <input.bag> [output_dir]"
    echo ""
    echo "Flags:"
    echo "  --ros1    Generate PointCloud2 ROS1 bag  (via livox_bag_aggregate Docker)"
    echo "  --ros2    Generate PointCloud2 ROS2 bag  (via rosbags-convert, requires --ros1)"
    echo "  --livox-ros2  Generate Livox CustomMsg ROS2  (via mandeye_to_bag Docker)"
    echo "  --all     Generate all of the above"
    echo "  (no flag) Only copy the original Livox CustomMsg bag"
    exit 1
fi

# Default output directory: same directory as input bag
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(dirname "$INPUT_BAG")
fi

INPUT_BAG=$(realpath "$INPUT_BAG")
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASENAME=$(basename "$INPUT_BAG" .bag)

# --- Validate requirements ---
if [ ! -f "$INPUT_BAG" ]; then
    echo "ERROR: Input file not found: $INPUT_BAG"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    exit 1
fi

ROSBAGS_IMAGE="rosbags-convert"
if $DO_ROS2 || $DO_LIVOX_ROS2; then
    if ! docker image inspect "$ROSBAGS_IMAGE" &> /dev/null; then
        echo "Building Docker image $ROSBAGS_IMAGE..."
        # rosbags 0.9.22 generates metadata.yaml version 5, compatible with
        # Humble, Iron, and Jazzy. Newer rosbags (0.10+) generates version 8-9
        # which only Jazzy supports.
        docker build -t "$ROSBAGS_IMAGE" - <<'DOCKERFILE'
FROM python:3.10-slim
RUN pip install --no-cache-dir rosbags==0.9.22
ENTRYPOINT ["rosbags-convert"]
DOCKERFILE
    fi
fi

if $DO_ROS2 && ! $DO_ROS1; then
    echo "NOTE: --ros2 requires PointCloud2 ROS1 bag. Enabling --ros1 automatically."
    DO_ROS1=true
fi

# --- Interrupt handling ---
# On Ctrl+C: stop Docker containers and remove incomplete output.
CURRENT_OUTPUT=""
cleanup_on_interrupt() {
    for img in livox_bag_aggregate_noetic mandeye-ws_noetic mandeye-ws_humble; do
        docker rm -f $(docker ps -q --filter ancestor="$img") 2>/dev/null || true
    done
    if [ -n "$CURRENT_OUTPUT" ]; then
        rm -rf "$CURRENT_OUTPUT"
    fi
    exit 1
}
trap cleanup_on_interrupt INT

mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo " LiDAR bag data preparation"
echo "============================================"
echo "Input:  $INPUT_BAG"
echo "Output: $OUTPUT_DIR"
echo "Flags:  ros1=$DO_ROS1  ros2=$DO_ROS2  resple=$DO_LIVOX_ROS2"
echo ""

# --- Step 0: Copy original (always) ---
echo "[original] Copying Livox CustomMsg ROS1 bag..."
if [ "$INPUT_BAG" != "$OUTPUT_DIR/$BASENAME.bag" ]; then
    cp -n "$INPUT_BAG" "$OUTPUT_DIR/$BASENAME.bag" 2>/dev/null || true
fi
echo "  -> $OUTPUT_DIR/$BASENAME.bag"
echo ""

# --- Step 1: --ros1 (Livox CustomMsg -> PointCloud2 ROS1) ---
if $DO_ROS1; then
    echo "[--ros1] Converting Livox CustomMsg -> PointCloud2 ROS1..."
    if [ -f "$OUTPUT_DIR/$BASENAME.bag-pc.bag" ]; then
        echo "  Already exists, skipping."
    else
        if ! docker image inspect livox_bag_aggregate_noetic &> /dev/null; then
            echo "  Building Docker image livox_bag_aggregate_noetic..."
            docker build -t livox_bag_aggregate_noetic "$SCRIPT_DIR/livox_bag_aggregate"
        fi
        cd "$SCRIPT_DIR/livox_bag_aggregate"
        chmod +x livox_bag.sh
        CURRENT_OUTPUT="$OUTPUT_DIR/$BASENAME.bag-pc.bag"
        ./livox_bag.sh "$OUTPUT_DIR/$BASENAME.bag" "$OUTPUT_DIR"
        CURRENT_OUTPUT=""
    fi
    echo "  -> $OUTPUT_DIR/$BASENAME.bag-pc.bag"
    echo ""
fi

# --- Step 2: --ros2 (PointCloud2 ROS1 -> ROS2) ---
if $DO_ROS2; then
    echo "[--ros2] Converting PointCloud2 ROS1 -> ROS2..."
    if [ -d "$OUTPUT_DIR/${BASENAME}-ros2" ]; then
        echo "  Already exists, skipping."
    else
        if [ ! -f "$OUTPUT_DIR/$BASENAME.bag-pc.bag" ]; then
            echo "  ERROR: $BASENAME.bag-pc.bag not found. Run with --ros1 first."
            exit 1
        fi
        CURRENT_OUTPUT="$OUTPUT_DIR/${BASENAME}-ros2"
        docker run --rm -v "$OUTPUT_DIR":/data "$ROSBAGS_IMAGE" \
            --src "/data/$BASENAME.bag-pc.bag" --dst "/data/${BASENAME}-ros2"
        CURRENT_OUTPUT=""
    fi
    echo "  -> $OUTPUT_DIR/${BASENAME}-ros2/"
    echo ""
fi

# --- Step 3: --livox-ros2 (special conversion via mandeye_to_bag) ---
if $DO_LIVOX_ROS2; then
    echo "[--livox-ros2] Converting Livox CustomMsg ROS1 -> ROS2 (mandeye_to_bag)..."
    if [ -d "$OUTPUT_DIR/${BASENAME}-ros2-lidar" ]; then
        echo "  Already exists, skipping."
    else
        if ! docker image inspect mandeye-ws_noetic &> /dev/null; then
            echo "  Building Docker image mandeye-ws_noetic..."
            docker build -t mandeye-ws_noetic --target ros1 "$SCRIPT_DIR/mandeye_to_bag"
        fi
        if ! docker image inspect mandeye-ws_humble &> /dev/null; then
            echo "  Building Docker image mandeye-ws_humble..."
            docker build -t mandeye-ws_humble --target ros2 "$SCRIPT_DIR/mandeye_to_bag"
        fi

        cd "$SCRIPT_DIR/mandeye_to_bag"
        chmod +x mandeye-convert.sh

        CURRENT_OUTPUT="$OUTPUT_DIR/${BASENAME}-ros2-lidar"

        echo "  Step 3a: ROS1 bag -> HDMapping..."
        if [ -d "$OUTPUT_DIR/${BASENAME}-convert" ]; then
            echo "    Already exists, skipping."
        else
            ./mandeye-convert.sh "$OUTPUT_DIR/$BASENAME.bag" "$OUTPUT_DIR/${BASENAME}-convert" ros1-to-hdmapping
        fi

        echo "  Step 3b: HDMapping -> ROS1 bag..."
        if [ -d "$OUTPUT_DIR/${BASENAME}-convert.bag" ]; then
            echo "    Already exists, skipping."
        else
            ./mandeye-convert.sh "$OUTPUT_DIR/${BASENAME}-convert" "$OUTPUT_DIR/${BASENAME}-convert.bag" hdmapping-to-ros1
        fi

        echo "  Step 3c: ROS1 -> ROS2..."
        # mandeye-convert outputs the bag without .bag extension — rename so rosbags-convert detects the format.
        BAG_FILE="$OUTPUT_DIR/${BASENAME}-convert.bag/${BASENAME}-convert"
        if [ -f "$BAG_FILE" ] && [ ! -f "${BAG_FILE}.bag" ]; then
            mv "$BAG_FILE" "${BAG_FILE}.bag"
        fi
        docker run --rm -v "$OUTPUT_DIR":/data "$ROSBAGS_IMAGE" \
            --src "/data/${BASENAME}-convert.bag/${BASENAME}-convert.bag" \
            --dst "/data/${BASENAME}-ros2-lidar"
        CURRENT_OUTPUT=""
    fi
    echo "  -> $OUTPUT_DIR/${BASENAME}-ros2-lidar/"
    echo ""
fi

# --- Summary ---
echo "============================================"
echo " Done. Generated files:"
echo "============================================"
echo ""
[ -f "$OUTPUT_DIR/$BASENAME.bag" ]             && echo "  $BASENAME.bag              (Livox CustomMsg, ROS1)"
[ -f "$OUTPUT_DIR/$BASENAME.bag-pc.bag" ]      && echo "  $BASENAME.bag-pc.bag       (PointCloud2, ROS1)"
[ -d "$OUTPUT_DIR/${BASENAME}-ros2" ]          && echo "  ${BASENAME}-ros2/          (PointCloud2, ROS2)"
[ -d "$OUTPUT_DIR/${BASENAME}-ros2-lidar" ]    && echo "  ${BASENAME}-ros2-lidar/    (Livox CustomMsg, ROS2)"
echo ""
echo "See README.md for which benchmarks use which format."
