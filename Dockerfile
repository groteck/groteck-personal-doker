FROM ubuntu:14.04
MAINTAINER Juan Fraire

# Install updates
RUN apt-get update && apt-get upgrade -y

# Create and configure user
RUN useradd --create-home -s /bin/bash fray
# User with empty password
RUN passwd fray -d

# Enable passwordless sudo for user
RUN apt-get update && apt-get install -y sudo && apt-get clean
RUN mkdir -p /etc/sudoers.d && echo "fray ALL= NOPASSWD: ALL" > /etc/sudoers.d/fray && chmod 0440 /etc/sudoers.d/fray
