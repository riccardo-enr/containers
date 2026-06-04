# syntax=docker/dockerfile:1
#
# GENERATED FILE - do not edit by hand.
# Profile : px4-sitl-jazzy-cpu
# Source  : config.yml + layers/*.j2
# Regenerate with: python generate.py px4-sitl-jazzy-cpu --write
#
# ROS 2 jazzy + PX4 SITL toolchain + MAVSDK (cpu).

FROM ros2-base:jazzy-cpu

ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy
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

# --- px4-source: clone PX4 firmware + the uXRCE-DDS agent -----------------
# Clones PX4-Autopilot and runs its setup script (deps only; px4_sitl itself
# compiles on first `make px4_sitl <model>`). Then builds the Micro-XRCE-DDS
# Agent -- the bridge PX4 uses to talk to ROS 2 over uXRCE-DDS. The agent is
# packaged here rather than in its own layer because it is useless without the
# PX4 firmware it bridges. Pinned to v2.4.3 for a reproducible build; its cmake
# superbuild fetches and builds Fast-DDS, so build-essential + cmake (px4-deps)
# are the only host prerequisites.
RUN git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/PX4/PX4-Autopilot.git /opt/px4 \
    && cd /opt/px4 \
    && bash Tools/setup/ubuntu.sh --no-nuttx \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v2.4.3 \
        https://github.com/eProsima/Micro-XRCE-DDS-Agent.git /tmp/xrce-agent \
    && cmake -S /tmp/xrce-agent -B /tmp/xrce-agent/build \
        -DUAGENT_BUILD_EXECUTABLE=ON \
    && cmake --build /tmp/xrce-agent/build --target install -j "$(nproc)" \
    && ldconfig /usr/local/lib/ \
    && rm -rf /tmp/xrce-agent

# --- mavsdk-python: MAVSDK Python bindings --------------------------------
# Noble (24.04) ships pip with PEP 668 "externally managed" enforcement, so
# system installs need --break-system-packages. Jammy's (22.04) older pip
# neither has that flag nor needs it.
RUN pip3 install --no-cache-dir --break-system-packages \
        mavsdk \
        aioconsole \
        pymavlink

# --- gz-sim: Gazebo simulator for PX4 SITL --------------------------------
# Installed on every hardware. On GPU the host driver accelerates rendering and
# sensor simulation; on CPU it falls back to Mesa's llvmpipe software renderer
# (export LIBGL_ALWAYS_SOFTWARE=1 at runtime) -- slower, but enough to run
# headless SITL without a GPU. ros-<distro>-ros-gz pulls the Gazebo release
# paired with the ROS 2 distro (Harmonic on Jazzy, Fortress on Humble) together
# with the ros_gz bridge packages; libgl1-mesa-dri provides the llvmpipe driver.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-jazzy-ros-gz \
        libgl1-mesa-dri \
    && rm -rf /var/lib/apt/lists/*

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
