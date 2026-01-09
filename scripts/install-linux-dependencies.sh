#!/bin/bash

echo $USER

sudo apt-get update -y
sudo apt-get install -y build-essential git
sudo apt-get install -y qt6-base-dev qt6-base-dev-tools qt6-multimedia-dev qt6-5compat-dev
sudo apt-get install -y ruby ruby-bundler
sudo gem install --no-user-install fpm
