#!/bin/sh
set -eu

package_dir=/home/builder/package
output_dir=/mnt/output

as_builder() {
	su builder -c "cd '$package_dir' && $*"
}

install -d -o builder -g abuild /var/cache/distfiles
mkdir -p "$output_dir"

echo "Installing Alpine build dependencies"
as_builder abuild -K -r builddeps

echo "Installing Chromium's pinned Siso release"
GOTOOLCHAIN=auto GOBIN=/usr/local/bin \
	go install go.chromium.org/build/siso@v1.5.16
siso version

echo "Fetching, unpacking, and preparing Chromium"
as_builder "SISO_RBE=1 \
	SISO_REAPI_ADDRESS='${SISO_REAPI_ADDRESS:-127.0.0.1:8980}' \
	SISO_REAPI_INSTANCE='${SISO_REAPI_INSTANCE:-alpine}' \
	abuild -K -r fetch unpack prepare"

df -h "$package_dir"
du -sh "$package_dir/src"

echo "Building Chromium with distributed Siso execution"
as_builder "SISO_RBE=1 \
	SISO_REAPI_ADDRESS='${SISO_REAPI_ADDRESS:-127.0.0.1:8980}' \
	SISO_REAPI_INSTANCE='${SISO_REAPI_INSTANCE:-alpine}' \
	SISO_REMOTE_JOBS='${SISO_REMOTE_JOBS:-16}' \
	abuild -K build"

echo "Creating APK packages"
as_builder abuild -K rootpkg
find /home/builder/packages -type f -name '*.apk' \
	-exec cp -v '{}' "$output_dir/" ';'
(
	cd "$output_dir"
	sha256sum ./*.apk > SHA256SUMS
)
