FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa \
    clang cmake ninja-build pkg-config libgtk-3-dev

USER vscode
WORKDIR /home/vscode

RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 \
    && echo 'export PATH="$PATH:/home/vscode/flutter/bin"' >> ~/.bashrc

ENV PATH="${PATH}:/home/vscode/flutter/bin"
RUN flutter precache --web \
    && flutter config --enable-web \
    && flutter config --no-analytics \
    && yes | flutter doctor --android-licenses 2>/dev/null || true

USER root
