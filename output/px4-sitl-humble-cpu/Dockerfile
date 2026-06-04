# syntax=docker/dockerfile:1
#
# GENERATED FILE - do not edit by hand.
# Profile : px4-sitl-humble-cpu
# Source  : config.yml + layers/*.j2
# Regenerate with: python generate.py px4-sitl-humble-cpu --write
#
# ROS 2 humble + PX4 SITL toolchain + MAVSDK (cpu).

FROM ros2-base:humble-cpu

ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble
ENV LANG=en_US.UTF-8

# --- px4-deps: PX4 SITL toolchain and build dependencies ------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        astyle \
        build-essential \
        cmake \
        ninja-build \
        ccache \
        gdb \
        python3-pip \
        python3-dev \
        python3-empy \
        python3-jinja2 \
        python3-numpy \
        python3-toml \
        python3-yaml \
        libxml2-dev \
        libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

# --- px4-source: clone and bootstrap PX4-Autopilot firmware ---------------
RUN git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/PX4/PX4-Autopilot.git /opt/px4 \
    && cd /opt/px4 \
    && bash Tools/setup/ubuntu.sh --no-nuttx \
    && rm -rf /var/lib/apt/lists/*

# --- mavsdk-python: MAVSDK Python bindings --------------------------------
# Noble (24.04) ships pip with PEP 668 "externally managed" enforcement, so
# system installs need --break-system-packages. Jammy's (22.04) older pip
# neither has that flag nor needs it.
RUN pip3 install --no-cache-dir \
        mavsdk \
        aioconsole \
        pymavlink

# --- gz-sim: Gazebo simulator for PX4 SITL (GPU-only) ---------------------
# Gazebo is heavy and only pays off where the GPU can accelerate rendering and
# sensor simulation, so it ships only in GPU images. ros-<distro>-ros-gz pulls
# the Gazebo release paired with the ROS 2 distro (Harmonic on Jazzy, Fortress
# on Humble) together with the ros_gz bridge packages.
# (skipped: gz-sim is GPU-only; this is a cpu image)

# --- ros-user: create a non-root user with the workspace pre-sourced ------
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

RUN if getent group ${USER_GID} > /dev/null 2>&1; then \
        groupmod --new-name ${USERNAME} $(getent group ${USER_GID} | cut -d: -f1); \
    else \
        groupadd --gid ${USER_GID} ${USERNAME}; \
    fi \
    && if getent passwd ${USER_UID} > /dev/null 2>&1; then \
        usermod --login ${USERNAME} --home /home/${USERNAME} -m -g ${USER_GID} -s /bin/bash $(getent passwd ${USER_UID} | cut -d: -f1); \
    else \
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}; \
    fi \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && echo "source /opt/ros/humble/setup.bash" >> /home/${USERNAME}/.bashrc

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# --- omz-shell: zsh + oh-my-zsh for ros -------------------------
# Runs after the USER switch, so apt goes through the user's NOPASSWD sudo.
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        zsh \
    && sudo rm -rf /var/lib/apt/lists/* \
    && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended \
    && echo "source /opt/ros/humble/setup.zsh" >> /home/ros/.zshrc

ENV SHELL=/usr/bin/zsh
