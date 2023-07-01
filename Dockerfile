# It doesn't seem like the wolfi base image has any other tags besides "latest" https://edu.chainguard.dev/chainguard/chainguard-images/reference/wolfi-base/image_specs/

FROM cgr.dev/chainguard/wolfi-base:latest
# Renovate "style" is used for some versioning. See https://docs.renovatebot.com/modules/manager/regex/#advanced-capture

# Make all shells run in a safer way. Ref: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
# SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

# Install rpm packages that we need. AWS Session Manager Plugin is not published in any repo that we can use, so we grab it directly from where they publish it in S3.
# hadolint ignore=DL3041

# RUN ARCH_STRING=$(uname -m) \
#   && if [ "$ARCH_STRING" = "x86_64" ]; then \
#       SSM_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"; \
#     elif [ "$ARCH_STRING" = "aarch64" ]; then \
#       SSM_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"; \
#     fi \
RUN apk add \
    bash \
    git \
    curl \
    py3-pip \  
    # bind-utils  the analogous package seems to be bind-tools
    bind-tools \ 
    bzip2 \
    # bzip2-devel  the analogous package seems to be bzip2-dev
    bzip2-dev \
    findutils \
    gcc \
    # gcc-c++ the analogous package seems to be libstdc++
    libstdc++ \
    gettext \
    # iptables-nft the analogous package seems to be contained within iptables
    iptables \ 
    jq \
    # libffi-devel the analogous package seems to be libffi-dev
    libffi-dev \
    # libxslt-devel the analogous package seems to be libxslt-dev
    libxslt-dev \
    make \
    # nc the analogous package seems to be netcat-openbsd
    netcat-openbsd \
    # ncurses-devel the analogous package seems to be ncurses-dev
    ncurses-dev \ 
    openldap-clients \
    # openssl-devel the analogous package seems to be openssl-dev
    openssl-dev \ 
    # perl-Digest-SHA no pacakge found
    # procps-ng there is a procps package but not procps-ng
    procps \ 
    # readline-devel the analogous package seems to be readline-dev
    readline-dev \ 
    # sqlite-devel the analogous package seems to be sqlite-dev
    sqlite-dev \ 
    sshpass \
    # unzip this is already present in the image:
    #     8e347e3b0047:/# which unzip
    # /usr/bin/unzip
    wget \
    # which  is already present in the image
    # xz  already present in the image
#   "${SSM_PLUGIN_URL}" \
  # && dnf clean all \
  # && rm -rf /var/cache/yum/
    && apk cache clean

# Install asdf. Get versions from https://github.com/asdf-vm/asdf/releases
# hadolint ignore=SC2016
# renovate: datasource=github-tags depName=asdf-vm/asdf
ENV ASDF_VERSION=0.12.0
ENV ASDF_DIR=/root/.asdf
RUN git clone https://github.com/asdf-vm/asdf.git --branch v${ASDF_VERSION} --depth 1 "${HOME}/.asdf" \
  && echo -e '\nsource $HOME/.asdf/asdf.sh' >> "${HOME}/.bashrc" \
  && echo -e '\nsource $HOME/.asdf/asdf.sh' >> "${HOME}/.profile" \
  && source "${HOME}/.asdf/asdf.sh"
ENV PATH="/root/.asdf/shims:/root/.asdf/bin:${PATH}"

# Copy our .tool-versions file into the container
COPY .tool-versions /root/.tool-versions

# Zarf needs to be added separately since it doesn't have a "shortform" option in the asdf registry yet
RUN asdf plugin add zarf https://github.com/defenseunicorns/asdf-zarf.git
# Install all other ASDF plugins that are present in the .tool-versions file.
RUN cat /root/.tool-versions | cut -d' ' -f1 | grep "^[^\#]" | grep -v "zarf" | xargs -i asdf plugin add {}

# Install all ASDF versions that are present in the .tool-versions file
RUN asdf install

# Install sshuttle. Get versions by running `pip index versions sshuttle`
# renovate: datasource=pypi depName=sshuttle
ENV SSHUTTLE_VERSION=1.1.1
RUN pip install --force-reinstall -v "sshuttle==${SSHUTTLE_VERSION}"

# Support tools installed as root when running as any other user
ENV ASDF_DATA_DIR="/root/.asdf"

CMD ["/bin/bash"]
