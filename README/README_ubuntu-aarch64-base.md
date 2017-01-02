# [ubuntu-aarch64-base](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/ubuntu-aarch64-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-aarch64-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/ubuntu-aarch64-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-aarch64-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/ubuntu-aarch64-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/) [![Docker Pulls](https://img.shields.io/docker/pulls/forumi0721/ubuntu-aarch64-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)



----------------------------------------
#### Description
* Distribution : [Ubuntu](https://www.ubuntu.com/)
* Architecture : aarch64
* Base Image   : [forumi0721/ubuntu-aarch64-base](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)
* Appplication : -



----------------------------------------
#### Run
```sh
docker run -i -t --rm \
           forumi0721/ubuntu-aarch64-base:latest
```



----------------------------------------
#### Usage
```dockerfile
FROM forumi0721/ubuntu-aarch64-base:latest

#For cross compile on dockerhub
RUN ["docker-build-start"]

RUN 'build-code'

#For cross compile on dockerhub
RUN ["docker-build-end"]
```


###### Notes
* You can use `docker-install` for install packages.
    - `-r`: Refresh
    - `-u`: Ugrade
    - `-c`: Clean
    - `-d`: Uninstall



----------------------------------------
#### Docker Options
| Option             | Description                                      |
|--------------------|--------------------------------------------------|
| -                  | -                                                |


#### Ports
| Port               | Description                                      |
|--------------------|--------------------------------------------------|
| -                  | -                                                |


#### Volumes
| Volume             | Description                                      |
|--------------------|--------------------------------------------------|
| -                  | -                                                |


#### Environment Variables
| ENV                | Description                                      |
|--------------------|--------------------------------------------------|
| -                  | -                                                |



----------------------------------------
* [forumi0721/ubuntu-x64-base](https://hub.docker.com/r/forumi0721/ubuntu-x64-base/)
* [forumi0721/ubuntu-armhf-base](https://hub.docker.com/r/forumi0721/ubuntu-armhf-base/)
* [forumi0721/ubuntu-aarch64-base](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)

