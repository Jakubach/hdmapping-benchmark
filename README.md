# HDMapping Benchmark Test Suite

Reproducible testing of LiDAR odometry/SLAM algorithms integrated with [HDMapping](https://github.com/MapsHD/HDMapping).

## Prerequisites

```bash
# Docker
sudo apt install -y docker.io
sudo usermod -aG docker $USER

# rosbags (for --ros2 and --resple flags)
pip install rosbags

# Clone conversion tools
git clone https://github.com/MapsHD/livox_bag_aggregate.git --recursive
git clone https://github.com/MapsHD/mandeye_to_bag.git --recursive

# Build conversion Docker images
cd livox_bag_aggregate && docker build -t livox_bag_aggregate_noetic . && cd ..
cd mandeye_to_bag && docker build -t mandeye-ws_noetic --target ros1 . && cd ..
cd mandeye_to_bag && docker build -t mandeye-ws_humble --target ros2 . && cd ..
```

## Quick Start

```bash
# 1. Create workspace and download test data
mkdir -p ~/hdmapping-benchmark/{data,benchmarks,outputs}
wget -O ~/hdmapping-benchmark/data/reg-1.bag "https://cloud.cylab.be/public.php/dav/files/7PgyjbM2CBcakN5/reg-1.bag"

# 2. Prepare all data formats
./prepare_benchmark_data.sh --all data/reg-1.bag

# 3. Clone a benchmark
cd ~/hdmapping-benchmark/benchmarks
git clone https://github.com/MapsHD/benchmark-FAST-LIO-to-HDMapping.git --recursive

# 4. Run it
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-FAST-LIO-to-HDMapping data/reg-1.bag
# Results in outputs/
```

## Preparing Data

```bash
./prepare_benchmark_data.sh [--ros1] [--ros2] [--resple] [--all] <input.bag> [output_dir]
```

| Argument | Description |
|----------|-------------|
| `<input.bag>` | Path to Livox CustomMsg ROS1 bag |
| `[output_dir]` | Output directory (default: same as input bag) |
| `--ros1` | Generate PointCloud2 ROS1 bag (via livox_bag_aggregate Docker) |
| `--ros2` | Generate PointCloud2 ROS2 bag (via rosbags-convert, requires `--ros1`) |
| `--resple` | Generate RESPLE-specific ROS2 (via mandeye_to_bag Docker + rosbags-convert) |
| `--all` | All of the above |

## Data Formats

The input dataset (`reg-1.bag`) uses Livox `CustomMsg`. Different algorithms expect different formats:

| Format | File | Flag | Conversion Tool |
|--------|------|------|-----------------|
| Livox CustomMsg (ROS1) | `reg-1.bag` | *(original)* | none |
| PointCloud2 (ROS1) | `reg-1.bag-pc.bag` | `--ros1` | [livox_bag_aggregate](https://github.com/MapsHD/livox_bag_aggregate) Docker |
| PointCloud2 (ROS2) | `reg-1-ros2/` | `--ros2` | [rosbags](https://pypi.org/project/rosbags/) (`pip install rosbags`) |
| RESPLE-specific (ROS2) | `reg-1-ros2-lidar/` | `--resple` | [mandeye_to_bag](https://github.com/MapsHD/mandeye_to_bag) Docker |

## Benchmark Input Data Requirements

| # | Algorithm | Year | Venue | ROS | Input Format | Input File | Flag | Movie |
|---|-----------|------|-------|-----|--------------|------------|------|-------|
| 1 | [FAST-LIO](https://github.com/MapsHD/benchmark-FAST-LIO-to-HDMapping) | 2020 | arXiv | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/ENlaQTtOXEM) |
| 2 | [Faster-LIO](https://github.com/MapsHD/benchmark-Faster-LIO-to-HDMapping) | 2022 | RA-L | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/bV1jgF_m-Zo) |
| 3 | [VoxelMap](https://github.com/MapsHD/benchmark-VoxelMap-to-HDMapping) | 2022 | arXiv | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/oRiuvJRNl-c) |
| 4 | [Point-LIO](https://github.com/MapsHD/benchmark-Point-LIO-to-HDMapping) | 2024 | JAIS | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/JlD1hDJHcrs) |
| 5 | [iG-LIO](https://github.com/MapsHD/benchmark-iG-LIO-to-HDMapping) | 2024 | RA-L | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/KlZf7nHeVmI) |
| 6 | [I2EKF-LO](https://github.com/MapsHD/benchmark-I2EKF-LO-to-HDMapping) | 2024 | arXiv | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/B2358Gn62Ho) |
| 7 | [SLICT](https://github.com/MapsHD/benchmark-SLICT-to-HDMapping) | 2023 | RA-L | 1 | Livox CustomMsg | `data/reg-1.bag` | *(none)* | [link](https://youtu.be/TUaJN7FJOFU) |
| 8 | [CT-ICP](https://github.com/MapsHD/benchmark-CT-ICP-to-HDMapping) | 2021 | arXiv | 1 | PointCloud2 ROS1 | `data/reg-1.bag-pc.bag` | `--ros1` | [link](https://youtu.be/swEsJHwtE50) |
| 9 | [DLO](https://github.com/MapsHD/benchmark-DLO-to-HDMapping) | 2022 | RA-L | 1 | PointCloud2 ROS1 | `data/reg-1.bag-pc.bag` | `--ros1` | [link](https://youtu.be/-UH81mNLw8Q) |
| 10 | [DLIO](https://github.com/MapsHD/benchmark-DLIO-to-HDMapping) | 2023 | ICRA | 1 | PointCloud2 ROS1 | `data/reg-1.bag-pc.bag` | `--ros1` | [link](https://youtu.be/xFLqFcoAtk8) |
| 11 | [LIO-EKF](https://github.com/MapsHD/benchmark-LIO-EKF-to-HDMapping) | 2024 | ICRA | 1 | PointCloud2 ROS1 | `data/reg-1.bag-pc.bag` | `--ros1` | [link](https://youtu.be/R4Cn1LJ4U_E) |
| 12 | [LOAM-Livox](https://github.com/MapsHD/benchmark-LOAM-Livox-to-HDMapping) | 2019 | arXiv | 1 | PointCloud2 ROS1 | `data/reg-1.bag-pc.bag` | `--ros1` | [link](https://youtu.be/MbKHTmUcI2w) |
| 13 | [LeGO-LOAM](https://github.com/MapsHD/benchmark-LeGO-LOAM-to-HDMapping) | 2018 | IROS | 1 | PointCloud2 ROS1 | `data/reg-1.bag-pc.bag` | `--ros1` | [link](https://youtu.be/WpFBXe1zKto) |
| 14 | [KISS-ICP](https://github.com/MapsHD/benchmark-KISS-ICP-to-HDMapping) | 2023 | RA-L | 2 | PointCloud2 ROS2 | `data/reg-1-ros2` | `--ros1 --ros2` | [link](https://youtu.be/GyB8UuQN0Io) |
| 15 | [GenZ-ICP](https://github.com/MapsHD/benchmark-GenZ-ICP-to-HDMapping) | 2025 | RA-L | 2 | PointCloud2 ROS2 | `data/reg-1-ros2` | `--ros1 --ros2` | [link](https://youtu.be/vgGkucOBVg4) |
| 16 | [GLIM](https://github.com/MapsHD/benchmark-GLIM-to-HDMapping) | 2024 | arXiv | 2 | PointCloud2 ROS2 | `data/reg-1-ros2` | `--ros1 --ros2` | [link](https://youtu.be/zyZDJECqOG0) |
| 17 | [RESPLE](https://github.com/MapsHD/benchmark-RESPLE-to-HDMapping) | 2025 | RA-L | 2 | RESPLE-specific ROS2 | `data/reg-1-ros2-lidar` | `--resple` | [link](https://youtu.be/5PAB4xJmMoo) |

## Recommended Execution Order

Running all 17 benchmarks takes time due to Docker builds. To maximize Docker layer cache reuse,
group benchmarks by base image and run them in this order:

**Group 1 — ROS1 Noetic, Livox CustomMsg** (no data conversion needed):

```bash
./run_benchmark.sh benchmarks/benchmark-FAST-LIO-to-HDMapping     data/reg-1.bag
./run_benchmark.sh benchmarks/benchmark-Faster-LIO-to-HDMapping    data/reg-1.bag
./run_benchmark.sh benchmarks/benchmark-VoxelMap-to-HDMapping      data/reg-1.bag
./run_benchmark.sh benchmarks/benchmark-Point-LIO-to-HDMapping     data/reg-1.bag
./run_benchmark.sh benchmarks/benchmark-iG-LIO-to-HDMapping        data/reg-1.bag
./run_benchmark.sh benchmarks/benchmark-I2EKF-LO-to-HDMapping      data/reg-1.bag
./run_benchmark.sh benchmarks/benchmark-SLICT-to-HDMapping          data/reg-1.bag
```

**Group 2 — ROS1 Noetic, PointCloud2** (requires `--ros1`):

```bash
./run_benchmark.sh benchmarks/benchmark-CT-ICP-to-HDMapping        data/reg-1.bag-pc.bag
./run_benchmark.sh benchmarks/benchmark-DLO-to-HDMapping            data/reg-1.bag-pc.bag
./run_benchmark.sh benchmarks/benchmark-DLIO-to-HDMapping           data/reg-1.bag-pc.bag
./run_benchmark.sh benchmarks/benchmark-LIO-EKF-to-HDMapping       data/reg-1.bag-pc.bag
./run_benchmark.sh benchmarks/benchmark-LOAM-Livox-to-HDMapping    data/reg-1.bag-pc.bag
./run_benchmark.sh benchmarks/benchmark-LeGO-LOAM-to-HDMapping     data/reg-1.bag-pc.bag
```

**Group 3 — ROS2 Humble, PointCloud2** (requires `--ros1 --ros2`):

```bash
./run_benchmark.sh benchmarks/benchmark-KISS-ICP-to-HDMapping      data/reg-1-ros2
./run_benchmark.sh benchmarks/benchmark-GenZ-ICP-to-HDMapping       data/reg-1-ros2
./run_benchmark.sh benchmarks/benchmark-GLIM-to-HDMapping           data/reg-1-ros2
```

**Group 4 — ROS2 Humble, RESPLE-specific** (requires `--resple`):

```bash
./run_benchmark.sh benchmarks/benchmark-RESPLE-to-HDMapping         data/reg-1-ros2-lidar
```

> **Tip:** Within each group the Noetic/Humble base layers are cached, so only the
> algorithm-specific layers need to be built. Switching between groups invalidates
> the base image cache.

## Running a Benchmark

Each benchmark uses the `Bunker-DVI-Dataset-reg-1` branch with Docker-based workflow.

```bash
./run_benchmark.sh <benchmark_dir> <input> [output_dir]
```

| Argument | Description |
|----------|-------------|
| `<benchmark_dir>` | Path to a `benchmark-*-to-HDMapping` repo |
| `<input>` | Input bag file or directory (see table above) |
| `[output_dir]` | Output directory for results (default: `outputs/`) |

### Per-Benchmark Commands

<details>
<summary>1. FAST-LIO</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-FAST-LIO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-FAST-LIO-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>2. Faster-LIO</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-Faster-LIO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-Faster-LIO-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>3. VoxelMap</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-VoxelMap-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-VoxelMap-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>4. Point-LIO</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-Point-LIO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-Point-LIO-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>5. iG-LIO</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-iG-LIO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-iG-LIO-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>6. I2EKF-LO</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-I2EKF-LO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-I2EKF-LO-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>7. SLICT</summary>

```bash
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-SLICT-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-SLICT-to-HDMapping data/reg-1.bag
```
</details>

<details>
<summary>8. CT-ICP</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-CT-ICP-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-CT-ICP-to-HDMapping data/reg-1.bag-pc.bag
```
</details>

<details>
<summary>9. DLO</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-DLO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-DLO-to-HDMapping data/reg-1.bag-pc.bag
```
</details>

<details>
<summary>10. DLIO</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-DLIO-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-DLIO-to-HDMapping data/reg-1.bag-pc.bag
```
</details>

<details>
<summary>11. LIO-EKF</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-LIO-EKF-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-LIO-EKF-to-HDMapping data/reg-1.bag-pc.bag
```
</details>

<details>
<summary>12. LOAM-Livox</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-LOAM-Livox-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-LOAM-Livox-to-HDMapping data/reg-1.bag-pc.bag
```
</details>

<details>
<summary>13. LeGO-LOAM</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-LeGO-LOAM-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-LeGO-LOAM-to-HDMapping data/reg-1.bag-pc.bag
```
</details>

<details>
<summary>14. KISS-ICP</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 --ros2 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-KISS-ICP-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-KISS-ICP-to-HDMapping data/reg-1-ros2
```
</details>

<details>
<summary>15. GenZ-ICP</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 --ros2 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-GenZ-ICP-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-GenZ-ICP-to-HDMapping data/reg-1-ros2
```
</details>

<details>
<summary>16. GLIM</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --ros1 --ros2 data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-GLIM-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-GLIM-to-HDMapping data/reg-1-ros2
```
</details>

<details>
<summary>17. RESPLE</summary>

```bash
# Requires: ./prepare_benchmark_data.sh --resple data/reg-1.bag
cd ~/hdmapping-benchmark/benchmarks && git clone https://github.com/MapsHD/benchmark-RESPLE-to-HDMapping.git --recursive
cd ~/hdmapping-benchmark
./run_benchmark.sh benchmarks/benchmark-RESPLE-to-HDMapping data/reg-1-ros2-lidar
```
</details>

### Expected Output

Each benchmark produces a folder `output_hdmapping-XXXX/` containing:
- `session.json`
- `poses.reg`
- `lio_initial_poses.reg`
- `scan_lio_*.laz`
- `trajectory_lio_*.csv`

Open with [HDMapping](https://github.com/MapsHD/HDMapping) `multi_view_tls_registration_step_2`.

## Directory Structure

```
hdmapping-benchmark/
├── prepare_benchmark_data.sh    # Data preparation script
├── run_benchmark.sh             # Run a single benchmark
├── README.md                    # This file
├── livox_bag_aggregate/         # Livox CustomMsg -> PointCloud2 converter
├── mandeye_to_bag/              # HDMapping <-> ROS bag converter
├── data/                        # Prepared input data
│   ├── reg-1.bag                # Original Livox CustomMsg (ROS1)
│   ├── reg-1.bag-pc.bag         # PointCloud2 (ROS1)        [--ros1]
│   ├── reg-1-ros2/              # PointCloud2 (ROS2)        [--ros2]
│   └── reg-1-ros2-lidar/        # RESPLE-specific (ROS2)    [--resple]
├── benchmarks/                  # Cloned benchmark repos
│   ├── benchmark-FAST-LIO-to-HDMapping/
│   ├── benchmark-KISS-ICP-to-HDMapping/
│   └── ...
└── outputs/                     # Benchmark results
    ├── output_hdmapping-FAST-LIO/
    ├── output_hdmapping-kiss/
    └── ...
```
