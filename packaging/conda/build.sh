#!/usr/bin/env bash
set -euo pipefail

# Prefer conda-provided fmt (12.x). Do not fall back to FetchContent fmt 11.
if [[ -z "${PREFIX:-}" ]]; then
  echo "PREFIX is unset; rattler-build must provide the conda install prefix" >&2
  exit 1
fi

if [[ -f .gitmodules ]] && [[ ! -f common/CMakeLists.txt ]]; then
  git submodule update --init --recursive
fi

# Upstream CMake uses git tags for packaging metadata when .git exists.
# Fork checkouts / conda builds often have no tags, so stage a tree without .git
# and let CMakeLists fall back to PROJECT_VERSION (0.21.2).
src_root="$(pwd)"
stage="${SRC_DIR:-${src_root}}/build-conda-src"
rm -rf "${stage}"
mkdir -p "${stage}"
# Copy tracked content + initialized submodule; exclude VCS and prior builds.
tar -C "${src_root}" \
  --exclude='.git' \
  --exclude='build-conda' \
  --exclude='build-conda-src' \
  --exclude='output' \
  -cf - . | tar -C "${stage}" -xf -

# During rattler-build, PREFIX is the host+install prefix.
# For local smoke tests, deps live in CONDA_PREFIX while PREFIX is the install root.
host_prefix="${CONDA_PREFIX:-${PREFIX}}"

cmake -S "${stage}" -B "${src_root}/build-conda" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_PREFIX_PATH="${host_prefix};${PREFIX}" \
  -DEigen3_DIR="${host_prefix}/share/eigen3/cmake" \
  -DBUILD_TESTING=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_DOCUMENTATION=OFF \
  -DGENERATE_PYLIBFRANKA=OFF \
  -DSKIP_CXX_BUILD=OFF

cmake --build "${src_root}/build-conda" --parallel "${CPU_COUNT:-1}"
cmake --install "${src_root}/build-conda"

# Fail the build if the shared library is not linked against conda fmt 12.
libfranka="$(find "${PREFIX}/lib" -maxdepth 1 -name 'libfranka.so.*' -type f | head -n 1)"
if [[ -z "${libfranka}" ]]; then
  echo "libfranka shared library was not installed into ${PREFIX}/lib" >&2
  exit 1
fi

needed="$(readelf -d "${libfranka}" | awk '/NEEDED/ {print $5}' | tr -d '[]')"
echo "libfranka NEEDED:"
echo "${needed}"

if ! grep -qx 'libfmt.so.12' <<<"${needed}"; then
  echo "ABI check failed: expected NEEDED libfmt.so.12 (Pixi/robostack), got:" >&2
  echo "${needed}" >&2
  exit 1
fi
if grep -Eq 'libfmt\.so\.9($|\.)' <<<"${needed}"; then
  echo "ABI check failed: package must not depend on libfmt.so.9 (Ubuntu noble ABI)" >&2
  exit 1
fi
if grep -Eq 'libPoco(Foundation|Net)\.so\.80($|\.)' <<<"${needed}"; then
  echo "ABI check failed: package must not depend on Ubuntu Poco SONAME .80" >&2
  exit 1
fi
if ! grep -Eq 'libpinocchio_(default|parsers)\.so\.4\.0\.0' <<<"${needed}"; then
  echo "ABI check failed: expected NEEDED libpinocchio_*.so.4.0.0 (physical_ai_runtime)" >&2
  echo "${needed}" >&2
  exit 1
fi
if grep -Eq 'libpinocchio_.*\.so\.4\.1\.' <<<"${needed}"; then
  echo "ABI check failed: package must not depend on pinocchio 4.1 SONAME" >&2
  exit 1
fi
if grep -Eq 'liburdfdom_world\.so\.5' <<<"${needed}"; then
  echo "ABI check failed: expected urdfdom 6 (robostack/Pixi), not SONAME .5" >&2
  exit 1
fi
