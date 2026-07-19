#!/bin/sh
set -eu

package_dir=${CI_RBE_PACKAGE_DIR:-/home/builder/package}
input_dir=${CI_RBE_INPUT_DIR:-/mnt/input}
output_dir=${CI_RBE_OUTPUT_DIR:-/mnt/output}
progress_dir=${CI_RBE_PROGRESS_DIR:-/mnt/progress}
stage_timeout=${CI_RBE_STAGE_TIMEOUT:-270m}
stage_number=${CI_RBE_STAGE_NUMBER:-unknown}
build_log=$progress_dir/siso-build.log

as_builder() {
	su builder -c "cd '$package_dir' && $*"
}

if [ -n "${RBE_TARGET:-}" ] && [ "$(apk --print-arch)" != "$RBE_TARGET" ]; then
	echo "Expected $RBE_TARGET container, got $(apk --print-arch)" >&2
	exit 1
fi

mkdir -p "$input_dir" "$output_dir" "$progress_dir"

if [ "${CI_RBE_DRY_RUN:-0}" = 1 ]; then
	echo "Running synthetic checkpoint stage $stage_number"
	if [ -f "$input_dir/package.tar.zst" ]; then
		(
			cd "$input_dir"
			sha256sum -c package.tar.zst.sha256
		)
		tar -xf "$input_dir/package.tar.zst" -C "$package_dir"
		rm -f \
			"$input_dir/package.tar.zst" \
			"$input_dir/package.tar.zst.sha256"
		test -f "$package_dir/src/.rbe-dry-run-stage"
		echo "Restored synthetic package-tree checkpoint"
	else
		mkdir -p "$package_dir/src"
	fi
	printf '%s\n' "$stage_number" > "$package_dir/src/.rbe-dry-run-stage"
	tar -I 'zstd -T0 -1' \
		-cf "$progress_dir/package.tar.zst" \
		-C "$package_dir" src
	(
		cd "$progress_dir"
		sha256sum package.tar.zst > package.tar.zst.sha256
	)
	echo "Synthetic checkpoint stage $stage_number completed"
	exit 0
fi

install -d -o builder -g abuild /var/cache/distfiles

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
		abuild -K build" > "$build_log" 2>&1 &
build_pid=$!

report_progress() {
	while sleep 300; do
		echo "=== Siso heartbeat $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
		df -h "$package_dir" "$progress_dir"
		free -h || true
		du -sh "$package_dir/src" "$progress_dir" || true
		tail -n 20 "$build_log" || true
	done
}
report_progress &
reporter_pid=$!

wait "$build_pid"
status=$?
kill "$reporter_pid" 2>/dev/null || true
wait "$reporter_pid" 2>/dev/null || true
set -e
tail -n 100 "$build_log" || true

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
