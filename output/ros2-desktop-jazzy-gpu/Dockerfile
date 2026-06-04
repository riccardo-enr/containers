# syntax=docker/dockerfile:1
#
# GENERATED FILE - do not edit by hand.
# Profile : ros2-desktop-jazzy-gpu
# Source  : config.yml + layers/*.j2
# Regenerate with: python generate.py ros2-desktop-jazzy-gpu --write
#
# ROS 2 jazzy desktop (gpu), fzf + oh-my-zsh.

FROM nvidia/cuda:12.6.3-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy
ENV LANG=en_US.UTF-8

# --- nvidia-env: expose the GPU to the container at runtime ---------------
# Picked up by the NVIDIA Container Toolkit (`docker run --gpus all`).
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# --- bootstrap: base packages, locale, common tooling ---------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg2 \
        locales \
        lsb-release \
        software-properties-common \
        sudo \
        wget \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# --- ros2-repo: add the ROS 2 apt repository ------------------------------
RUN add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu noble main" \
        > /etc/apt/sources.list.d/ros2.list

# --- ros2-desktop: install ROS 2 jazzy desktop + build tools ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-jazzy-desktop \
        ros-dev-tools \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# --- rosdep-init: initialise and update rosdep ----------------------------
RUN rosdep init && rosdep update --rosdistro jazzy

# --- fzf-shell: fuzzy finder for shell history/search ---------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        fzf \
        ripgrep \
        fd-find \
    && rm -rf /var/lib/apt/lists/*

# --- ros-user: create a non-root user with the workspace pre-sourced ------
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && echo "source /opt/ros/jazzy/setup.bash" >> /home/${USERNAME}/.bashrc

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# --- omz-shell: zsh + oh-my-zsh for ros -------------------------
# Runs after the USER switch, so apt goes through the user's NOPASSWD sudo.
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        zsh \
    && sudo rm -rf /var/lib/apt/lists/* \
    && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended \
    && echo "source /opt/ros/jazzy/setup.zsh" >> /home/ros/.zshrc

ENV SHELL=/usr/bin/zsh
