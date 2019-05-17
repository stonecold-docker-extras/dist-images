# busybox-base

#### [busybox-x64-base](https://hub.docker.com/r/forumi0721/busybox-x64-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/busybox-x64-base.svg)](https://microbadger.com/images/forumi0721/busybox-x64-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/busybox-x64-base.svg)](https://microbadger.com/images/forumi0721/busybox-x64-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/busybox-x64-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/busybox-x64-base/)
#### [busybox-aarch64-base](https://hub.docker.com/r/forumi0721/busybox-aarch64-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/busybox-aarch64-base.svg)](https://microbadger.com/images/forumi0721/busybox-aarch64-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/busybox-aarch64-base.svg)](https://microbadger.com/images/forumi0721/busybox-aarch64-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/busybox-aarch64-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/busybox-aarch64-base/)
#### [busybox-armhf-base](https://hub.docker.com/r/forumi0721/busybox-armhf-base/)
[![](https://images.microbadger.com/badges/version/forumi0721/busybox-armhf-base.svg)](https://microbadger.com/images/forumi0721/busybox-armhf-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721/busybox-armhf-base.svg)](https://microbadger.com/images/forumi0721/busybox-armhf-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721/busybox-armhf-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721/busybox-armhf-base/)



----------------------------------------
#### Description

* Distribution : [Busybox](https://busybox.net/)
* Architecture : x64,aarch64,armhf
* Appplication : -



----------------------------------------
#### Run

* x64
```sh
docker run -i -t --rm \
           forumi0721/busybox-aarch64-base:latest
```

* aarch64
```sh
docker run -i -t --rm \
           forumi0721/busybox-aarch64-base:latest
```

* armhf
```sh
docker run -i -t --rm \
           forumi0721/busybox-aarch64-base:latest
```



----------------------------------------
#### Usage

```dockerfile
#for x64
FROM forumi0721/busybox-x64-base:latest
#for aarch64
#FROM forumi0721/busybox-aarch64-base:latest
#for armhf
#FROM forumi0721/busybox-armhf-base:latest

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
* [forumi0721/busybox-x64-base](https://hub.docker.com/r/forumi0721/busybox-x64-base/)
* [forumi0721/busybox-aarch64-base](https://hub.docker.com/r/forumi0721/busybox-aarch64-base/)
* [forumi0721/busybox-armhf-base](https://hub.docker.com/r/forumi0721/busybox-armhf-base/)

