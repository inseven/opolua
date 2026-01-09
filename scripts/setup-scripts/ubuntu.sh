#!/bin/bash

apt-get update -y
apt-get install -y build-essential git
apt-get install -y qt6-base-dev qt6-base-dev-tools qt6-multimedia-dev qt6-5compat-dev
apt-get install -y ruby ruby-bundler
gem install --no-user-install fpm
