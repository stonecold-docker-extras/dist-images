# Your base image.
FROM forumi0721/alpine-arm-base:latest

# Your name.
MAINTAINER stonecold <forumi0721@gmail.com>

# If you need some extra files, run copy command.
COPY local/. /usr/local/

# Change image to run arm command
RUN ["docker-build-start"]

# Some command like "apt-get update && apt-get install vim" 
RUN stub....

# Change image to original x64 image
RUN ["docker-build-end"]

# Entrypoint
ENTRYPOINT ["docker-run"]

# Ports
EXPOSE 80/tcp 443/tcp

