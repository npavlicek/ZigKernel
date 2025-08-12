#!/bin/bash

qemu-system-x86_64 -enable-kvm -cpu host -bios OVMF.fd -net none -serial stdio -m 1G -drive file=./bin/boot.img,if=virtio,format=raw -no-reboot -no-shutdown -S -s 
