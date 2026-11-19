FROM ubuntu:24.04
ARG GODOT_VERSION=4.5.1
ARG UBUNTU_ARCHIVE
ENV DEBIAN_FRONTEND=noninteractive PORT=8080
# CI supplies the runner's CA bundle so APT can use HTTPS before ca-certificates is installed.
RUN --mount=type=secret,id=ubuntu_archive_ca,mode=0444 \
    set -eu; \
    set -- -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30; \
    if [ -n "${UBUNTU_ARCHIVE}" ]; then \
        test -s /run/secrets/ubuntu_archive_ca; \
        sed -i "s|^URIs: http://archive\.ubuntu\.com/ubuntu/*$|URIs: ${UBUNTU_ARCHIVE}|; s|^URIs: http://security\.ubuntu\.com/ubuntu/*$|URIs: ${UBUNTU_ARCHIVE}|" \
            /etc/apt/sources.list.d/ubuntu.sources; \
        set -- "$@" -o Acquire::https::CaInfo=/run/secrets/ubuntu_archive_ca; \
    fi; \
    apt-get "$@" -o APT::Update::Error-Mode=any update; \
    apt-get "$@" install -y --no-install-recommends ca-certificates curl unzip \
        libfontconfig1 libx11-6 libxrandr2 libxcursor1 libxi6 libasound2t64 libudev1 libgl1 python3; \
    rm -rf /var/lib/apt/lists/*
RUN curl --fail --location --retry 3 --output /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip
# Fail the Docker build if an overly minimal Python image drops stdlib modules.
RUN python3 -c "import asyncio, socket, signal, json; print('EDGE_RUNTIME_STD_LIB_OK')"
WORKDIR /game
COPY . /game
RUN mkdir -p /home/server/.local/share /home/server/.config /home/server/.cache && \
    godot --headless --editor --path /game --quit >/tmp/import.log 2>&1 || (cat /tmp/import.log && exit 1)
EXPOSE 8080
CMD ["python3", "-u", "/game/server/edge_gateway.py"]
