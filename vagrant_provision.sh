#!/bin/bash

ERLANG_VERSION=20.2.2
ELIXIR_VERSION=1.6.1-1
NODE_VERSION=8

# Note: password is for postgres user "postgres"
POSTGRES_DB_PASS=postgres
POSTGRES_VERSION=9.5

# # Set language and locale
# apt-get install -y language-pack-en
# locale-gen --purge en_GB.UTF-8
# echo "LC_ALL='en_GB.UTF-8'" >> /etc/environment
# dpkg-reconfigure locales

# Repo Stuff

curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Erlang 
wget -q https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
dpkg -i erlang-solutions_1.0_all.deb
rm erlang-solutions_1.0_all.deb

# Node - this also, handily, runs apt-get update for us.
curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | sudo -E bash -

# Install basic packages
# inotify is installed because it's a Phoenix dependency
apt-get install -y \
wget \
git \
unzip \
build-essential \
ntp \
inotify-tools \
nodejs \
imagemagick \
ssh-askpass \
squashfs-tools \
esl-erlang="1:${ERLANG_VERSION}" \
elixir="${ELIXIR_VERSION}"

# Fwup - needed for nerves project.
wget -q https://github.com/fhunleth/fwup/releases/download/v1.0.0/fwup_1.0.0_amd64.deb
dpkg -i fwup_1.0.0_amd64.deb
rm fwup_1.0.0_amd64.deb

# Install local Elixir hex and rebar for the ubuntu user
su - vagrant -c '/usr/local/bin/mix local.hex --force && /usr/local/bin/mix local.rebar --force'

# Nerves project install
su - vagrant -c '/usr/local/bin/mix archive.install hex nerves_bootstrap --force && /usr/local/bin/mix local.nerves --force'
