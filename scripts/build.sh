#!/usr/bin/env bash

set -e
echo "Starting release process..."
cd /opt/build
rm -rf /opt/build/_build/prod/rel/central/releases

echo "Creating release artifact directory..."
mkdir -p /opt/build/rel/artifacts

echo "Installing rebar and hex..."
mix local.rebar --force
mix local.hex --if-missing --force

echo "Fetching project deps..."
mix deps.get

echo "Cleaning and compiling..."
# "If you are using Phoenix, here is where you would run mix phx.digest"
mix phx.digest

echo "Generating release..."
mix release

echo "Creating tarball..."
tar -zcf "/opt/build/rel/artifacts/teiserver.tar.gz" /opt/build/_build/prod

echo "Release generated at rel/artifacts/teiserver.tar.gz"
exit 0