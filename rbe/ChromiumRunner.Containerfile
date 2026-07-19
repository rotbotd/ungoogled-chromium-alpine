FROM ungoogled-chromium-alpine-builder

RUN su builder -c 'cd /home/builder/package && abuild -K -r builddeps'

ENTRYPOINT []
