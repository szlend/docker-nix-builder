#!/usr/bin/env bash
set -eEuo pipefail

image=${DOCKER_NIX_BUILDER_IMAGE?missing}
num_jobs=${DOCKER_NIX_BUILDER_JOBS:-"$(getconf _NPROCESSORS_ONLN)"}

container_name="docker-nix-builder"
volume_name="$container_name-data"
state_dir="${XDG_STATE_HOME:-"$HOME/.local/state"}/$container_name"
server_key="$state_dir/server_id_ed25519"
client_key="$state_dir/client_id_ed25519"
machines_file="$state_dir/machines"
image_file="$state_dir/image"

if ! docker version &> /dev/null; then
  echo "Docker daemon is not running." 2>&1
  exit 1
fi

if docker container inspect "$container_name" &> /dev/null; then
  echo "The nix remote builder container is already running." 2>&1
  exit 1
fi

# Load the nix remote builder docker image
output=$(docker load < "$image")
image_tag=${output#Loaded image: }
echo "Using image $image_tag." 2>&1

mkdir -p "$state_dir"

# Generate server SSH key if it does not exist
if [ ! -f "$server_key" ]; then
  echo "Creating server key ${server_key}." 2>&1
  ssh-keygen -q -t ed25519 -N "" -C "$container_name" -f "$server_key"
fi

# Generate client SSH key if it does not exist
if [ ! -f "$client_key" ]; then
  echo "Creating client key ${client_key}." 2>&1
  ssh-keygen -q -t ed25519 -N "" -C "$container_name" -f "$client_key"
fi

# Delete the Nix builder volume if the previous image is stale
touch "$image_file"
if [ "$(cat "$image_file")" != "$image" ]; then
  echo "Deleting stale nix builder volume..." 2>&1
  docker volume rm "$volume_name" &> /dev/null || true
  echo "$image" > "$image_file"
fi

# Generate Nix remote machine config. A pool of $num_jobs
echo > "$machines_file"
trap 'echo > "$machines_file"' EXIT
for i in $(seq 1 "$num_jobs"); do
  echo "ssh-ng://root@$container_name-$i aarch64-linux,x86_64-linux $client_key 1 1" >> "$machines_file"
done

echo "Starting nix remote builder." 2>&1
docker run --rm -ti --name "$container_name" \
  -p 127.0.0.1:20022:22 \
  -v "$volume_name:/nix" \
  -v "$state_dir:/mnt:ro" \
  "$image_tag"
