###############################################
# BASE IMAGE
###############################################
FROM ubuntu:20.04

###############################################
# WORKING DIRECTORY
###############################################
RUN mkdir /app
WORKDIR /app

###############################################
# SYSTEM DEPENDENCIES
###############################################
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    python3-setuptools \
    python-is-python3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install Yarn
RUN npm install -g yarn

# CRITICAL: Verify pip is available after Python installation (needed for parsing.py dependencies)
RUN python -m pip --version && echo "✓ pip is available" || (echo "✗ pip not found" && exit 1)

###############################################
# REPO SETUP
###############################################
RUN git clone https://github.com/dpaia/webclients.git .
RUN git checkout 7366a9584597e6c06b10dee477e043cded019649

###############################################
# ENTRYPOINT / CMD
###############################################

# Write preprocess and build scripts
ENV PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
ENV UV_HTTP_TIMEOUT=60

RUN cat <<'EOFPREP' > /preprocess.sh
#!/bin/bash

cd /app

git reset --hard 9b35b414f77c6165550550fdda8b25bbc74aac7b
git clean -fdx
git checkout 9b35b414f77c6165550550fdda8b25bbc74aac7b

cd /

EOFPREP
RUN chmod +x /preprocess.sh
RUN /preprocess.sh

RUN cat <<'EOFBUILD' > /build.sh
##!/bin/sh
pip install setuptools || true
sleep 3
pip install pytest-rerunfailures
export PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"

cd /app
set -e

python -m pip --version && echo "✓ pip is available" || (echo "✗ pip not found" && exit 1)

yarn install --no-frozen-lockfile

export NODE_OPTIONS="--max-old-space-size=4096"

echo "================= 0909 BUILD START 0909 ================="
yarn workspaces foreach -A run postinstall || true
echo "================= 0909 BUILD END 0909 ================="

EOFBUILD
RUN chmod +x /build.sh
RUN /build.sh

LABEL ee-bench.type="codegen"
LABEL ee-bench.version="1.0"
RUN rm -rf /app/.ee-bench/ 2>/dev/null || true
