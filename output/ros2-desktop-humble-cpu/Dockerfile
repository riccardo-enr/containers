# syntax=docker/dockerfile:1
#
# GENERATED FILE - do not edit by hand.
# Profile : ros2-desktop-humble-cpu
# Source  : config.yml + layers/*.j2
# Regenerate with: python generate.py ros2-desktop-humble-cpu --write
#
# ROS 2 humble desktop (cpu), fzf + oh-my-zsh.

FROM ros2-base:humble-cpu

ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble
ENV LANG=en_US.UTF-8

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
