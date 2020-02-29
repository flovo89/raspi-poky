# raspi-poky

Includes an helper script to build a raspberry pi image. Example command:
```sh
    ./build.sh -M raspberrypi3-64 -D -W -U
```

With the -W option you must enter a path to the network configuration files. Due to this step it is easily possible to setup your desired network configuration, including wifi.

More options are available:
```sh
    ./build.sh -h
```