# docker-nix-builder

## Usage

```bash
# Configure trusted user and register Nix remote builder
$ sudo tee -a /etc/nix/nix.conf > /dev/null <<EOF
extra-trusted-users = $USER
builders = $HOME/.local/state/docker-nix-builder/machines
EOF

# Configure Nix remote builder SSH host
$ sudo tee -a ~root/.ssh/config > /dev/null <<EOF
Host docker-nix-builder-*
    HostName 127.0.0.1
    Port 20022
    ControlMaster auto
    ControlPath ~/.ssh/master-%r@%n:%p
    ControlPersist 1m
    StrictHostKeyChecking no
EOF

# a) Start docker-nix-builder based on linux binaries from the binary cache
# Quick to build, but not reproducible from source on Darwin
$ nix run github:szlend/docker-nix-builder#docker-nix-builder

# b) Start docker-nix-builder based on cross-compiled linux binaries
# Very slow to build, but reproducible from source on Darwin
$ nix run github:szlend/docker-nix-builder#docker-nix-builder-cross

# Build `hello` for `aarch64-linux`
$ nix build -L github:szlend/docker-nix-builder#legacyPackages.aarch64-linux.test-hello
```
