FROM rockylinux:9
# Renovate "style" is used for some versioning. See https://docs.renovatebot.com/modules/manager/regex/#advanced-capture

# Make all shells run in a safer way. Ref: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

# Install rpm packages that we need. AWS Session Manager Plugin is not published in any repo that we can use, so we grab it directly from where they publish it in S3.
# hadolint ignore=DL3041
RUN ARCH_STRING=$(uname -m) \
  && if [ "$ARCH_STRING" = "x86_64" ]; then \
      SSM_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"; \
    elif [ "$ARCH_STRING" = "aarch64" ]; then \
      SSM_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"; \
    fi \
  && dnf install -y --refresh \
    bind-utils \
    bzip2 \
    bzip2-devel \
    findutils \
    gcc \
    gcc-c++ \
    gettext \
    git \
    iptables-nft \
    jq \
    libffi-devel \
    libxslt-devel \
    make \
    nc \
    ncurses-devel \
    openldap-clients \
    openssl-devel \
    perl-Digest-SHA \
    procps-ng \
    python3-pip \
    readline-devel \
    sqlite-devel \
    sshpass \
    unzip \
    wget \
    which \
    xz \
  "${SSM_PLUGIN_URL}" \
  && dnf clean all \
  && rm -rf /var/cache/yum/

# Install asdf. Get versions from https://github.com/asdf-vm/asdf/releases
# hadolint ignore=SC2016
# renovate: datasource=github-tags depName=asdf-vm/asdf
ENV ASDF_VERSION=0.11.3
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
