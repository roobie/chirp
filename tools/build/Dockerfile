# The build container: the pinned Alpine base plus the packages in packages.txt.
# Built by .github/workflows/build-image.yml and pinned by digest in pins.jdn
# as :build-image, so the packages cannot change under a fixed pin.
# Build context is tools/build.
ARG BASE
FROM ${BASE}
COPY packages.txt /packages.txt
RUN apk add --no-cache -q $(cat /packages.txt) \
 && apk info -v | sort > /etc/chirp-apk-versions.txt
