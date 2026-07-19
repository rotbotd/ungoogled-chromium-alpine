FROM docker.io/library/alpine:edge

RUN apk add --no-cache \
		alpine-sdk \
		coreutils \
		shellcheck \
		sudo \
		tar \
		zstd \
	&& adduser -D -h /home/builder builder \
	&& addgroup builder abuild \
	&& printf '%s\n' 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder \
	&& chmod 0440 /etc/sudoers.d/builder \
	&& install -d -o builder -g abuild \
		/home/builder/.abuild \
		/home/builder/package \
		/home/builder/packages \
		/var/cache/distfiles \
	&& su builder -c 'abuild-keygen -a -n' \
	&& cp /home/builder/.abuild/*.rsa.pub /etc/apk/keys/

COPY --chown=builder:abuild package/ /home/builder/package/
COPY scripts/container-entrypoint.sh /usr/local/bin/container-entrypoint
COPY scripts/ci-stage.sh /usr/local/bin/ci-stage
COPY scripts/ci-rbe.sh /usr/local/bin/ci-rbe

RUN chmod 0755 \
	/usr/local/bin/container-entrypoint \
	/usr/local/bin/ci-rbe \
	/usr/local/bin/ci-stage

WORKDIR /home/builder/package
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
CMD ["validate"]
