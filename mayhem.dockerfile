# Build Stage
FROM ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cmake clang curl git-all build-essential libssl-dev pkg-config
RUN curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN ${HOME}/.cargo/bin/rustup default nightly
RUN ${HOME}/.cargo/bin/cargo install -f cargo-fuzz
ADD . /snarkOS
WORKDIR /snarkOS/fuzz/
RUN ${HOME}/.cargo/bin/cargo fuzz build
#package stage
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y openssl
RUN mkdir -p /snarkOS/fuzz
COPY --from=builder /snarkOS/fuzz /snarkOS/fuzz
