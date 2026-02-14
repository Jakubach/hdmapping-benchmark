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

## 1. libcurl conflict in mandeye_to_bag Dockerfile

**Files:**
- `mandeye_to_bag/Dockerfile` (ros1 stage)
- `benchmark-CT-ICP-to-HDMapping/Dockerfile`
- `benchmark-DLIO-to-HDMapping/Dockerfile`
- `benchmark-DLO-to-HDMapping/Dockerfile`
- `benchmark-FAST-LIO-to-HDMapping/Dockerfile`
- `benchmark-Faster-LIO-to-HDMapping/Dockerfile`
- `benchmark-VoxelMap-to-HDMapping/Dockerfile`

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
