# Build Stage
FROM ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cmake clang curl git-all build-essential libssl-dev pkg-config
RUN curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN ${HOME}/.cargo/bin/rustup default nightly
RUN ${HOME}/.cargo/bin/cargo install -f cargo-fuzz
RUN git clone https://github.com/AleoHQ/snarkOS.git
WORKDIR /snarkOS/fuzz/
RUN ${HOME}/.cargo/bin/cargo fuzz build
WORKDIR /

# Package Stage
#FROM ubuntu:20.04
#COPY --from=builder /snarkOS/fuzz/target/x86_64-unknown-linux-gnu/release/ /
#COPY /Mayhem /Mayhem