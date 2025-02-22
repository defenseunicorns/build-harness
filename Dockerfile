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
    'dnf-command(config-manager)' \
    ca-certificates \
    findutils \
    gcc \
    gcc-c++ \
    gettext \
    git \
    httpd-tools \
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

# Trust the Department of Defense CA certificates from the specified ZIP archive
RUN set -e && \
    URL="https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_v5-6_dod.zip" && \
    ZIP_FILE="dod_certs.zip" && \
    EXTRACT_DIR="dod-certs" && \
    TRUST_DIR="/etc/pki/ca-trust/source/anchors/" && \
    curl -o "$ZIP_FILE" "$URL" && \
    mkdir -p "$EXTRACT_DIR" && \
    unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR" && \
    CERTS_DIR=$(find "$EXTRACT_DIR" -type d -name "Certificates_PKCS7*") && \
    cd "$CERTS_DIR" && \
    for p7b_file in *.p7b; do \
        if [ "$(openssl asn1parse -inform DER -in "$p7b_file" 2>/dev/null)" ]; then \
            openssl pkcs7 -inform DER -print_certs -in "$p7b_file" -out "${p7b_file%.p7b}.crt"; \
        else \
            openssl pkcs7 -print_certs -in "$p7b_file" -out "${p7b_file%.p7b}.crt"; \
        fi; \
    done && \
    cp -v *.crt "$TRUST_DIR" && \
    update-ca-trust extract && \
    cd ../../ && \
    rm -rf "$ZIP_FILE" "$EXTRACT_DIR" && \
    echo "DoD certificates have been installed and trusted successfully."

# Install Docker. To use Docker you need to run the 'docker run' command with '-v /var/run/docker.sock:/var/run/docker.sock' to mount the docker socket into the container.
# WARNING: This is a security risk that requires other mitigations to be in place. See https://stackoverflow.com/a/41822163. Doing so will give the container root access to the host machine.
# No additional security risk is posed if this container is run without mounting the docker socket.
# It is our belief that this is safe to do on GitHub Actions hosted runners, since it is GitHub's own infrastructure that would be at risk if they didn't mitigate what would otherwise be an incredibly easy to exploit security hole.
# This is NOT regarded as safe to do on self-hosted runners without having taken some other mitigation step first.
RUN dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
      && dnf install -y docker-ce docker-ce-cli containerd.io \
      && dnf clean all \
      && rm -rf /var/cache/yum/


# Fetch the latest ASDF version and install it
RUN ASDF_VERSION=$(curl -s https://api.github.com/repos/asdf-vm/asdf/releases/latest | jq -r .tag_name) && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        ASDF_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-amd64.tar.gz"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        ASDF_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-arm64.tar.gz"; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi && \
    curl -L "$ASDF_URL" -o /tmp/asdf.tar.gz && \
    mkdir -p /usr/local/asdf && \
    tar -xzf /tmp/asdf.tar.gz -C /usr/local/asdf && \
    ln -sf /usr/local/asdf/asdf /usr/local/bin/asdf && \
    rm -f /tmp/asdf.tar.gz
ENV ASDF_DATA_DIR="/root/.asdf"
ENV PATH="${ASDF_DATA_DIR}/shims:$PATH"

# Copy our .tool-versions file into the container
COPY .tool-versions /root/.tool-versions

# These tools need to be added separately since they don't have a "shortform" option in the asdf registry yet
RUN asdf plugin add zarf https://github.com/defenseunicorns/asdf-zarf.git && \
    asdf plugin add git-xargs https://github.com/defenseunicorns/asdf-git-xargs.git && \
    asdf plugin add opentofu https://github.com/defenseunicorns/asdf-opentofu.git && \
    asdf plugin add uds-cli https://github.com/defenseunicorns/asdf-uds-cli.git && \
    asdf plugin add atmos https://github.com/cloudposse/asdf-atmos.git

# Install all other ASDF plugins that are present in the .tool-versions file.
RUN cat /root/.tool-versions | \
  cut -d' ' -f1 | \
  grep "^[^\#]" | \
  grep -v "zarf" | \
  grep -v "git-xargs" | \
  grep -v "opentofu" | \
  grep -v "uds-cli" | \
  grep -v "atmos" | \
  xargs -i asdf plugin add {}
# Install all ASDF versions that are present in the .tool-versions file
RUN asdf install

# Install sshuttle. Get versions by running `pip index versions sshuttle`
# renovate: datasource=pypi depName=sshuttle
ENV SSHUTTLE_VERSION=1.1.2
RUN pip install --force-reinstall -v "sshuttle==${SSHUTTLE_VERSION}"

CMD ["/bin/bash"]
