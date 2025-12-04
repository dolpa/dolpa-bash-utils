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
  && rm -rf /var/lib/apt/lists/*

# Install bats-core so run-tests.sh won't try to build/install it itself
RUN git clone https://github.com/bats-core/bats-core.git /tmp/bats-core \
  && /tmp/bats-core/install.sh /usr/local \
  && rm -rf /tmp/bats-core

# Create workdir and copy repository into the image
WORKDIR /opt/bash-utils
COPY . /opt/bash-utils

# Make sure scripts are executable
RUN chmod +x /opt/bash-utils/run-tests.sh || true

# Default command: run the project's test runner
ENTRYPOINT ["/bin/bash", "/opt/bash-utils/run-tests.sh"]
