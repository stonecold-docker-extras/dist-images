# ubuntu-base

#### [ubuntu-x64-base](https://hub.docker.com/r/forumi0721/ubuntu-x64-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/ubuntu-x64-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-x64-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/ubuntu-x64-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-x64-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/ubuntu-x64-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-x64-base/)
#### [ubuntu-aarch64-base](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/ubuntu-aarch64-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-aarch64-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/ubuntu-aarch64-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-aarch64-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/ubuntu-aarch64-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)
#### [ubuntu-armhf-base](https://hub.docker.com/r/forumi0721/ubuntu-armhf-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/ubuntu-armhf-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-armhf-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/ubuntu-armhf-base.svg)](https://microbadger.com/images/forumi0721/ubuntu-armhf-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/ubuntu-armhf-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-armhf-base/)

#### [ubuntu-x64-base-bionic](https://hub.docker.com/r/forumi0721/ubuntu-x64-base-bionic/)
[![](https://images.microbadger.com/badges/version/forumi0721/ubuntu-x64-base-bionic.svg)](https://microbadger.com/images/forumi0721/ubuntu-x64-base-bionic "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/ubuntu-x64-base-bionic.svg)](https://microbadger.com/images/forumi0721/ubuntu-x64-base-bionic "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/ubuntu-x64-base-bionic.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-x64-base-bionic/)
#### [ubuntu-x64-base-xenial](https://hub.docker.com/r/forumi0721/ubuntu-x64-base-xenial/)
[![](https://images.microbadger.com/badges/version/forumi0721/ubuntu-x64-base-xenial.svg)](https://microbadger.com/images/forumi0721/ubuntu-x64-base-xenial "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/ubuntu-x64-base-xenial.svg)](https://microbadger.com/images/forumi0721/ubuntu-x64-base-xenial "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/ubuntu-x64-base-xenial.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/ubuntu-x64-base-xenial/)



----------------------------------------
#### Description

* Distribution : [Ubuntu](https://www.ubuntu.com/)
* Architecture : x64,aarch64,armhf
* Appplication : -



----------------------------------------
#### Run

* x64
```sh
docker run -i -t --rm \
           forumi0721/ubuntu-aarch64-base:latest
```

* aarch64
```sh
docker run -i -t --rm \
           forumi0721/ubuntu-aarch64-base:latest
```

* armhf
```sh
docker run -i -t --rm \
           forumi0721/ubuntu-aarch64-base:latest
```



----------------------------------------
#### Usage

```dockerfile
#for x64
FROM forumi0721/ubuntu-x64-base:latest
#for aarch64
#FROM forumi0721/ubuntu-aarch64-base:latest
#for armhf
#FROM forumi0721/ubuntu-armhf-base:latest

#For cross compile on dockerhub (aarch64,armhf)
RUN ["docker-build-start"]

RUN 'build-code'

#For cross compile on dockerhub  (aarch64,armhf)
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
* [forumi0721/ubuntu-aarch64-base](https://hub.docker.com/r/forumi0721/ubuntu-aarch64-base/)
* [forumi0721/ubuntu-armhf-base](https://hub.docker.com/r/forumi0721/ubuntu-armhf-base/)
* [forumi0721/ubuntu-x64-base-bionic](https://hub.docker.com/r/forumi0721/ubuntu-x64-base-bionic/)
* [forumi0721/ubuntu-x64-base-xenial](https://hub.docker.com/r/forumi0721/ubuntu-x64-base-xenial/)

