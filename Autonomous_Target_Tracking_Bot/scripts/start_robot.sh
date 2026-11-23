#!/usr/bin/env bash

set -e

# ---------------------------------------
# 1. Define project paths
# ---------------------------------------

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="$PROJECT_DIR/ros_ws"

# ---------------------------------------
# 2. Source ROS 2 environment
# ---------------------------------------

source /opt/ros/jazzy/setup.bash
source "$WORKSPACE_DIR/install/setup.bash"

echo "ROS 2 environment sourced."

# ---------------------------------------
# 3. Process IDs and cleanup
# ---------------------------------------

CAMERA_PID=""
LIDAR_PID=""
LAUNCH_PID=""

cleanup() {
    echo ""
    echo "Shutting down AGV processes..."

    for pid in "$LAUNCH_PID" "$LIDAR_PID" "$CAMERA_PID"; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -INT "$pid" 2>/dev/null || true
        fi
    done

    for pid in "$LAUNCH_PID" "$LIDAR_PID" "$CAMERA_PID"; do
        if [[ -n "$pid" ]]; then
            wait "$pid" 2>/dev/null || true
        fi
    done

    echo "All processes stopped."
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------------------------------------
# 4. Start camera driver
# ---------------------------------------

echo "Starting USB camera..."

ros2 run v4l2_camera v4l2_camera_node --ros-args \
    -r /image_raw:=/AGV/camera/img \
    -r /camera_info:=/AGV/camera/camera_info \
    -p video_device:=/dev/video0 \
    -p image_size:="[1280,720]" &

CAMERA_PID=$!

sleep 2

# ---------------------------------------
# 5. Start LiDAR driver
# ---------------------------------------

echo "Starting YDLIDAR TG15..."

ros2 launch ydlidar_ros2_driver ydlidar_launch.py \
    --ros-args \
    -r /scan:=/AGV/lidar/scan &

LIDAR_PID=$!

sleep 2

# ---------------------------------------
# 6. Wait for sensor data
# ---------------------------------------

echo "Waiting for camera and LiDAR data..."

wait_for_topic() {
    local topic="$1"
    local max_wait="$2"
    local start_time=$SECONDS

    until timeout 2s ros2 topic echo "$topic" --once >/dev/null 2>&1; do

        if (( SECONDS - start_time >= max_wait )); then
            echo "ERROR: Timeout waiting for $topic"
            return 1
        fi

        sleep 1
    done

    echo "$topic is publishing."
}

wait_for_topic /AGV/camera/img 10
wait_for_topic /AGV/lidar/scan 15

# ---------------------------------------
# 7. Start main AGV launch file
# ---------------------------------------

echo "Starting AGV software..."

ros2 launch "$WORKSPACE_DIR/launch/simulation.launch.py" &

LAUNCH_PID=$!

wait "$LAUNCH_PID"
