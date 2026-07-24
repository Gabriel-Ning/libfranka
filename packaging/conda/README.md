# Prefix.dev binary package (Pixi / robostack ABI)

This recipe builds **libfranka** for the `gabriel-robotics` Prefix.dev channel
against the **same dependency ABI** as `physical_ai_runtime`'s Pixi lock:

- `fmt >=12.1.0,<12.2.0a0` → `libfmt.so.12`
- conda-forge `poco` (not Ubuntu `libPoco*.so.80`)
- `pinocchio`, `eigen`, `tinyxml2`, `console_bridge`

It is **not** a repack of the official `libfranka_*_noble_amd64.deb`. That
`.deb` needs `libfmt.so.9` / `libPoco*.so.80` and fails to `dlopen` against
Pixi `fmt 12` even with SONAME symlinks.

The package ships the shared library, public headers, and CMake
`find_package(Franka)` config so `franka_ros2` / `franka_hardware` can link
against it inside Pixi.

## Prerequisites

- `common/` submodule checked out (`git submodule update --init --recursive`)
- `rattler-build` available (e.g. `pixi global install rattler-build` or from
  the workspace env)

## Build

From the repository root:

```bash
rattler-build build --recipe packaging/conda/recipe.yaml \
  -c https://prefix.dev/gabriel-robotics \
  -c conda-forge
```

The build script refuses to finish unless `libfranka.so` **NEEDED** contains
`libfmt.so.12` and does **not** contain `libfmt.so.9` or `libPoco*.so.80`.

## Upload (separate, credentialed step)

```bash
# After inspecting output/linux-64/libfranka-*.conda
rattler-build upload prefix -c gabriel-robotics output/linux-64/libfranka-*.conda
```

Do not upload until `package_contents` and the ABI `script` tests pass.

## Consume from physical_ai_runtime

This fork tracks upstream **main**; the conda package version is just whatever
`CMakeLists.txt` currently reports. Exact version pins are optional — ABI
compatibility (`fmt` 12 / conda `poco`) matters more than matching
`franka_ros2`'s historical `dependency.repos` tag.

```toml
# pixi.toml
libfranka = "*"
poco = "*"
```

Prefer the `gabriel-robotics` channel so this Pixi-built artifact wins over
any future conda-forge or Ubuntu deb of the same name.
