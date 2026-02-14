# Pipeline test report

## Test platform

| Component          | Value                                          |
|--------------------|------------------------------------------------|
| OS                 | Ubuntu 24.04.4 LTS                             |
| Kernel             | 6.8.0-100-generic                              |
| CPU                | Intel Core i7-10870H @ 2.20GHz (16 threads)    |
| RAM                | 32 GB                                          |
| Docker             | 28.3.3                                         |
| Python             | 3.12.3                                         |
| rosbags            | 0.11.0                                         |
| Storage            | External USB HDD 2TB (NTFS, mounted as ntfs3)  |
| Mount point        | `/media/jakub/Elements SE/hdmapping-benchmark/` |

---

## 1. libcurl conflict caused by libpcl-dev placement

**Files (all 18 benchmark Dockerfiles + mandeye_to_bag):**
- `mandeye_to_bag/Dockerfile` (ros1 stage)
- `benchmark-CT-ICP-to-HDMapping/Dockerfile`
- `benchmark-DLIO-to-HDMapping/Dockerfile`
- `benchmark-DLO-to-HDMapping/Dockerfile`
- `benchmark-FAST-LIO-to-HDMapping/Dockerfile`
- `benchmark-Faster-LIO-to-HDMapping/Dockerfile`
- `benchmark-VoxelMap-to-HDMapping/Dockerfile`
- `benchmark-I2EKF-LO-to-HDMapping/Dockerfile`
- `benchmark-iG-LIO-to-HDMapping/Dockerfile`
- `benchmark-Point-LIO-to-HDMapping/Dockerfile`
- `benchmark-SLICT-to-HDMapping/Dockerfile`
- `benchmark-LIO-EKF-to-HDMapping/Dockerfile`
- `benchmark-LOAM-Livox-to-HDMapping/Dockerfile`
- `benchmark-LeGO-LOAM-to-HDMapping/Dockerfile`
- `benchmark-GenZ-ICP-to-HDMapping/Dockerfile` (ROS 2)
- `benchmark-GLIM-to-HDMapping/Dockerfile` (ROS 2)
- `benchmark-KISS-ICP-to-HDMapping/Dockerfile` (ROS 2)
- `benchmark-RESPLE-to-HDMapping/Dockerfile` (ROS 2)
- `benchmark-lidar_odometry_ros_wrapper-to-HDMapping/Dockerfile` (ROS 2)

**Symptom:** Docker build fails at step 5/19 with:
```
dpkg: error processing package libcurl4-gnutls-dev:amd64 (--remove):
 cannot remove '/usr/share/doc/libcurl4-gnutls-dev': Invalid argument
```

**Root cause:** Two separate `RUN apt-get install` layers create a conflict.
Step 3 installs `libpcl-dev` which pulls in `libcurl4-gnutls-dev`.
Step 5 installs `ros-noetic-desktop-full` which needs `libcurl4-openssl-dev`.
dpkg tries to remove `libcurl4-gnutls-dev` across layers and fails.

**Fix:** Move `libpcl-dev` from the first `apt-get install` to the second (after ROS repo is added), so both packages are resolved in a single dpkg transaction.

```diff
 RUN apt-get update && apt-get install -y --no-install-recommends \
     curl gnupg2 lsb-release software-properties-common \
     build-essential git cmake \
     python3-pip \
     libceres-dev libeigen3-dev \
-    libpcl-dev \
     nlohmann-json3-dev \
     tmux \
     libusb-1.0-0-dev \
     && rm -rf /var/lib/apt/lists/*

 ...

 RUN apt-get update && apt-get install -y --no-install-recommends \
     ros-noetic-desktop-full \
     python3-rosdep \
     python3-catkin-tools \
+    libpcl-dev \
     && rm -rf /var/lib/apt/lists/*
```

---

## 2. Uninitialized git submodule + symlinks not followed by Docker COPY

**File:** `mandeye_to_bag/Dockerfile` (ros1 & ros2 stages)

**Symptom:** Docker build fails at step 17/19 (catkin_make) with:
```
CMake Error at mandeye_to_rosbag1/CMakeLists.txt:34 (add_subdirectory):
  The source directory /mandeye_ws/src/mandeye_to_rosbag1/common/3rd/LASzip
  does not contain a CMakeLists.txt file.
```

**Root cause:** Two separate issues combine:

1. `src/common/3rd/LASzip` is a git submodule that was not initialized — the directory is empty.
2. `src/mandeye_to_rosbag1/common` and `src/mandeye_to_rosbag2/common` are symlinks (`-> ../common`).
   Docker `COPY` does not follow symlinks (Docker 28.3+), so the `common/` directory inside
   each package is copied as a dangling symlink.

**Fix (two parts):**

a) Initialize the submodule:
```bash
cd mandeye_to_bag
git submodule update --init --recursive
```

b) Recreate the symlinks inside the container after COPY (using absolute container paths):
```diff
 COPY ./src/common ./src/common
 COPY ./src/mandeye_to_rosbag1 ./src/mandeye_to_rosbag1
+# mandeye_to_rosbag1/common is a symlink to ../common — recreate it in the container.
+RUN rm -rf ./src/mandeye_to_rosbag1/common && \
+    ln -s /mandeye_ws/src/common ./src/mandeye_to_rosbag1/common

 ...

 COPY ./src/common ./src/common
 COPY ./src/mandeye_to_rosbag2 ./src/mandeye_to_rosbag2
+RUN rm -rf ./src/mandeye_to_rosbag2/common && \
+    ln -s /mandeye_ws/src/common ./src/mandeye_to_rosbag2/common
```

Note: `cp -r` was tried first but fails with `Invalid argument` on Docker's overlay filesystem.
`ln -s` with absolute container paths works correctly.

---

## 3. `rm -rf` across Docker layers fails in CT-ICP Dockerfile

**File:** `benchmark-CT-ICP-to-HDMapping/Dockerfile`

**Symptom:** Docker build fails at step 18/26 with:
```
rm: cannot remove '/ros_ws/src/ct_icp/.cmake-build-superbuild/CMakeFiles/3.20.5': Directory not empty
rm: cannot remove '/ros_ws/src/ct_icp/.cmake-build-superbuild/MappingResearchKEU_superbuild/...': Directory not empty
```

**Root cause:** Step 12 builds the superbuild in `.cmake-build-superbuild/`.
Step 18 tries to `rm -rf` that directory and rebuild with `-DCMAKE_CXX_STANDARD=14`.
Docker's overlay filesystem cannot remove directories created in a previous layer —
`rm -rf` fails with "Directory not empty" even though the flag should handle it.

**Fix:** Build the C++14 variant in a separate directory instead of deleting and reusing the old one:

```diff
-RUN rm -rf /ros_ws/src/ct_icp/.cmake-build-superbuild && \
-    mkdir -p /ros_ws/src/ct_icp/.cmake-build-superbuild && \
-    cd /ros_ws/src/ct_icp/.cmake-build-superbuild && \
+RUN mkdir -p /ros_ws/src/ct_icp/.cmake-build-superbuild-cpp14 && \
+    cd /ros_ws/src/ct_icp/.cmake-build-superbuild-cpp14 && \
     cmake .. -DCMAKE_CXX_STANDARD=14 && \
     make  && make install
```

---

## 4. SLICT: `catkin clean` fails across Docker layers

**File:** `benchmark-SLICT-to-HDMapping/Dockerfile`

**Symptom:** Docker build fails at step 94 with:
```
[clean] Failed to clean profile `default`
OSError: [Errno 22] Invalid argument: 'atomic_configure'
```

**Root cause:** Same class of issue as CT-ICP (#3). Step 76–77 runs `catkin build` in `/ws_livox`, creating a build directory. Step 94–98 runs `catkin clean -y` which calls `shutil.rmtree` on `/ws_livox/build`. Docker's overlay filesystem cannot remove directories created in a previous layer — `rmtree` fails with "Invalid argument".

**Fix:** Remove `catkin clean -y` and use `--force-cmake` to reconfigure without deleting the old build:

```diff
 RUN source /opt/ros/noetic/setup.bash && \
     catkin init && \
     catkin config --extend /ws_livox2/devel && \
-    catkin clean -y && \
-    catkin build
+    catkin build --force-cmake
```

---

## 5. iG-LIO: rviz `required="true"` kills roslaunch in headless Docker

**Files:** `benchmark-iG-LIO-to-HDMapping/src/ig_lio/launch/lio_avia.launch` (and 5 other launch files)

**Symptom:** Container starts, rosbag play/record begin, but ig_lio_node never appears in `rosnode list`. The roslaunch panel shows:
```
REQUIRED process [rviz-3] has died!
process has died [pid 208, exit code -11, cmd /opt/ros/noetic/lib/rviz/rviz ...]
Initiating shutdown!
```
The controller panel hangs at `[control] waiting for play end` because rosbag play runs but no algorithm processes the data.

**Root cause:** The launch file starts rviz with `required="true"`. In a headless Docker container (no display/GPU), rviz crashes with SIGSEGV (exit code -11). Because it is marked as `required`, roslaunch kills **all** nodes — including `ig_lio_node`.

**Fix:** Change `required="true"` to `required="false"` on all rviz nodes, or comment them out entirely. A generic patch was added to `run_benchmark.sh` to do this automatically before `docker build`:
```bash
# --- Patch: disable rviz required="true" for headless Docker ---
find "$REPO_DIR" -name "*.launch" -exec \
    sed -i 's/\(pkg="rviz".*\)required="true"/\1required="false"/' {} + 2>/dev/null || true
```

**Affected launch files:**
- `lio_avia.launch`
- `lio_bg_avia.launch`
- `lio_bg_velodyne.launch`
- `lio_ncd.launch`
- `lio_nclt.launch`
- `lio_ulhk.launch`

---

## 6. iG-LIO: permission denied on result directory + hardcoded host path

**Files:**
- `benchmark-iG-LIO-to-HDMapping/Dockerfile`
- `benchmark-iG-LIO-to-HDMapping/docker_session_run-ros1-ig-lio.sh`

**Symptom:** After fixing the rviz issue, ig_lio_node starts but immediately exits with:
```
Could not create logging file: Permission denied
COULD NOT CREATE A LOGGINGFILE 20260214-175452.203!
E0214 17:54:52.827517   203 ig_lio_node.cpp:707] failed to open: "/ros_ws/src/ig_lio/result/lio_odom.txt"
[ig_lio_node-2] process has finished cleanly
```

**Root cause (three issues):**

1. **Dockerfile:** The workspace `/ros_ws` is created and built as `root`, then user `ros` (UID 1000) is created. The container runs as `-u 1000:1000` but `/ros_ws/src/ig_lio/result/` is owned by root — `ros` cannot write to it.

2. **Run script:** `RESULT_IG_LIO_HOST_PATH` is hardcoded to `/home/janusz/hdmapping-benchmark/...` — a path from another developer's machine that doesn't exist on the current host.

3. **Run script:** `mkdir -p "$RESULT_IG_LIO_PATH"` references an undefined variable (should be `$RESULT_IG_LIO_HOST_PATH`).

**Fix:**

a) Dockerfile — grant ownership to user `ros`:
```diff
 RUN groupadd -g $GID ros && \
     useradd -m -u $UID -g $GID -s /bin/bash ros
 WORKDIR /ros_ws
+
+RUN chown -R ros:ros /ros_ws
```

b) Run script — use relative path and fix variable name:
```diff
-RESULT_IG_LIO_HOST_PATH="/home/janusz/hdmapping-benchmark/benchmark-iG-LIO-to-HDMapping/src/ig_lio/result"
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+RESULT_IG_LIO_HOST_PATH="$SCRIPT_DIR/src/ig_lio/result"
```
```diff
-mkdir -p "$RESULT_IG_LIO_PATH"
+mkdir -p "$RESULT_IG_LIO_HOST_PATH"
```
