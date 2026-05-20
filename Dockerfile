# Reproducible ceremony environment. Pins snarkjs 0.7.6 on Node 22.
# Contributors only run snarkjs; the circuits are pre-compiled
# (circuits/*.r1cs), so circom is not needed here.

FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        gpg \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g snarkjs@0.7.6 --quiet

WORKDIR /work

CMD ["bash"]
