FROM almalinux:8.6
MAINTAINER Star Lab <info@starlab.io>

ENV LANG=C.utf-8
ENV LC_ALL=C.utf-8
ENV RUSTUP_HOME=/usr/local/rust
ENV PATH="$PATH:$RUSTUP_HOME/bin"
ENV container=docker

# DNF package config
RUN \
    # Limit AlmaLinux packages to 8.6 minor release
    dnf update -y almalinux-release-8.6 && \
    find /etc/yum.repos.d/ -name almalinux*.repo -print | xargs sed -i 's/$releasever/$releasever.6/' && \
    \
    # Enable PowerTools repo
    dnf install -y dnf-plugins-core && \
    dnf config-manager -y --set-enabled powertools && \
    \
    # Enable EPEL repo
    dnf install -y epel-release && \
    \
    # Enable Openstack repo for OpenvSwitch
    dnf install -y https://www.rdoproject.org/repos/rdo-release.el8.rpm && \
    dnf config-manager --set-disabled advanced-virtualization centos-rabbitmq-38 ceph-pacific openstack-yoga && \
    \
    # Update existing packages
    dnf update -y && \
    \
    dnf clean all && \
    rm -rf /tmp/* /var/tmp/*

# Extra DNF packages
RUN \
    dnf install --setopt install_weak_deps=False -y \
    \
    # Convenience / documentation
    bash-completion \
    file \
    man-db \
    man-pages \
    procps-ng \
    sudo \
    which \
    \
    # Python 3.6 (matches meson)
    python36 \
    python36-devel \
    python3-docutils \
    python3-flake8 \
    python3-importlib-metadata \
    python3-pycodestyle \
    python3-pyflakes \
    \
    # Container signal handling
    tini \
    \
    # Build tools and dependencies
    asciidoc \
    audit-libs-devel \
    augeas \
    autoconf \
    automake \
    bison \
    byacc \
    ctags \
    cyrus-sasl-devel \
    device-mapper-devel \
    diffstat \
    dmidecode \
    dwarves \
    firewalld-filesystem \
    flex \
    fuse-devel \
    fuse3 \
    gcc-toolset-11 \
    gcc-toolset-11-annobin-annocheck \
    gcc-toolset-11-annobin-plugin-gcc \
    gettext \
    git \
    glib2-devel \
    glibc-devel \
    gnutls-devel \
    iproute \
    iproute-tc \
    iptables \
    iptables-ebtables \
    iscsi-initiator-utils \
    libacl-devel \
    libattr-devel \
    libblkid-devel \
    libcap-ng-devel \
    libcurl-devel \
    libiscsi-devel \
    libnl3-devel \
    libpcap-devel \
    libpciaccess-devel \
    libselinux-devel \
    libssh2-devel \
    libtirpc-devel \
    libtool \
    libxml2-devel \
    lvm2 \
    mdevctl \
    meson \
    netcf-devel \
    nfs-utils \
    ninja-build \
    numactl-devel \
    numad \
    openssl-devel \
    openvswitch2.16 \
    parted-devel \
    patchutils \
    pesign \
    pkgconf \
    pkgconf-m4 \
    pkgconf-pkg-config \
    polkit \
    qemu-img \
    readline-devel \
    redhat-rpm-config \
    rpcgen \
    rpm-build \
    rpm-sign \
    sanlock-devel \
    scrub \
    systemd-devel \
    systemtap-sdt-devel \
    yajl-devel \
    && \
    dnf clean all && \
    rm -rf /tmp/* /var/tmp/*

# Install / setup Rust
# Only set CARGO_HOME during build so unprivileged container users won't try to use system location
ARG CARGO_HOME="$RUSTUP_HOME"
RUN curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | \
    sh -s -- -y --profile minimal --default-toolchain 1.60.0-x86_64-unknown-linux-gnu && \
    rustup toolchain install --profile minimal nightly && \
    rustup component add rustfmt clippy && \
    rustup component add rustfmt clippy --toolchain nightly && \
    cargo install cargo-deny --locked && \
    cargo install cargo-license --locked && \
    cargo install cargo-udeps --locked && \
    rm -rf "$CARGO_HOME/registry" /tmp/* /var/tmp/*

# Setup Python
RUN alternatives --set python /usr/bin/python3 && \
    pip3 install --upgrade pip && \
    pip3 install git-archive-all && \
    rm -rf /tmp/* /var/tmp/*

# Allow any user to have sudo access within the container
ARG VER=1
ARG ZIP_FILE=add-user-to-sudoers.zip
RUN curl -L -o ${ZIP_FILE} "https://github.com/starlab-io/add-user-to-sudoers/releases/download/${VER}/${ZIP_FILE}" && \
    unzip "${ZIP_FILE}" && \
    rm "${ZIP_FILE}" && \
    mkdir -p /usr/local/bin && \
    mv add_user_to_sudoers /usr/local/bin/ && \
    mv startup_script /usr/local/bin/ && \
    chmod 4755 /usr/local/bin/add_user_to_sudoers && \
    chmod +x /usr/local/bin/startup_script && \
    # Let regular users be able to use sudo
    echo $'auth       sufficient    pam_permit.so\n\
account    sufficient    pam_permit.so\n\
session    sufficient    pam_permit.so\n\
' > /etc/pam.d/sudo

# Apply some nice bash defaults
COPY mybash.sh /etc/profile.d/

ENTRYPOINT ["/usr/local/bin/startup_script", "/usr/bin/tini", "/usr/bin/scl", "--", "enable", "gcc-toolset-11", "--"]
CMD ["/bin/bash", "-l"]
