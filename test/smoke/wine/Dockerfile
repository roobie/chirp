# Wine for running the windows build on linux. BASE is the digest-pinned build
# image from pins.jdn; the wine and ca-certificates versions come from its apk
# archive and are printed by run-windows.sh.
ARG BASE
FROM ${BASE}
RUN apk add --no-cache -q wine ca-certificates
ENV WINEDEBUG=-all WINEPREFIX=/tmp/wineprefix XDG_RUNTIME_DIR=/tmp
