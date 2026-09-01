FROM ubuntu:24.04
WORKDIR /app

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

# Run checks and tests
RUN moon check
RUN moon test
RUN bash scripts/test.sh

# Install Bun (needed to bundle the playground)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install mdbook
RUN wget https://github.com/rust-lang/mdBook/releases/download/v0.4.45/mdbook-v0.4.45-x86_64-unknown-linux-gnu.tar.gz
RUN tar -xzf mdbook-v0.4.45-x86_64-unknown-linux-gnu.tar.gz
RUN mv mdbook /usr/local/bin/mdbook
RUN rm mdbook-v0.4.45-x86_64-unknown-linux-gnu.tar.gz

# Build
RUN moon build src/lib/driver --target=js --release
RUN bun build src/main/playground.ts src/main/playground-worker.ts --outdir bundle --minify
RUN cd book && mdbook build
RUN mkdir artifacts
RUN cp -r book/book artifacts/book
RUN cp -r bundle artifacts/bundle
RUN cp src/main/playground.html artifacts/playground.html
RUN cp src/main/playground.css artifacts/playground.css
