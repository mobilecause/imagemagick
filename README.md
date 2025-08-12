# ImageMagick RPM Builder

This repository provides a Docker-based build system for creating ImageMagick RPMs that can be distributed via a custom repository.

## Overview

This build system:
- Creates ImageMagick RPMs from source using Amazon Linux base image
- Packages them into a distributable repository structure
- Provides easy installation scripts for client systems
- Uses GitHub Actions for automated builds

## Repository Structure

```
├── Dockerfile                 # Docker build file for ImageMagick
├── ImageMagick.spec           # RPM spec file for ImageMagick
├── ImageMagick.keyring        # GPG keyring for verification
├── sources                    # Source checksums file
├── test-build-simple.sh       # Local build test script
└── .github/workflows/
    └── build-imagemagick-simple.yml  # GitHub Actions workflow
```

## Building Locally

### Prerequisites
- Docker installed and running
- Git

### Build Steps

1. Clone this repository:
   ```bash
   git clone https://github.com/mobilecause/imagemagick.git
   cd imagemagick
   ```

2. Build the Docker image:
   ```bash
   docker build -f Dockerfile -t imagemagick-builder .
   ```

3. Extract the built RPMs:
   ```bash
   mkdir -p output
   docker run --rm -v $(pwd)/output:/output imagemagick-builder bash -c "
     cp /home/builder/output/*.rpm /output/ 2>/dev/null || true
     chown -R $(id -u):$(id -g) /output/
   "
   ```

4. Built RPMs will be available in the `output/` directory.

### Quick Test Build

For a quick local test, you can use the provided test script:

```bash
./test-build-simple.sh
```

This script automates the Docker build and extraction process.

## Using GitHub Actions

The repository includes a GitHub Actions workflow that automatically builds ImageMagick RPMs.

### Trigger a Build

1. Go to the "Actions" tab in your GitHub repository
2. Select "Build ImageMagick RPM (Simple)"
3. Click "Run workflow"

### Download Built Artifacts

After the workflow completes:
1. Go to the workflow run
2. Download the artifacts:
   - `imagemagick-complete-x86_64`: Complete repository structure
   - `imagemagick-x86_64-rpms`: Individual RPM files

## Installing ImageMagick from Built Repository

### Quick Installation

If you've published the repository structure to GitHub:

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/imagemagick-repo/client-setup/install.sh | sudo bash

# Install ImageMagick
sudo dnf install ImageMagick ImageMagick-devel
```

### Manual Repository Setup

1. Download the repository configuration:
   ```bash
   sudo curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/imagemagick-repo/client-setup/imagemagick-build.repo \
     -o /etc/yum.repos.d/imagemagick-build.repo
   ```

2. Refresh package cache:
   ```bash
   sudo dnf clean all
   sudo dnf makecache
   ```

3. Install ImageMagick:
   ```bash
   sudo dnf install ImageMagick ImageMagick-devel
   ```

### Verify Installation

```bash
# Check version
convert --version
# or
magick --version

# Verify package source
dnf info ImageMagick
```

## ImageMagick Features

The built ImageMagick includes support for:
- JPEG, PNG, TIFF, GIF image formats
- WebP, HEIF (if available)
- SVG via librsvg
- PDF via Ghostscript
- Raw camera formats
- OpenEXR for HDR images
- Various image filters and effects

## Customizing the Build

### Modifying Build Options

Edit `ImageMagick.spec` to:
- Change configure options
- Add/remove dependencies
- Modify install paths
- Add patches

### Adding Dependencies

Update `Dockerfile` to install additional build dependencies:
```dockerfile
RUN dnf install -y your-additional-package-devel
```

## Repository Structure

The built repository follows standard YUM/DNF repository structure:
```
imagemagick-repo/
├── rpm-repo/
│   └── x86_64/
│       ├── repodata/          # Repository metadata
│       └── *.rpm              # RPM packages
└── client-setup/
    ├── imagemagick-build.repo # Repository configuration
    └── install.sh             # Installation script
```

## Troubleshooting

### Build Failures

1. **Missing dependencies**: Check the Docker build logs for missing packages
2. **Spec file issues**: Verify the ImageMagick.spec file syntax
3. **Source download failures**: Ensure the source URLs in the spec file are accessible

### Installation Issues

1. **Repository not found**: Verify the repository URL is accessible
2. **GPG errors**: The repository is configured with `gpgcheck=0` for simplicity
3. **Conflicts**: Remove existing ImageMagick packages before installing

### Common Commands

```bash
# List available ImageMagick packages
dnf list available | grep -i imagemagick

# Remove existing ImageMagick
sudo dnf remove ImageMagick*

# Check repository configuration
dnf repolist | grep imagemagick

# Clean repository cache
sudo dnf clean all && sudo dnf makecache
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Test your changes locally
4. Submit a pull request

## License

This build system follows the ImageMagick license. See the ImageMagick.spec file for details.
