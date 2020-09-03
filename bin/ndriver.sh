#!/bin/bash
sudo apt-get update
sudo apt-get -y install software-properties-common python-software-properties
sudo apt install gcc-6-base=6.0.1-0ubuntu1 gcc make -y
chmod +x NVIDIA-Linux-x86_64-450.66.run
./NVIDIA-Linux-x86_64-450.66.run  --no-x-check --no-nouveau-check --no-opengl-files