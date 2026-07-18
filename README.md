# ungoogled-chromium-alpine

Experimental Alpine Linux packaging for ungoogled-chromium, built in Podman.
The `APKBUILD` starts with Alpine's `community/chromium` recipe and applies the
matching ungoogled-chromium patch bundle before Chromium is configured.

The recipe is pinned to Chromium and ungoogled-chromium
`150.0.7871.128-1`. It currently targets `x86_64`.

## Inputs

- Alpine `community/chromium` `150.0.7871.128-r0`
- Arch Linux ungoogled-chromium tag `150.0.7871.128-1`
- Upstream ungoogled-chromium patch bundle `150.0.7871.128-1`

The Alpine recipe supplies the musl patches, dependency list, compiler flags,
subpackage layout, and packaging functions. The Arch recipe supplies the
ungoogled pruning, patching, domain substitution, and GN configuration order.

## Requirements

- Podman
- At least 16 GB of RAM, with swap available
- At least 100 GB of free disk space for sources, build output, and images

## Validate the recipe

This builds the small Alpine builder image and runs syntax, shell, and
`abuild validate` checks without downloading Chromium:

```sh
./podman.sh validate
```

## Build the packages

```sh
./podman.sh build
```

The build uses a named Podman volume for `/var/cache/distfiles`, so reruns do
not redownload the Chromium source. Finished `.apk` files are copied to
`output/`.

The build is intentionally explicit because compiling Chromium can take hours.
The initial port sets `!check`; Alpine's Chromium unit tests exercise namespace
and display behavior that needs additional container privileges. The compiler
and packaging steps remain unchanged from Alpine's recipe.

Debug packages are omitted from this experimental build to reduce build output
and artifact storage.

## GitHub Actions

`Validate` builds the container and runs the lightweight checks on pushes and
pull requests. `Build APK packages` is manually dispatched and splits the
Chromium compilation across seven GitHub-hosted jobs. Each stage runs for up to
five hours and uploads a compressed build-tree checkpoint for the next stage.
Superseded checkpoints are deleted after the next stage succeeds.

Start and monitor the full build with GitHub CLI:

```sh
gh workflow run build.yml
gh run list --workflow build.yml
gh run watch
```

Completed APKs and `SHA256SUMS` are stored in the `packages` workflow artifact
for seven days.

## Inspect the builder

```sh
./podman.sh shell
```

The generated signing key is local to the builder image. Packages produced by
this project are development artifacts and are not signed by Alpine Linux.
Replace the local maintainer address in `package/APKBUILD` before publishing.

`PODMAN_BUILD_ARGS` and `PODMAN_RUN_ARGS` can supply host-specific Podman
options without editing the wrapper. They are normally unset.
