# raspi-poky

Building images using raspi-poky offers following features:
* Raspberry pi update using swupdate
* Network configuration adding custom /etc/network/interfaces & /etc/wpa_supplicant.conf
* Layer for custom services with prepared recipe in poky/meta-raspi-app/recipes-core/images/raspi-app-image.bb

## Requirements

Following packages needs to be installed:
```sh
   sudo apt-get install gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat python3 python3-distutils
```

## Build

The repo includes an helper script to build a raspberry pi image. Example command:
```sh
    ./build.sh -M raspberrypi3-64 -D -W -U
```

See all available options:
```sh
    ./build.sh -h
```

## Deployed files

The deploy folder contains .wic (to write raw on a SD card) and .swu (software-update package) files. To update a system, visit http://MACHINE:8080/, where MACHINE is your -M passed variable.
