FROM node:16-buster AS build_frontend

WORKDIR /app

# RUN apt install git python2

COPY package.json .

RUN ls -l /usr/local/bin/npm
RUN npm --version
RUN npm install

COPY . .

RUN NODE_ENV=production npm run build && \
    rm dist/data/public/index.html.br


FROM golang:1.16-buster AS build_backend

WORKDIR /app

ENV CGO_LDFLAGS_ALLOW "-fopenmp"
ENV GO111MODULE "on"

RUN apt-get update && \
    apt-get install -y libglib2.0-dev curl

COPY . .

RUN find server/plugin/plg_* -type f -name "install.sh" -exec {} \; && \
    go generate -x ./server/...

RUN PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ CGO_CFLAGS_ALLOW='-fopenmp' go build -mod=vendor --tags "fts5" -ldflags "-X github.com/mickael-kerjean/filestash/server/common.BUILD_DATE=`date -u +%Y%m%d` -X github.com/mickael-kerjean/filestash/server/common.BUILD_REF=`git rev-parse HEAD`" -o filestash server/main.go

FROM arm64v8/debian:stable-slim

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /app

COPY --from=build_frontend /app/dist .
COPY --from=build_backend /app/filestash .
COPY config /app/data/state/config

RUN apt-get update > /dev/null && \
    apt-get upgrade -y && \
    apt-get install -y libglib2.0-0 && \
    #################
    # Optional dependencies
    apt-get install -y curl tor emacs ffmpeg zip poppler-utils > /dev/null && \
    # org-mode: html export
    curl https://raw.githubusercontent.com/mickael-kerjean/filestash/master/server/.assets/emacs/htmlize.el > /usr/share/emacs/site-lisp/htmlize.el && \
    # org-mode: markdown export
    curl https://raw.githubusercontent.com/mickael-kerjean/filestash/master/server/.assets/emacs/ox-gfm.el > /usr/share/emacs/site-lisp/ox-gfm.el && \
    # org-mode: pdf export (with a light latex distribution)
    #cd && apt-get install -y wget perl > /dev/null && \
    #export CTAN_REPO="http://mirror.las.iastate.edu/tex-archive/systems/texlive/tlnet" && \
    #curl -sL "https://yihui.name/gh/tinytex/tools/install-unx.sh" | sh && \
    #mv ~/.TinyTeX /usr/share/tinytex && \
    #/usr/share/tinytex/bin/*/kpsewhich && \
    #/usr/share/tinytex/bin/*/tlmgr install wasy && \
    #/usr/share/tinytex/bin/*/tlmgr install ulem && \
    #/usr/share/tinytex/bin/*/tlmgr install marvosym && \
    #/usr/share/tinytex/bin/*/tlmgr install wasysym && \
    #/usr/share/tinytex/bin/*/tlmgr install xcolor && \
    #/usr/share/tinytex/bin/*/tlmgr install listings && \
    #/usr/share/tinytex/bin/*/tlmgr install parskip && \
    #/usr/share/tinytex/bin/*/tlmgr install float && \
    #/usr/share/tinytex/bin/*/tlmgr install wrapfig && \
    #/usr/share/tinytex/bin/*/tlmgr install sectsty && \
    #/usr/share/tinytex/bin/*/tlmgr install capt-of && \
    #/usr/share/tinytex/bin/*/tlmgr install epstopdf-pkg && \
    #/usr/share/tinytex/bin/*/tlmgr install cm-super && \
    #ln -s /usr/share/tinytex/bin/*/pdflatex /usr/local/bin/pdflatex && \
    #apt-get purge -y --auto-remove perl wget && \
    # Cleanup
    find /usr/share/ -name 'doc' | xargs rm -rf && \
    find /usr/share/emacs -name '*.pbm' | xargs rm -f && \
    find /usr/share/emacs -name '*.png' | xargs rm -f && \
    find /usr/share/emacs -name '*.xpm' | xargs rm -f && \
    #################
    # Finalise the image
    useradd filestash && \
    chown -R filestash:filestash /app/ && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

USER filestash
RUN timeout 1 /app/filestash | grep -q start

EXPOSE 8334
VOLUME ["/app/data/state/"]
CMD ["/app/filestash"]
