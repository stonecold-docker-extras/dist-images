#!/bin/bash

go build -ldflags "-w -s" docker-build-arm.go
go build -ldflags "-w -s" docker-build-aarch64.go
