#!/bin/sh
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
image=${IMAGE:-localhost/ungoogled-chromium-alpine-builder}
cache_volume=${CACHE_VOLUME:-ungoogled-chromium-alpine-distfiles}
podman_build_args=${PODMAN_BUILD_ARGS:-}
podman_run_args=${PODMAN_RUN_ARGS:-}

podman_build() {
	# The optional argument strings intentionally expand into separate flags.
	# shellcheck disable=SC2086
	podman build $podman_build_args \
		-t "$image" -f "$project_dir/Containerfile" "$project_dir"
}

podman_run() {
	# shellcheck disable=SC2086
	podman run $podman_run_args "$@"
}

case "${1:-validate}" in
image)
	podman_build
	;;
validate)
	podman_build
	podman_run --rm "$image" validate
	;;
build)
	podman_build
	mkdir -p "$project_dir/output"
	podman_run --rm \
		--ulimit nofile=4096:4096 \
		--mount "type=volume,source=$cache_volume,target=/var/cache/distfiles" \
		--mount "type=bind,source=$project_dir/output,target=/output" \
		"$image" build
	;;
shell)
	podman_build
	podman_run --rm -it \
		--mount "type=volume,source=$cache_volume,target=/var/cache/distfiles" \
		"$image" shell
	;;
*)
	echo "usage: $0 {image|validate|build|shell}" >&2
	exit 2
	;;
esac
