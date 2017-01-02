package main

import (
	"log"
	"os"
	"os/exec"
	"syscall"
)

func crossBuildStart() {
	err := os.Rename("/bin/sh", "/bin/sh.real")
	if err != nil {
		log.Fatal(err)
	}
	err = os.Link("/usr/local/bin/docker-build-aarch64", "/bin/sh")
	if err != nil {
		log.Fatal(err)
	}
}

func crossBuildEnd() {
	err := os.Remove("/bin/sh")
	if err != nil {
		log.Fatal(err)
	}
	err = os.Rename("/bin/sh.real", "/bin/sh")
	if err != nil {
		log.Fatal(err)
	}
}

func runShell() error {
	cmd := exec.Command("/usr/bin/qemu-aarch64-static", append([]string{"-execve", "-0", "/bin/sh", "/bin/sh"}, os.Args[1:]...)...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	switch os.Args[0] {
	case "docker-build-start":
		crossBuildStart()
	case "docker-build-end":
		crossBuildEnd()
	case "/bin/sh":
		code := 0
		crossBuildEnd()

		if err := runShell(); err != nil {
			code = 1
			if exiterr, ok := err.(*exec.ExitError); ok {
				if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
					code = status.ExitStatus()
				}
			}
		}

		crossBuildStart()

		os.Exit(code)
	}
}
