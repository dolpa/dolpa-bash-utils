FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install packages required to run the tests and build tools
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates \
     curl \
     wget \
     git \
     unzip \
     bash \
     procps \
     jq \
  && rm -rf /var/lib/apt/lists/*

# Install bats-core so run-tests.sh won't try to build/install it itself
RUN git clone https://github.com/bats-core/bats-core.git /tmp/bats-core \
  && /tmp/bats-core/install.sh /usr/local \
  && rm -rf /tmp/bats-core

# Create workdir 
WORKDIR /opt/bash-utils

# Copy repository into the image (this will be overridden by volume mount in run-tests-docker.sh)
COPY . /opt/bash-utils

# Make sure scripts are executable
RUN chmod +x /opt/bash-utils/run-tests.sh || true

# Default command: run the project's test runner with any passed arguments
# This allows for: docker run bash-utils [test-arguments]
ENTRYPOINT ["/bin/bash", "/opt/bash-utils/run-tests.sh"]
