FROM ubuntu:24.04
WORKDIR /app

# Copy files
COPY book/ ./book
COPY src/ ./src
COPY moon.mod.json ./
COPY examples/ ./examples
COPY test.sh ./

# Install dependencies
RUN apt update
RUN apt install -y curl git wget tar unzip

# Install Moonbit
RUN curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s '0.6.26+4cdee97dd'
ENV PATH="/root/.moon/bin:${PATH}"
RUN moon update
RUN moon install

# Install firtool
RUN wget https://github.com/llvm/circt/releases/download/firtool-1.129.0/firrtl-bin-linux-x64.tar.gz
RUN tar -xzf firrtl-bin-linux-x64.tar.gz
RUN mv firtool-1.111.1/bin/firtool /usr/local/bin/firtool
RUN rm -rf firrtl-bin-linux-x64.tar.gz firtool-1.111.1

# Run tests
RUN bash test.sh

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install mdbook
RUN wget https://github.com/rust-lang/mdBook/releases/download/v0.4.45/mdbook-v0.4.45-x86_64-unknown-linux-gnu.tar.gz
RUN tar -xzf mdbook-v0.4.45-x86_64-unknown-linux-gnu.tar.gz
RUN mv mdbook /usr/local/bin/mdbook
RUN rm mdbook-v0.4.45-x86_64-unknown-linux-gnu.tar.gz

# Build
RUN moon build --target js
RUN bun build src/main/yodl.ts --outdir bundle --minify
RUN cd book && mdbook build
RUN mkdir artifacts
RUN cp -r book/book artifacts/book
RUN cp -r bundle artifacts/bundle
RUN cp src/main/playground.html artifacts/playground.html
