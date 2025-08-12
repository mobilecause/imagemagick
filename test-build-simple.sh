#!/bin/bash
set -e

echo "=== ImageMagick Build Test ==="
echo "Testing built ImageMagick RPMs and repository structure"
echo ""

# Main test function
main() {
    local success=true

    echo "Working directory: $(pwd)"
    echo ""

    # Test 1: Check if RPMs were built
    echo "=== Checking Built RPMs ==="
    rpm_count=$(find output -name "*.rpm" 2>/dev/null | wc -l || echo "0")

    if [ "$rpm_count" -gt 0 ]; then
        echo "✅ Found $rpm_count RPM files:"
        for rpm in output/*.rpm; do
            if [ -f "$rpm" ]; then
                echo "  - $(basename $rpm)"

                # Quick RPM validation
                if rpm -qp --info "$rpm" >/dev/null 2>&1; then
                    echo "    ✅ Valid RPM"
                else
                    echo "    ❌ Invalid RPM"
                    success=false
                fi
            fi
        done
    else
        echo "❌ No RPM files found"
        success=false
    fi

    echo ""

    # Test 2: Check repository structure
    echo "=== Checking Repository Structure ==="
    if [ -d "output/imagemagick-repo" ]; then
        echo "✅ Repository directory found"

        # Check for repository metadata
        if [ -f "output/imagemagick-repo/rpm-repo/x86_64/repodata/repomd.xml" ]; then
            echo "✅ Repository metadata exists"
        else
            echo "❌ Repository metadata missing"
            success=false
        fi

        # Check for installation script
        if [ -f "output/imagemagick-repo/client-setup/install.sh" ]; then
            echo "✅ Installation script exists"
            if [ -x "output/imagemagick-repo/client-setup/install.sh" ]; then
                echo "✅ Installation script is executable"
            else
                echo "⚠️  Installation script not executable"
            fi
        else
            echo "❌ Installation script missing"
            success=false
        fi

        # Check for repo config
        if [ -f "output/imagemagick-repo/client-setup/imagemagick-build.repo" ]; then
            echo "✅ Repository config exists"
        else
            echo "❌ Repository config missing"
            success=false
        fi

    else
        echo "❌ Repository structure not found"
        success=false
    fi

    echo ""

    # Test 3: Test ImageMagick if installed
    echo "=== Testing ImageMagick Installation ==="
    if command -v convert >/dev/null 2>&1; then
        echo "✅ convert command available"
        convert --version | head -1

        # Test basic functionality
        if convert -size 100x100 xc:blue test_image.png 2>/dev/null; then
            echo "✅ Basic image creation works"
            rm -f test_image.png
        else
            echo "❌ Basic image creation failed"
            success=false
        fi
    elif command -v magick >/dev/null 2>&1; then
        echo "✅ magick command available"
        magick --version | head -1

        # Test basic functionality
        if magick -size 100x100 xc:red test_image.png 2>/dev/null; then
            echo "✅ Basic image creation works"
            rm -f test_image.png
        else
            echo "❌ Basic image creation failed"
            success=false
        fi
    else
        echo "ℹ️  ImageMagick not installed (install RPMs to test functionality)"
    fi

    echo ""
    echo "=== Test Summary ==="
    if [ "$success" = true ]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ Some tests failed. Check the output above."
        exit 1
    fi
}

# Show usage if requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--help]"
    echo ""
    echo "This script tests the ImageMagick build results:"
    echo "- Validates built RPMs"
    echo "- Checks repository structure"
    echo "- Tests ImageMagick functionality (if installed)"
    echo ""
    echo "Run this after: docker build -t imagemagick-builder . && docker run ..."
    exit 0
fi

# Run main test
main "$@"
