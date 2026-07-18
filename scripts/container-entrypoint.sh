#!/bin/sh
set -eu

package_dir=/home/builder/package

as_builder() {
	su builder -c "cd '$package_dir' && $*"
}

case "${1:-validate}" in
validate)
	sh -n "$package_dir/APKBUILD"
	shellcheck "$package_dir/chromium-launcher.sh"
	as_builder abuild validate
	;;
build)
	install -d -o builder -g abuild /var/cache/distfiles
	as_builder abuild -r
	find /home/builder/packages -type f -name '*.apk' -exec cp -v '{}' /output/ ';'
	;;
shell)
	exec su - builder
	;;
stage)
	exec /usr/local/bin/ci-stage
	;;
*)
	echo "usage: container-entrypoint {validate|build|shell|stage}" >&2
	exit 2
	;;
esac
