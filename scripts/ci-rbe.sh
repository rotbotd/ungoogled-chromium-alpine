#!/bin/sh
set -eu

package_dir=/home/builder/package
input_dir=/mnt/input
output_dir=/mnt/output
progress_dir=/mnt/progress
stage_timeout=${CI_RBE_STAGE_TIMEOUT:-270m}

as_builder() {
	su builder -c "cd '$package_dir' && $*"
}

install -d -o builder -g abuild /var/cache/distfiles
mkdir -p "$input_dir" "$output_dir" "$progress_dir"

echo "Installing Alpine build dependencies"
as_builder abuild -K -r builddeps

echo "Installing Chromium's pinned Siso release"
GOTOOLCHAIN=auto GOBIN=/usr/local/bin \
	go install go.chromium.org/build/siso@v1.5.16
siso version

if [ -f "$input_dir/package.tar.zst" ]; then
	echo "Restoring the previous package-tree checkpoint"
	(
		cd "$input_dir"
		sha256sum -c package.tar.zst.sha256
	)
	tar -xf "$input_dir/package.tar.zst" -C "$package_dir"
	rm -f \
		"$input_dir/package.tar.zst" \
		"$input_dir/package.tar.zst.sha256"
	chown -R builder:abuild "$package_dir/src"
else
	echo "Fetching, unpacking, and preparing Chromium"
	as_builder "SISO_RBE=1 \
		SISO_REAPI_ADDRESS='${SISO_REAPI_ADDRESS:-127.0.0.1:8980}' \
		SISO_REAPI_INSTANCE='${SISO_REAPI_INSTANCE:-alpine}' \
		abuild -K -r fetch unpack prepare"
fi

df -h "$package_dir"
du -sh "$package_dir/src"

echo "Building Chromium with distributed Siso execution for up to $stage_timeout"
set +e
timeout -k 10m -s TERM "$stage_timeout" \
	su builder -c "cd '$package_dir' && \
		SISO_RBE=1 \
		SISO_REAPI_ADDRESS='${SISO_REAPI_ADDRESS:-127.0.0.1:8980}' \
		SISO_REAPI_INSTANCE='${SISO_REAPI_INSTANCE:-alpine}' \
		SISO_REMOTE_JOBS='${SISO_REMOTE_JOBS:-16}' \
		abuild -K build"
status=$?
set -e

case "$status" in
0)
	echo "Compilation completed; creating APK packages"
	as_builder abuild -K rootpkg
	find /home/builder/packages -type f -name '*.apk' \
		-exec cp -v '{}' "$output_dir/" ';'
	(
		cd "$output_dir"
		sha256sum ./*.apk > SHA256SUMS
	)
	touch "$progress_dir/finished"
	;;
124)
	echo "Stage timed out; creating a resumable package-tree checkpoint"
	tar --sparse -I 'zstd -T0 -3' \
		-cf "$progress_dir/package.tar.zst" \
		-C "$package_dir" src
	(
		cd "$progress_dir"
		sha256sum package.tar.zst > package.tar.zst.sha256
	)
	;;
*)
	echo "Compilation failed with exit code $status" >&2
	exit "$status"
	;;
esac
