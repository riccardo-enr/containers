# syntax=docker/dockerfile:1.7
#
# Example Dockerfile for a CONSUMER repo (GPU + CUDA compile + Gazebo).
#
# Builds on the prebuilt factory image ros2-desktop:jazzy-gpu-devel (run this
# repo's ./build.sh once). That base already provides: CUDA -devel base (nvcc +
# headers) with NVIDIA caps for OGRE2/EGL rendering, ROS 2 Jazzy desktop,
# colcon + rosdep (init & update), fzf, the `ros` user (uid 1000, NOPASSWD
# sudo, sourced rc files), and vanilla oh-my-zsh + zsh.
#
# So everything below is ONLY the project-specific layer on top -- it rebuilds
# in seconds; the heavy base is never rebuilt.

# Override to retarget, e.g. --build-arg BASE_IMAGE=ros2-desktop:jazzy-gpu
ARG BASE_IMAGE=ros2-desktop:jazzy-gpu-devel
FROM ${BASE_IMAGE}

# The oh-my-zsh fzf plugin sources its shell integration from here.
ENV FZF_BASE=/usr/share/doc/fzf/examples

# --- project ROS packages (Gazebo Harmonic via ros-gz) + dev tooling ------
# We run as the base image's `ros` user, so apt goes through its NOPASSWD sudo.
# ROS_DISTRO is inherited from the base image's ENV.
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-ros-gz \
        ros-${ROS_DISTRO}-pcl-ros \
        ros-${ROS_DISTRO}-topic-tools \
        python3-pip \
        just \
        clang-format \
    && sudo pip install --break-system-packages ruff \
    && sudo rm -rf /var/lib/apt/lists/*

# --- fzf zsh shell-integration scripts (missing from the Ubuntu package) ---
RUN FZF_VER="$(fzf --version | awk '{print $1}')" \
    && sudo curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/$FZF_VER/shell/key-bindings.zsh" \
        -o "$FZF_BASE/key-bindings.zsh" \
    && sudo curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/$FZF_VER/shell/completion.zsh" \
        -o "$FZF_BASE/completion.zsh"

# --- oh-my-zsh plugins + powerlevel10k theme (base has vanilla oh-my-zsh) --
RUN ZSH_CUSTOM="$HOME/.oh-my-zsh/custom" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k"
