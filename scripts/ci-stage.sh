#!/bin/sh
set -eu

package_dir=/home/builder/package
input_dir=/mnt/input
output_dir=/mnt/output
progress_dir=/mnt/progress
stage_timeout=${CI_STAGE_TIMEOUT:-300m}

as_builder() {
	su builder -c "cd '$package_dir' && $*"
}

mkdir -p "$input_dir" "$output_dir" "$progress_dir"
install -d -o builder -g abuild /var/cache/distfiles

if [ -f "$input_dir/progress.tar.zst" ]; then
	echo "Restoring the previous compilation checkpoint"
	(
		cd "$input_dir"
		sha256sum -c progress.tar.zst.sha256
	)
	tar -xf "$input_dir/progress.tar.zst" -C "$package_dir"
	rm -f "$input_dir/progress.tar.zst" "$input_dir/progress.tar.zst.sha256"
	chown -R builder:abuild "$package_dir/src"
else
	echo "Fetching, unpacking, and preparing Chromium"
	as_builder abuild -K -r builddeps fetch unpack prepare
fi

df -h "$package_dir"
du -sh "$package_dir/src"

echo "Compiling for up to $stage_timeout"
set +e
timeout -k 10m -s TERM "$stage_timeout" \
	su builder -c "cd '$package_dir' && abuild -K build"
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
	echo "Stage timed out; creating a resumable checkpoint"
	tar -I 'zstd -T0 -3' -cf "$progress_dir/progress.tar.zst" \
		-C "$package_dir" src
	(
		cd "$progress_dir"
		sha256sum progress.tar.zst > progress.tar.zst.sha256
	)
	;;
*)
	echo "Compilation failed with exit code $status" >&2
	exit "$status"
	;;
esac
