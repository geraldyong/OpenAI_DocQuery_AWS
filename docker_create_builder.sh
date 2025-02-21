#!/bin/bash

# Create new builder for Linux images.
echo "INFO: Creating docker builder for Linux images"
#docker buildx rm linux
docker buildx create --name linux --driver kubernetes --platform linux/amd64,linux/arm64 --bootstrap

# List out all builders.
echo "INFO: List of all builders"
docker buildx ls
