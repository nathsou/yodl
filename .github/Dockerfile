FROM ubuntu:24.04
WORKDIR /app
ARG YODL_REVISION=local
ENV YODL_REVISION=${YODL_REVISION}

# Copy files
COPY book/ ./book
COPY src/ ./src
COPY moon.mod.json ./
COPY examples/ ./examples
COPY tour/ ./tour
COPY scripts/ ./scripts

# Install dependencies
RUN apt update
RUN apt install -y curl git wget tar unzip

# Install Moonbit
RUN curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s '0.10.11+8f8e8db1e'
ENV PATH="/root/.moon/bin:${PATH}"
RUN moon update
RUN moon install

# Install firtool
RUN wget https://github.com/llvm/circt/releases/download/firtool-1.149.0/firrtl-bin-linux-x64.tar.gz
RUN tar -xzf firrtl-bin-linux-x64.tar.gz
RUN mv firtool-1.149.0/bin/firtool /usr/local/bin/firtool
RUN rm -rf firrtl-bin-linux-x64.tar.gz firtool-1.149.0

# Bun powers the site build and the shared documentation test extractor.
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v1.4.0"
ENV PATH="/root/.bun/bin:${PATH}"

# Run checks and tests
RUN moon check
RUN moon test
RUN bash scripts/test.sh

# Build the static documentation and playground.
RUN bun test src/docs
RUN bun src/docs/build.ts
RUN mv dist artifacts
