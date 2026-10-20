FROM ubuntu:24.04
ARG GODOT_VERSION=4.5.1
ENV DEBIAN_FRONTEND=noninteractive PORT=8080
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libx11-6 libxrandr2 libxcursor1 libxi6 libasound2t64 libudev1 libgl1 && rm -rf /var/lib/apt/lists/*
RUN curl --fail --location --retry 3 --output /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip
WORKDIR /game
COPY . /game
RUN mkdir -p /home/server/.local/share /home/server/.config /home/server/.cache && \
    godot --headless --editor --path /game --quit >/tmp/import.log 2>&1 || (cat /tmp/import.log && exit 1)
EXPOSE 8080
CMD ["godot", "--headless", "--path", "/game", "--script", "res://server/dedicated.gd"]
