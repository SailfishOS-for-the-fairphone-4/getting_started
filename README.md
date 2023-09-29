# Introduction

Welcome to the port of SailfishOS for the fairphone 4.

This repository serves as an overview as to how everything fits together and how to get started in building the build environment and how to make your first changes.

## Build Overview

To build SailfishOS for the Fairphone 4, there are 4 global steps which are further explained below.

1. Setting up the develop/build environment (SDK's)
1. Sourcing and Building relevant bits of your chosen Android base (LineageOS 18.1)
1. Packaging/building SailfishOS (SailfishOS 4.5.0.18)
1. Flashing SailfishOS

## Overview of the different systems

There are a number of different systems you'll be working with. This section serves as an overview of those systems, along with a short description of what they do and what they are used for.

This section is simply an overview, a lot of information is sourced from [the sailfish HADK porting guide](https://docs.sailfishos.org/Develop/HADK/).

### Lineage OS

A lot of mobile phones run android. Unfortunately, most operating systems based on android are closed source and use google's proprietary implementation.

Lineage OS is a free & open source operating system base. It contains the android base, along with the device drivers needed for the operating system.

### Sailfish OS

Sailfish OS is the higher-level operating system which runs on top of the Lineage OS base. It handles the user interaction and the user interface.

### Hybris

Hybris, or libhybris, is a compatibility layer for linux-based systems which enables you to run software that is written for android. This is mainly android libraries and device drivers.

So, hybris is what allows android drivers to run on our linux backend.

### SDK's

In this implementation, we use 2 SDK's which you need to launch seperately in your shell.

These SDK's are needed to build specific parts of the operating system, described below.

#### Platform SDK

The platform SDK is a development environment that includes build tools, like cross compilers, an emulated root filesystem(containing necessary drivers and programs for booting) and device-specific headers and libraries. It is used to build the following parts of the operating system.

- RPM Packages
- Hardware Middleware(Like PulseAudio)

This is software that runs on the mobile phone, but isn't directly part of the kernel.

#### HA Build SDK

The HA Build SDK is mainly used to build the kernel and other low-level systems. It is basically a minimalistic ubuntu chroot, which are used to build android sources. It allows you to build the following parts.

- The kernel
- A modifiable [initrd file](https://www.kernel.org/doc/html/latest/admin-guide/initrd.html). In short: an initrd is an minimalistic root filesystem used in booting. It contains drivers, necessary programs and other stuff that is required to boot your operaring system.
- The hybris boot and recovery images (containing the kernel and custom inird)
- A base /system/ directory
- Modified android parts for libhybris and sailfish os

So this basically allows you to build the lower-levels of the operating system.
## Requirements
### Host Device
- Minimal **Linux x86 64-bit** installation
- ~200gb of storage
- Preferably 16gb of ram

### To-Be-Installed Packages
- curl
- git
 
# Table of Contents
- [Introduction](#introduction)
  - [Requirements](#requirements)
    - [Host Device](#host-device)
    - [To-Be-Installed Packages](#to-be-installed-packages)
- [Table of Contents](#table-of-contents)
- [Setting up the SDK’S](#setting-up-the-sdks)
  - [Setting up the Environment Variables](#setting-up-the-environment-variables)
  - [Setup the Platform SDK](#setup-the-platform-sdk)
  - [Setup the Android build Environment](#setup-the-android-build-environment)
  - [Install Tools](#install-tools)
- [Sourcing and Building relevant bits of your chosen Android base](#sourcing-and-building-relevant-bits-of-your-chosen-android-base)
  - [Sourcing the Android Base](#sourcing-the-android-base)
  - [Syncing the Android Base](#syncing-the-android-base)
  - [Patching the Android base](#patching-the-android-base)
  - [Building boot and recovery image](#building-boot-and-recovery-image)
  - [Configuring the built kernel](#configuring-the-built-kernel)
- [Packaging and building SailfishOS](#packaging-and-building-sailfishos)
  - [Install SDK-targets and SDK-tooling](#install-sdk-targets-and-sdk-tooling)
  - [Cloning the "standard" configurations](#cloning-the-standard-configurations)
  - [Building middleware packages](#building-middleware-packages)
      - [Android Dynamic Partitions](#android-dynamic-partitions)
      - [Hidl Audio Fix](#hidl-audio-fix)
      - [Fingerprint deamon](#fingerprint-deamon)
  - [Package SailfishOS](#package-sailfishos)
- [Flashing SailfishOS](#flashing-sailfishos)
  - [TWRP](#twrp)
  - [Fastboot and ADB](#fastboot-and-adb)
  - [Flashing](#flashing)
- [Known Issues](#known-issues)
    - [Current limit reached with speaker](#current-limit-reached-with-speaker)
    - [Encryption](#encryption)
    - [Failed startup](#failed-startup)
    - [No splashcreen](#no-splashcreen)
    - [Earpiece microphone bug](#earpiece-microphone-bug)
    - [Mobile network does not work](#mobile-network-does-not-work)
    - [E-sim not supported by Sailfish OS and is therefore turned off by default](#e-sim-not-supported-by-sailfish-os-and-is-therefore-turned-off-by-default)

-----
# Setting up the SDK’S  
To mark the environment the user is currently working from, the notation marked below is used:
```
<environment> $
```  
Environment options used in this project:
* HOST $
* PLATFORM_SDK $
* HABUILD_SDK $

## Setting up the Environment Variables
Before the installation of the Sailfish OS platform SDK and the HABUILD SDK (android), the environment variables need to be set to define the phone's properties. This is done by creating a new file (.hadk.env) containing the commands to create the variables.

Additionaly the PS1(now your promt in the terminal) is changed to the environment of the device.
Finaly the file is executed setting the environment variables.

```
HOST $

cat << 'EOF' > $HOME/.hadk.env
export ANDROID_ROOT="$HOME/hadk"
export VENDOR="fairphone"
export DEVICE="FP4"
export PORT_ARCH="aarch64"
EOF

cat << 'EOF' >> $HOME/.mersdkubu.profile
function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
export PS1="HABUILD_SDK [\${DEVICE}] $PS1"
hadk
EOF
```  

## Setup the Platform SDK
Using the code segment below the PLATFORM_SDK environment will be created. The most recent version of Sailfish OS is downloaded, extracted, initialized and finaly the environment is switched to the new PLATFORM_SDK $ evironment.

During this proces the alias ```sfossdk``` is created and points to a script called ```sdk-chroot``` within the Platform SDK chroot environment. This script is used to launch the Platform SDK chroot environment. The final step of this code block is executing the alias sfossdk. 

To enter the Platform SDK environment in a later stage run ```sfossdk```.
The terminal will display **PlatformSDK \<name-of-machine>\ ~$** when you succesfully entered the environment.
To exit the environment type: ```CTRL+D``` or ```exit```  

```
HOST $

export PLATFORM_SDK_ROOT=/srv/sailfishos
curl -k -O https://releases.sailfishos.org/sdk/installers/latest/Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2
sudo mkdir -p $PLATFORM_SDK_ROOT/sdks/sfossdk
sudo tar --numeric-owner -p -xjf Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2 -C $PLATFORM_SDK_ROOT/sdks/sfossdk

echo "export PLATFORM_SDK_ROOT=$PLATFORM_SDK_ROOT" >> ~/.bashrc

cat <<'EOF' >> ~/.bashrc
alias sfossdk=$PLATFORM_SDK_ROOT/sdks/sfossdk/sdk-chroot
if [[ $SAILFISH_SDK ]]; then
  PS1="PlatformSDK $PS1"
  [ -d /etc/bash_completion.d ] && for i in /etc/bash_completion.d/*;do . $i;done
  
  function hadk() { source $HOME/.hadk.env;
  echo "Env setup for $DEVICE"; }
  hadk
fi
EOF

source ~/.bashrc
sfossdk
```

## Setup the Android build Environment
The next step is to set up the HABUILD enviroment. Usinge codeblock below we will donwload, unpack, initialize and switch to the new HABUILD enviroment.

To enter the HABUILD environment in a later stage run ```ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu```.  
To confirm you succesfully entered the HABUILD enviroment, the terminal should display: **HABUILD[FP4] \<name-of-machine\> ~$**
To exit this environment:  ```CTRL+D``` or ```exit```  

```
PLATFORM_SDK $

TARBALL=ubuntu-focal-20210531-android-rootfs.tar.bz2
curl -O https://releases.sailfishos.org/ubu/$TARBALL
UBUNTU_CHROOT=$PLATFORM_SDK_ROOT/sdks/ubuntu
sudo mkdir -p $UBUNTU_CHROOT
sudo tar --numeric-owner -xjf $TARBALL -C $UBUNTU_CHROOT

# ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu
```

## Install Tools
Finaly to coninue the setup we need to install the packages ```android-tools-hadk```, ```kmod``` and ```createrepo_c```. Make sure you run these commmands from the **PLATFORM_SDK** environment!


```
PLATFORM_SDK $

sudo zypper in android-tools-hadk kmod createrepo_c
```


Using the code block below the following repo is downloaded and saved in the user bin folder. This repo is used to manage smaller repo's stored in different locations. Using this tool all repos can be pulled at the same time.

Finaly run ```source $HOME/.profile``` to update the environment and 'apply' all changes made. Doing so will ensure that ~/bin is included in the path variable.

```
PLATFORM_SDK $

mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
source $HOME/.profile
```
Great! Both SDK's are now set up!  
  
-----
# Sourcing and Building relevant bits of your chosen Android base
## Sourcing the Android Base

In order to continue (and use the the Android "repo" command), we need to setup Git with some basic confguration:
```
HABUILD_SDK $

git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global color.ui "auto"
```

After configuring Git, we can start sourcing the Android base. First we need to make a new folder this will be made by using the $ANDROID_ROOT variable. The -p ensures that the entire directory path specified by $ANDROID_ROOT is created. 

The **`$`ANDROID_ROOT** variable stands for **`$`HOME/hadk**.

Then we need to give the user access to this folder and everything within. We change the directory to $ANDROID_ROOT. We use ```repo init``` to initialize the repository we are going to use:
```
HABUILD_SDK $

sudo mkdir -p $ANDROID_ROOT
sudo chown -R $USER $ANDROID_ROOT
cd $ANDROID_ROOT
repo init -u https://www.github.com/Sailfishos-for-the-fairphone-4/android.git -b hybris-18.1
```
This creates a **hidden** "repo" folder (in $ANDROID_ROOT) The repository that is initialised is a fork of the branch [hybris-18.1](https://github.com/mer-hybris/android/tree/hybris-18.1) on the my-hybris android repo. In the "Manifests" folder there are `.xml` files which are used to configure the paths to the source of the Android base. This folder is divided in three (manifest)-files: 
* snippets/lineage.xml  (LineageOS specific configurations)
* default.xml           (AOSP specific configurations)
* $DEVICE.xml           (of FP4.xml, Fairphone 4 specific configurations)

We need to copy the $DEVICE.xml file to a new directory: `local_manifests`.
In this instance the filename is FP4.xml. First we need to make a new folder and then we copy the FP4.xml in that new folder.

```
HABUILD_SDK $

mkdir -p $ANDROID_ROOT/.repo/local_manifests && cp $ANDROID_ROOT/.repo/manifests/FP4.xml $ANDROID_ROOT/.repo/local_manifests/FP4.xml
```
Now we are ready to "sync and build" the repo's that are configured in the manifest files.

## Syncing the Android Base
To sync all the configured repositories, we run the next command:
```
HABUILD_SDK $

repo sync --fetch-submodules
```
OR  
  
**Errors while running `repo sync --fetch-submodules`**
*error: Cannot fetch . . . (GitError: –force-sync not enabled; cannot overwrite a local work tree.*, usually
happens if repo sync --fetch-submodules gets interrupted. It is a bug of the repo tool. Ensure
all your changes have been safely stowed (check with repo status), and then workaround by:
```
HABUILD_SDK $

repo sync --force-sync
```

The expected disk usage for the source tree after sync is **~120 GB**. Depending on your connection, this might take some time. In the meantime, you could make yourself familiar with the rest of this guide :)  
  
  
## Patching the Android base
We do not need the complete Android base for SailfishOS. Mer-Hybris provides the [hybris-patches repo](https://github.com/mer-hybris/hybris-patches/tree/e7fac67471028463d9eaaced51f13f40a86262f6) which patch the (already sourced) Android base.
```
HABUILD_SDK $

cd $ANDROID_ROOT
./hybris-patches/apply-patches.sh --mb
```
Because we use a custom configurations, we removed the "Etar" repository from the configuration. Because of this, we need to change the "CalendarTests" (used for LineageOS/Etar Calendar) to "CalendarCommonTests" (used for AOSP calendar).

The sed command is used to perform text transformations on an input file or stream. The -i option tells ```sed``` to edit the file in place.

"s/CalendarTests/CalendarCommonTests/": This is a sed script that specifies what text transformation should be performed. It uses the s command, which stands for "substitute." It searches for the text "CalendarTests" in the input file and replaces it with "CalendarCommonTests."

platform_testing/build/tasks/tests/platform_test_list.mk: This is the path to the file that you want to perform the substitution on.

```
$ HABUILD

cd $ANDROID_ROOT
sed  -i "s/CalendarTests/CalendarCommonTests/" platform_testing/build/tasks/tests/platform_test_list.mk
```  

We are done configuring the Android base!  
We can continue building the relevant bits of the Android base.  

## Building boot and recovery image
First we change directory to the $ANDROID_ROOT.

source build/envsetup.sh:
source: This command is used to execute the commands in the specified script in the current shell session.
build/envsetup.sh: This script is used to set up environment variables and functions needed for building Android.

breakfast $DEVICE:
breakfast is a command used to configure the build for a specific device. (Used in LineageOS projects)

$DEVICE: This is a variable that contains the name of the Android device you want to build for. Running this command selects the device configuration, so subsequent build commands know what to target.

make -j$(nproc --all) hybris-hal droidmedia:

make: This is a build automation tool used to compile and build software projects.

-j$(nproc --all): This part specifies the number of CPU cores to use for parallel compilation. nproc --all is used to determine the number of available CPU cores, and -j is followed by that number to enable parallel compilation, which can significantly speed up the build process by utilizing multiple CPU cores.

hybris-hal and droidmedia: These are build targets specific to the Android project you're working on. Make is instructed to build these specific components. "hybris-hal" refers to a component related to the hardware abstraction layer (HAL), and "droidmedia" is related to media handling in Android.

Now we are ready to start building everything we sourced and synced so far:
```
HABUILD_SDK $

cd $ANDROID_ROOT
source build/envsetup.sh
breakfast $DEVICE
make -j$(nproc --all) hybris-hal droidmedia
```

This command will take a long time. This preferably runs with 16GB of RAM and and takes around 60GB of storage to complete the build.

## Configuring the built kernel 
After building previous process succesfully completed, we need to check wether the kernel configurations are correct.
The purpose of running this command is to use the mer_verify_kernel_config script to compare the contents of the three specified kernel configuration files. The script checks for any differences or inconsistencies between these configurations, which can be useful for ensuring that the kernel configuration is correct and consistent before building the kernel for the FairPhone.
```
HABUILD_SDK $

cd $ANDROID_ROOT
hybris/mer-kernel-check/mer_verify_kernel_config ./out/target/product/FP4/obj/DTBO_OBJ/.config ./out/target/product/FP4/obj/DTB_OBJ/.config ./out/target/product/FP4/obj/KERNEL_OBJ/.config
```
In case of errors; fix and recompile. Warnings can be fixed later.
Fixes need te be made in ```$ANDROID_ROOT/kernel/fairphone/sm7225/arch/arm64/configs/lineage_FP4_defconfig```  

**Important: Don't forget to commit changes to prevent the dirty flag** 
```
HABUILD_SDK $

cd $ANDROID_ROOT/kernel/fairphone/*/
git add . 
git commit "Changed some kernel flags."
```

-----
# Packaging and building SailfishOS
## Install SDK-targets and SDK-tooling
Now that everything is synced and built, we are ready to install the remaining platform sdk-tools.
First the SDK tool for the Sailfish_OS-4.5.8.18 will be installed, You will always install SDK tooling before SDK targets that depends on that tooling. Note that while SDK targets are target-cpu specific, SDK toolings are always i486 which is the only supported host platform.

```
PLATFORM_SDK $

sdk-assistant create SailfishOS-4.5.0.18 https://releases.sailfishos.org/sdk/targets/Sailfish_OS-4.5.0.18-Sailfish_SDK_Tooling-i486.tar.7z
sdk-assistant create $VENDOR-$DEVICE-$PORT_ARCH https://releases.sailfishos.org/sdk/targets/Sailfish_OS-4.5.0.18-Sailfish_SDK_Target-aarch64.tar.7z
```

## Cloning the "standard" configurations
To install the OS we are using rpm (package manager for Linux, comparable to npm for javascript and pip for python).
Before we can build the package we have to configure the rpm settings. To do that, we need to clone the repositories containing the rpm-configuration specific for the FP4. These also contains the configuration for when building the HAL.
```
PLATFORM_SDK $

cd $ANDROID_ROOT
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-hal-device-FP4.git rpm
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-configs-FP4.git hybris/droid-configs
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-hal-version-FP4.git hybris/droid-hal-version-FP4
git clone --recurse-submodules git@github.com:Sailfishos-for-the-fairphone-4/hybris-installer.git hybris/hybris-installer/
```  

## Building middleware packages
#### Android Dynamic Partitions
Allows mounting Android Dynamic Partitions files on Linux. Dynamic partitions are a userspace partitioning system for Android. Using this partitioning system, you can create, resize, or destroy partitions during over-the-air (OTA) updates. With dynamic partitions, vendors no longer have to worry about the individual sizes of partitions such as system, vendor, and product. Instead, the device allocates a super partition, and sub-partitions can be sized dynamically within it.
```
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/parse-android-dynparts.git hybris/parse-android-dynparts
rpm/dhd/helpers/build_packages.sh --build=hybris/parse-android-dynparts -s rpm/parse-android-dynparts.spec
```  

#### Hidl Audio Fix
```
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/hidl_audio.git hybris/mw/hidl_audio
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/hidl_audio -s rpm/hidl-audio.spec
```  

#### Fingerprint deamon
implements the DBUS API of the Jolla sailfish-fpd packge to add fingerprint support to this port. first the build enviroment is configured using envsetup.sh. Then breakfast (commonly used for Android custom ROM development) is used to prepare the build for the specific device. After the preparation, make is used to compile the software after which it will use build_package.sh to build the package.
```
HABUILD $

cd $ANDROID_ROOT
git clone https://github.com/b100dian/fake_crypt.git hybris/mw/fake_crypt --branch keymaster41
git clone https://github.com/sailfishos-open/sailfish-fpd-community.git hybris/mw/sailfish-fpd-community

source build/envsetup.sh
breakfast $DEVICE
make libbiometry_fp_api fake_crypt
```

```
PLATFORM_SDK $
hybris/mw/sailfish-fpd-community/rpm/copy-hal.sh
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community
```

## Package SailfishOS
We use the ```build_packages.sh``` script in the ```$ANDROID_ROOT/rpm/dhd/helpers/``` to package SailfishOS. The packages are built by using the diffrent flags after which it will be build into an image using the --mic flag. We could do this either by:  

Building everything at once:
```
PLATFORM_SDK $

cd $ANDROID_ROOT
export RELEASE=4.5.0.18
rpm/dhd/helpers/build_packages.sh 
```
OR  
Build packages seperatly:
```
rpm/dhd/helpers/build_packages.sh --droid-hal
rpm/dhd/helpers/build_packages.sh --configs
rpm/dhd/helpers/build_packages.sh --mw
rpm/dhd/helpers/build_packages.sh --gg
rpm/dhd/helpers/build_packages.sh --version
export RELEASE=4.5.0.18
rpm/dhd/helpers/build_packages.sh --mic
```


# Flashing SailfishOS

## TWRP
TWRP (Team Win Recovery Project) is a custom recovery image for Android devices, which is used to perform various maintenance and recovery tasks on the device. TWRP is a powerful tool for advanced Android users who want to perform customizations and maintenance on their device. 

We need TWRP to flash the generated .zip and perform various formatting on the phone.

## Fastboot and ADB
Fastboot is a protocol used by Android devices that allows users to flash firmware or install custom software onto the device. It is a tool included as part of the Android SDK (Software Development Kit) and typically used with the ADB (Android Debug Bridge) tool. We need Fastboot to flash the genrated hybris-boot.img. 

ADB (Android Debug Bridge) is a command-line tool that is part of the Android SDK (Software Development Kit). It allows developers and advanced users to communicate with an Android device over a USB-connection and execute various commands on the device. We need ADB to push generated (.zip) files to the phone.

We can download these tools from the official [LineageOS website](https://wiki.lineageos.org/adb_fastboot_guide) manually. Make sure you add the destination of these tool in the $PATH variable. 
If you don't want to bother with this step and use Linux/Ubuntu. You can use ```sudo apt install fastboot adb```. 

## Flashing
1. Generate the .zip files, corresponding to the SailfishOS rootfs.
2. Flash TWRP ( [recovery.img](https://sourceforge.net/projects/sailfishos-rom-for-fairphone-4/files/recovery.img/download) ) to the phone 
    * In fastboot/bootloader:
        * ```fastboot flash recovery_a <twrp-recovery-name>.img && fastboot flash recovery_b <twrp-recovery-name>.img ```
    * Enter TWRP by navigating to the ```Recovery Mode``` in Fastboot/bootloader
3. In TWRP
    * Navigate to ```wipe``` > ```Format Data``` and type "yes" to format data.
    * Navigate to ```mount``` and enable the checkbox ```system```
4. With ADB from the host-device (laptop/computer).
    * Push the generated .zip file (containing SailfishOS rootfs) to the externel_sd of the Fairphone 4:
        * ```adb push <file-to-push> external_sd```
5. In TWRP
    * Navigate to ```Install``` and select the pushed zip in the previous step and enter ```Install zip``` 
6. After installing SailfishOS on the phone in TWRP. ```Reboot``` to ```fastboot/bootloader```.
7. In Fastboot/bootloader:
    * Flash the generated hybris-boot.img:
        * ```fastboot flash boot_a <file-name>.img && fastboot flash boot_b <file-name>.img```
8. In fastboot/bootloader:
    * Start the device.

To prevent confusion, we flash both partitions (_a and _b) of the recovery and boot.


# Known Issues
### Current limit reached with speaker
If the volume is set to 100% and you play a loud audio, there is a current peak where it reaches its limit and the Fairphone will crash. You then need to simply boot, and everything will work again. (This is replicable when playing the yolla remix ringtone at 100% volume)

### Encryption
There is no encryption.

### Failed startup
When the phone takes longer than 60 seconds or the backlight turns off, the phone has failed to startup. In this state, you can only use the USB-interface. If this also doens't work, then you can only reboot or flash a new image. This issue rarely occurs.

### No splashcreen
During startup, there is no splashscreen displayed.

### Earpiece microphone bug
When you're on a phone call. The earpiece microphone does not work. To fix this, toggle speaker mode on and off. Afterwards it works like normal. (THIS IS NEEDED FOR EVERY PHONE CALL)

### Mobile network does not work
Mobile network does not work in Sailfish version 4.5.0.18. In the newest version announced here: [[Release notes] Struven ketju 4.5.0.19](https://forum.sailfishos.org/t/release-notes-struven-ketju-4-5-0-19/15078). It is stated there has been a fix for IPv6-only mobile networks. Currently, there are no new latest toolings and targets availible for Sailfish verion 4.5.0.19 yet. see: [Index of /sdk/targets/](https://releases.sailfishos.org/sdk/targets/)

### E-sim not supported by Sailfish OS and is therefore turned off by default
