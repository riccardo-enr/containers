# syntax=docker/dockerfile:1
#
# Example Dockerfile for a CONSUMER repo.
#
# It uses a LOCAL image built by this repo's ./build.sh as its base layer, then
# adds only project-specific things on top. The expensive base (ROS 2, CUDA,
# oh-my-zsh) is never rebuilt; only this thin layer rebuilds when your project
# deps change.
#
# Copy into the other repo (e.g. .devcontainer/Dockerfile) and build via the
# accompanying devcontainer.json.

# Pick the base by overriding BASE_IMAGE at build time, e.g.
#   docker build --build-arg BASE_IMAGE=ros2-desktop:jazzy-gpu .
ARG BASE_IMAGE=ros2-desktop:humble-cpu
FROM ${BASE_IMAGE}

# --- project-specific apt packages ---------------------------------------
# Runs as the `ros` user from the base image, so use its NOPASSWD sudo.
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-nav2-bringup \
        ros-${ROS_DISTRO}-tf-transformations \
    && sudo rm -rf /var/lib/apt/lists/*

# --- project Python deps --------------------------------------------------
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# --- (optional) pre-build the colcon workspace ----------------------------
# Leave this out if you'd rather build inside the running devcontainer.
# WORKDIR /workspace
# COPY . /workspace
# RUN . /opt/ros/${ROS_DISTRO}/setup.sh && colcon build --symlink-install
