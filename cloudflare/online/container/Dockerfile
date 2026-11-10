FROM --platform=linux/amd64 debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 libgcc-s1 ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --create-home game
WORKDIR /home/game
COPY --chown=game:game --chmod=755 phreaknic-server.x86_64 ./phreaknic-server.x86_64
USER game
EXPOSE 8080
CMD ["./phreaknic-server.x86_64", "--headless", "--", "--server", "--port", "8080"]
