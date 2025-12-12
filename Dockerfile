FROM ubuntu:latest

ARG DEBIAN_FRONTEND=noninteractive

# Install base tools, Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    ca-certificates \
    python3 \
    python3-pip \
    python3-psutil \
    python3-distro \
    python3-z3 \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    libgmp-dev \
    libtinfo6 \
    libopenblas-dev \
 && rm -rf /var/lib/apt/lists/*

# RUN pip3 install z3-solver

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install OpenJDK and sbt (Scala build tool)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    apt-transport-https \
    ca-certificates \
    curl \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x99E82A75642AC823" \
    | gpg --dearmor -o /etc/apt/keyrings/sbt-archive-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/sbt-archive-keyring.gpg] https://repo.scala-sbt.org/scalasbt/debian all main" > /etc/apt/sources.list.d/sbt.list \
 && echo "deb [signed-by=/etc/apt/keyrings/sbt-archive-keyring.gpg] https://scala.jfrog.io/artifactory/debian all main" > /etc/apt/sources.list.d/scala.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    openjdk-21-jdk \
    sbt \
 && rm -rf /var/lib/apt/lists/*

# (Optional) JAVA_HOME is not strictly required for sbt, but some tools expect it.
# We set it dynamically at shell init time to support multiple architectures.
RUN echo 'export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which javac))))"' > /etc/profile.d/java_home.sh \
 && chmod +x /etc/profile.d/java_home.sh

WORKDIR /workspace

# Clone SHIR repo branches into separate subdirectories
RUN git clone -b new-test-tag --single-branch --depth 1 --recursive --shallow-submodules https://bitbucket.org/cdubach/shir /workspace/shir-new-test-tag \
 && git clone -b new-test-tag-y --single-branch --depth 1 --recursive --shallow-submodules https://bitbucket.org/cdubach/shir /workspace/shir-new-test-tag-y \
 && git clone -b eqsat-nn-extra-sync --single-branch --depth 1 --recursive --shallow-submodules https://bitbucket.org/cdubach/shir /workspace/shir-eqsat-nn-extra-sync

# Precompile the test suites for all three branches
RUN cd /workspace/shir-new-test-tag && sbt test:compile \
 && cd /workspace/shir-new-test-tag-y && sbt test:compile \
 && cd /workspace/shir-eqsat-nn-extra-sync && sbt test:compile

# Copy the repo into the container
# COPY --chown=${USERNAME}:${USERNAME} . /workspace
COPY . /workspace

# Set up permission
RUN chmod -R 777 /workspace
RUN mkdir /.cache
RUN chmod -R 777 /.cache
RUN mkdir /.sbt
RUN chmod -R 777 /.sbt
RUN chmod -R 777 /tmp
RUN mkdir /tmp/.sbt
RUN chmod -R 777 /tmp/.sbt

# Default command: run all eqsat and lowering.
# Results are written to /workspace/results.
CMD ["/bin/bash", "-lc", "set -euo pipefail; python3 evaluation.py"]
