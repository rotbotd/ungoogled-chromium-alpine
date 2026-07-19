# ungoogled-chromium-alpine

Experimental Alpine Linux packaging for ungoogled-chromium, built in Podman.
The `APKBUILD` starts with Alpine's `community/chromium` recipe and applies the
matching ungoogled-chromium patch bundle before Chromium is configured.

The recipe is pinned to Chromium and ungoogled-chromium
`150.0.7871.128-1`. It targets `x86_64` and `aarch64`.

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
pull requests. `Distributed Chromium build` is manually dispatched with one of
four modes:

- `validate` checks workflows, shell, package metadata, Compose files, and both
  Buildbarn worker configurations without starting RBE.
- `infrastructure-dry-run` runs two x86_64 coordinator stages and two workers,
  uploading and restoring small synthetic checkpoints.
- `checkpoint-canary` runs two 15-minute x86_64 compilation stages with eight
  workers to exercise real remote execution and checkpoint restoration.
- `full` builds x86_64 and aarch64 independently. Each target uses eight workers
  and up to four 120-minute coordinator stages.

The distributed workflow needs two named Cloudflare tunnels protected by the
same Access service token:

- Secret `CLOUDFLARE_TUNNEL_TOKEN_X86_64`
- Secret `CLOUDFLARE_TUNNEL_TOKEN_AARCH64`
- Variable `RBE_TUNNEL_HOSTNAME_X86_64`
- Variable `RBE_TUNNEL_HOSTNAME_AARCH64`

Run the modes in order and monitor them with GitHub CLI:

```sh
gh workflow run rbe-build.yml -f mode=validate
gh workflow run rbe-build.yml -f mode=infrastructure-dry-run
gh workflow run rbe-build.yml -f mode=checkpoint-canary
gh workflow run rbe-build.yml -f mode=full
gh run list --workflow rbe-build.yml
gh run watch RUN_ID
```

Completed APKs and `SHA256SUMS` are stored in architecture-specific workflow
artifacts for seven days. Checkpoints are retained for one day and superseded
checkpoints are deleted after the next stage succeeds.

## Inspect the builder

```sh
./podman.sh shell
```

The generated signing key is local to the builder image. Packages produced by
this project are development artifacts and are not signed by Alpine Linux.
Replace the local maintainer address in `package/APKBUILD` before publishing.

`PODMAN_BUILD_ARGS` and `PODMAN_RUN_ARGS` can supply host-specific Podman
options without editing the wrapper. They are normally unset.
