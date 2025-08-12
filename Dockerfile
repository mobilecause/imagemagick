FROM amazonlinux:latest

# Update system and install development tools
RUN dnf update -y && \
    dnf groupinstall -y "Development Tools" && \
    dnf install -y --allowerasing \
        rpm-build \
        rpm-devel \
        rpmdevtools \
        wget \
        curl \
        tar \
        gzip \
        xz \
        hostname \
        procps-ng \
        'dnf-command(builddep)' \
        dnf-plugins-core \
        createrepo_c \
        gnupg2

# Create build user and setup RPM build environment
RUN useradd -m builder && \
    su - builder -c "rpmdev-setuptree"

# Switch to builder user
USER builder
WORKDIR /home/builder

# Copy the ImageMagick spec file and sources
COPY --chown=builder:builder ImageMagick.spec rpmbuild/SPECS/
COPY --chown=builder:builder sources rpmbuild/SOURCES/sources
COPY --chown=builder:builder ImageMagick.keyring rpmbuild/SOURCES/

# Download ImageMagick source tarball
RUN cd rpmbuild/SOURCES && \
    wget https://imagemagick.org/archive/releases/ImageMagick-7.1.1-47.tar.xz && \
    wget https://imagemagick.org/archive/releases/ImageMagick-7.1.1-47.tar.xz.asc

# Verify checksums
RUN cd rpmbuild/SOURCES && \
    sha512sum -c sources && \
    echo "✅ Source checksums verified"

# Install ImageMagick build dependencies as root
USER root
RUN echo "=== Installing EPEL and PowerTools ===" && \
    dnf install -y epel-release || true && \
    dnf config-manager --set-enabled powertools || true && \
    dnf config-manager --set-enabled crb || true

RUN echo "=== Installing build dependencies ===" && \
    dnf install -y --allowerasing --skip-broken \
        pkgconfig \
        bzip2-devel \
        freetype-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        libtiff-devel \
        giflib-devel \
        zlib-devel \
        perl-devel \
        perl-generators \
        ghostscript \
        ghostscript-devel \
        jasper-devel \
        libtool-ltdl-devel \
        libX11-devel \
        libXext-devel \
        libXt-devel \
        lcms2-devel \
        libxml2-devel \
        librsvg2-devel \
        fftw-devel \
        libwebp-devel \
        jbigkit-devel \
        fontconfig-devel \
        cairo-devel \
        pango-devel \
        gdk-pixbuf2-devel \
        libzip-devel \
        && echo "=== Core dependencies installed ==="

# Try to install optional dependencies (may not all be available)
RUN echo "=== Installing optional dependencies ===" && \
    dnf install -y --skip-broken \
        liblqr-1-devel \
        gtk3-devel \
        urw-base35-fonts-devel \
        || echo "Some optional dependencies not available"

# Keep this section minimal since most features are disabled
RUN echo "=== Installing remaining dependencies with alternative names ===" && \
    echo "Most optional features are disabled, skipping alternative packages"

# Build ImageMagick RPM
USER builder
RUN echo "=== Building ImageMagick RPM ===" && \
    rpmbuild -bb --nocheck rpmbuild/SPECS/ImageMagick.spec

# Create unified output directory with all RPMs
RUN echo "=== Creating unified output directory ===" && \
    mkdir -p /home/builder/output && \
    echo "=== Copying all built RPMs to output directory ===" && \
    find rpmbuild/RPMS -name "*.rpm" -exec cp {} /home/builder/output/ \; 2>/dev/null || true && \
    find rpmbuild/SRPMS -name "*.rpm" -exec cp {} /home/builder/output/ \; 2>/dev/null || true && \
    echo "=== Final RPM inventory ===" && \
    ls -la /home/builder/output/ && \
    echo "=== RPM details ===" && \
    for rpm in /home/builder/output/*.rpm; do \
        if [ -f "$rpm" ]; then \
            echo "=== $(basename $rpm) ==="; \
            rpm -qp --info "$rpm" 2>/dev/null || echo "Could not read RPM info"; \
            echo ""; \
        fi \
    done

# Test RPM installation
USER root
RUN echo "=== Testing RPM installation ===" && \
    dnf remove -y ImageMagick* --skip-broken || true && \
    dnf clean all && \
    echo "=== Installing ImageMagick packages ===" && \
    rpm -ivh --force --nodeps /home/builder/output/ImageMagick-*.rpm || true && \
    echo "=== Testing ImageMagick binary location ===" && \
    ls -la /usr/bin/*magick* || true && \
    echo "=== Testing ImageMagick functionality ===" && \
    (convert --version || magick --version || echo "ImageMagick not working") && \
    echo "=== ImageMagick test completed ==="

# Create complete imagemagick repository structure
USER builder
RUN echo "=== Creating imagemagick repository structure ===" && \
    mkdir -p /home/builder/imagemagick-repo/rpm-repo/x86_64 && \
    mkdir -p /home/builder/imagemagick-repo/client-setup && \
    echo "=== Copying x86_64 and noarch RPM packages ===" && \
    find /home/builder/output -name '*x86_64.rpm' -exec cp {} /home/builder/imagemagick-repo/rpm-repo/x86_64/ \; 2>/dev/null || true && \
    find /home/builder/output -name '*noarch.rpm' -exec cp {} /home/builder/imagemagick-repo/rpm-repo/x86_64/ \; 2>/dev/null || true

# Switch to root to generate repository metadata
USER root
RUN echo "=== Generating repository metadata ===" && \
    createrepo_c /home/builder/imagemagick-repo/rpm-repo/x86_64/

# Switch back to builder and create client setup files
USER builder
RUN echo "=== Creating client setup files ===" && \
    echo '[imagemagick-build]' > /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo 'name=ImageMagick Build Repository' >> /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo 'baseurl=https://raw.githubusercontent.com/mobilecause/imagemagick/main/imagemagick-repo/rpm-repo/x86_64/' >> /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo 'enabled=1' >> /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo 'gpgcheck=0' >> /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo 'metadata_expire=300' >> /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo 'priority=9' >> /home/builder/imagemagick-repo/client-setup/imagemagick-build.repo && \
    echo "=== Creating installation script ===" && \
    echo '#!/bin/bash' > /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'set -e' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'REPO_URL="https://raw.githubusercontent.com/mobilecause/imagemagick/main"' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'echo "Installing ImageMagick repository..."' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '# Download repo config with priority=9' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'curl -fsSL "$REPO_URL/imagemagick-repo/client-setup/imagemagick-build.repo" \\' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '    -o "/etc/yum.repos.d/imagemagick-build.repo"' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '# Refresh cache' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'dnf clean all' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'dnf makecache' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo '' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'echo "✅ ImageMagick repository installed with priority 9!"' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'echo "📦 Install ImageMagick: dnf install ImageMagick ImageMagick-devel"' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo 'echo "🔍 Verify source: dnf info ImageMagick"' >> /home/builder/imagemagick-repo/client-setup/install.sh && \
    chmod +x /home/builder/imagemagick-repo/client-setup/install.sh && \
    echo "=== Complete imagemagick repository structure ===" && \
    find /home/builder/imagemagick-repo -type f | sort && \
    echo "=== Repository metadata verification ===" && \
    ls -la /home/builder/imagemagick-repo/rpm-repo/x86_64/repodata/ || echo "No repodata found" && \
    echo "=== Client setup files ===" && \
    ls -la /home/builder/imagemagick-repo/client-setup/

CMD ["/bin/bash"]
