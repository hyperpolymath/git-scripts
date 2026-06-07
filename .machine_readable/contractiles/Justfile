import? "contractile.just"

# Git-Scripts - Justfile
# Build automation and development tasks

# Default target
default:
    just --list

# Build the escript
build:
    mix escript.build

# Run the TUI
run:
    ./script_manager --interactive

# Build and run
build-run:
    just build
    just run

# Run specific tools
wiki-audit:
    ./script_manager --interactive <<< "1\n0\n"

branch-protection:
    ./script_manager --interactive <<< "3\n0\n"

# Cross-launch NQC
nqc:
    /var/mnt/eclipse/repos/nextgen-databases/nqc/nqc-enhanced-launcher.sh --auto

# Cross-launch Invariant Path
invariant-path:
    /var/mnt/eclipse/repos/invariant-path/invariant-path-launcher --auto

# Install desktop integration
install:
    ./git-scripts-launcher --install

# Uninstall desktop integration
uninstall:
    ./git-scripts-launcher --disinteg

# Clean build artifacts
clean:
    rm -rf _build script_manager
    rm -f /tmp/gitscripts-*.log /tmp/gitscripts-*.err

# Run tests
test:
    mix test

# Format code
fmt:
    mix format

# Lint code
lint:
    mix credo

# Show help
help:
    just --list

# Combined workflows
full-build:
    just clean
    just build
    just run