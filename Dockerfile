FROM ubuntu:14.04
MAINTAINER Juan Fraire

# Install updates
RUN apt-get update && apt-get upgrade -y
