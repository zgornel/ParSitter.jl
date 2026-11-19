#!/usr/bin/env bash
# Cross-compiles the tree-sitter grammars for all supported platforms with zig
# and binds the resulting `tree-sitter-grammars` artifacts in Artifacts.toml.
#
# Usage (from the ParSitter.jl root):
#   docker run --rm -v "$PWD:/ParSitter" -w /ParSitter julia:1.12 bash deps/grammars/build.sh
#
# Outputs: deps/grammars/out/tree-sitter-grammars-<triplet>.tar.gz
# (upload them to ParSitter.jl_artifacts/grammars/) and an updated Artifacts.toml.
set -euo pipefail

ZIG_VERSION=0.14.1
ZIG_DIR=/opt/zig-x86_64-linux-${ZIG_VERSION}

apt-get update -qq
apt-get install -y -qq --no-install-recommends curl ca-certificates xz-utils >/dev/null
if [ ! -x "${ZIG_DIR}/zig" ]; then
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
        | tar -xJ -C /opt
fi

ZIG="${ZIG_DIR}/zig" julia --startup-file=no deps/grammars/build.jl
