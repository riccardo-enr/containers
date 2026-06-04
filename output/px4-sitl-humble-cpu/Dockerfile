# syntax=docker/dockerfile:1
#
# GENERATED FILE - do not edit by hand.
# Profile : px4-sitl-humble-cpu
# Source  : config.yml + layers/*.j2
# Regenerate with: python generate.py px4-sitl-humble-cpu --write
#
# ROS 2 humble + PX4 SITL toolchain + MAVSDK (cpu).

FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble
ENV LANG=en_US.UTF-8

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
http://packages.ros.org/ros2/ubuntu jammy main" \
        > /etc/apt/sources.list.d/ros2.list

# --- ros2-desktop: install ROS 2 humble desktop + build tools ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-humble-desktop \
        ros-dev-tools \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# --- rosdep-init: initialise and update rosdep ----------------------------
RUN rosdep init && rosdep update --rosdistro humble

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

# --- mavsdk-python: MAVSDK Python bindings --------------------------------
# Noble (24.04) ships pip with PEP 668 "externally managed" enforcement, so
# system installs need --break-system-packages. Jammy's (22.04) older pip
# neither has that flag nor needs it.
RUN pip3 install --no-cache-dir \
        mavsdk \
        aioconsole \
        pymavlink

# --- ros-user: create a non-root user with the workspace pre-sourced ------
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
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
