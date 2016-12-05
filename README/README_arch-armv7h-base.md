# [arch-armv7h-base](https://hub.docker.com/r/forumi0721archarmv7h/arch-armv7h-base/)
[![](https://images.microbadger.com/badges/version/forumi0721archarmv7h/arch-armv7h-base.svg)](https://microbadger.com/images/forumi0721archarmv7h/arch-armv7h-base "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/forumi0721archarmv7h/arch-armv7h-base.svg)](https://microbadger.com/images/forumi0721archarmv7h/arch-armv7h-base "Get your own image badge on microbadger.com") [![Docker Stars](https://img.shields.io/docker/stars/forumi0721archarmv7h/arch-armv7h-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721archarmv7h/arch-armv7h-base/) [![Docker Pulls](https://img.shields.io/docker/pulls/forumi0721archarmv7h/arch-armv7h-base.svg?style=flat-square)](https://hub.docker.com/r/forumi0721archarmv7h/arch-armv7h-base/)



----------------------------------------
#### Description
* Distribution : [Arch Linux ARM](https://archlinuxarm.org/)
* Architecture : armv7h
* Base Image   : [forumi0721archarmv7h/arch-armv7h-base](https://hub.docker.com/r/forumi0721archarmv7h/arch-armv7h-base/)
* Appplication : -



----------------------------------------
#### Run
```sh
docker run -i -t --rm \
           forumi0721archarmv7h/arch-armv7h-base:latest
```



----------------------------------------
#### Usage
```dockerfile
FROM forumi0721archarmv7h/arch-armv7h-base:latest

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
    - `-y`: Use yaourt



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
* [forumi0721archx64/arch-x64-base](https://hub.docker.com/r/forumi0721archx64/arch-x64-base/)
* [forumi0721archarmv7h/arch-armv7h-base](https://hub.docker.com/r/forumi0721archarmv7h/arch-armv7h-base/)

