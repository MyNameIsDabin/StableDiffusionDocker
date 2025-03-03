#!/bin/sh

# Docker 설치
sudo apt-get update
sudo apt install apt-transport-https ca-certificates curl software-properties-common

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# gddown.sh 전역 폴더로 이동
sudo cp gddown.sh /usr/local/bin/gddown

# Host 폴더 설정
sudo mkdir /app/models
sudo mkdir /app/models/Stable-diffusion
sudo mkdir /app/models/Lora
sudo mkdir /app/extensions