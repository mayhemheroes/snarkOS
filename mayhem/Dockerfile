FROM --platform=linux/amd64 ubuntu:22.04 AS builder

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl build-essential
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install -f cargo-fuzz

ADD . /snarkOS
WORKDIR /snarkOS

RUN cargo +nightly fuzz build --fuzz-dir fuzz network &&     mv fuzz/target/x86_64-unknown-linux-gnu/release/network /network

RUN cargo +nightly fuzz build --fuzz-dir fuzz deserialization &&     mv fuzz/target/x86_64-unknown-linux-gnu/release/deserialization /deserialization

RUN RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1"     cargo +nightly build --release --manifest-path fuzz/Cargo.toml &&     mv fuzz/target/release/network /network_no_inst &&     mv fuzz/target/release/deserialization /deserialization_no_inst

FROM ubuntu:22.04

COPY --from=builder /network /network_no_inst /deserialization /deserialization_no_inst /
