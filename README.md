# Introduction

We will be building SailfishOS for the Fairphone 4. In te global scheme of things, there are 4 major steps in this proces:
  1) Setting up the develop/build environment (SDK's) 
  3) Sourcing and Building relevant bits of your chosen Android base (LineageOS 18.1)
  4) Packaging/building SailfishOS (SailfishOS 4.5.0.18)
  5) Flashing SailfishOS

Here is some usefull literature: 
- Official SailfishOS Hardware Adaptation Development Kit [Page](https://docs.sailfishos.org/Develop/HADK/) 
- Unofficial [hadk-hot](https://etherpad.wikimedia.org/p/hadk-hot)  
- The [sfos-porters](https://piggz.co.uk/sailfishos-porters-archive/index.php) archive 
- If you're using [LineageOS](https://wiki.lineageos.org/devices/FP4/) as your Android base  

We are going to try to guide you through it. Goodluck!
  
## Requirements
### Host Device
- Minimal **Linux x86 64-bit** installation
- ~200gb of storage
- Preferably 16gb of ram

### To-Be-Installed Packages
- curl
- git
 
# Table of Contents
- [Setting up the SDK’S](#setting-up-the-sdk-s)
  * [Setting up the Environment Variables](#setting-up-the-environment-variables)
  * [Setup the Platform SDK](#setup-the-platform-sdk)
  * [Setup the Android build Environment](#setup-the-android-build-environment)
  * [Install Tools](#install-tools)
- [Sourcing and Building relevant bits of your chosen Android base](#sourcing-and-building-relevant-bits-of-your-chosen-android-base)
  * [Sourcing the Android Base](#sourcing-the-android-base)
  * [Syncing the Android Base](#syncing-the-android-base)
  * [Patching the Android base](#patching-the-android-base)
  * [Building boot and recovery image](#building-boot-and-recovery-image)
  * [Configuring the built kernel](#configuring-the-built-kernel)
- [Packaging and building SailfishOS](#packaging-and-building-sailfishos)
  * [Install SDK-targets and SDK-tooling](#install-sdk-targets-and-sdk-tooling)
  * [Cloning the "standard" configurations](#cloning-the--standard--configurations)
  * [Building middleware packages](#building-middleware-packages)
      - [Android Dynamic Partitions](#android-dynamic-partitions)
      - [Hidl Audio Fix](#hidl-audio-fix)
      - [Fingerprint deamon (TODO)](#fingerprint-deamon--todo-)
  * [Package SailfishOS](#package-sailfishos)
  
-----
# Setting up the SDK’S  
To mark in which environment we are working, we use the notation showed down below:
```
<environment> $
```  

## Setting up the Environment Variables
Before we can start installing the SDK’s, we need to make sure some environment
variables are written to some files. In our case (Fairhone 4):
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
Now we are going to set up the Platform SDK. With the codeblock down below we will donwload, unpack, initialize and enter the "new" PlatformSDK.

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
Run ```sfossdk``` to enter the Platform SDK.  
To confirm you succesfully entered the Platform SDK, the terminal should show: **PlatformSDK \<name-of-machine\> ~$**  
To exit this environment:  ```CTRL+D``` or ```exit```  

## Setup the Android build Environment
Now we are going to set up the HABUILD enviroment. With the codeblock down below we will donwload, unpack, initialize and enter the "new" HABUILD enviroment.
```
PLATFORM_SDK $

TARBALL=ubuntu-focal-20210531-android-rootfs.tar.bz2
curl -O https://releases.sailfishos.org/ubu/$TARBALL
UBUNTU_CHROOT=$PLATFORM_SDK_ROOT/sdks/ubuntu
sudo mkdir -p $UBUNTU_CHROOT
sudo tar --numeric-owner -xjf $TARBALL -C $UBUNTU_CHROOT

ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu
```
Run ```ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu``` to enter the HABUILD enviroment.  
To confirm you succesfully entered the HABUILD enviroment, the terminal should show: **HABUILD[FP4] \<name-of-machine\> ~$**
To exit this environment:  ```CTRL+D``` or ```exit```  

## Install Tools
We need to install two tools which are not installed by default. Make sure you are in the **PLATFORM_SDK**!

```
PLATFORM_SDK $

sudo zypper in android-tools-hadk kmod createrepo_c
```

```
PLATFORM_SDK $

mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
source $HOME/.profile
```
We run ```source $HOME/.profile``` to update the environment. This makes sure that ~/bin is included in the path variable.


Great! We successfully set up both SDK's!  
  
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

After configuring Git, we can start sourcing the Android base. We use ```repo init``` to initialize the repository we are going to use:
```
HABUILD_SDK $

sudo mkdir -p $ANDROID_ROOT
sudo chown -R $USER $ANDROID_ROOT
cd $ANDROID_ROOT
repo init -u https://www.github.com/Sailfishos-for-the-fairphone-4/android.git -b hybris-18.1
```
This creates a **hidden** "repo" folder (in $ANDROID_ROOT). In the "Manifests" folder there are `.xml` files which are used to configure the paths to the source of the Android base. This folder is divided in three (manifest)-files: 
* snippets/lineage.xml  (LineageOS specific configurations)
* default.xml           (AOSP specific configurations)
* $DEVICE.xml           (of FP4.xml, Fairphone 4 specific configurations)

We need to copy the $DEVICE.xml file to a new directory: `local_manifests`
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
```
$ HABUILD

cd $ANDROID_ROOT
sed  -i "s/CalendarTests/CalendarCommonTests/" platform_testing/build/tasks/tests/platform_test_list.mk
```  

We are done configuring the Android base!  
We can continue building the relevant bits of the Android base.  

## Building boot and recovery image
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
Now that everything is synced and built, we are ready to install the remaining platform sdk-tools
```
PLATFORM_SDK $

sdk-assistant create SailfishOS-4.5.0.18 https://releases.sailfishos.org/sdk/targets/Sailfish_OS-4.5.0.18-Sailfish_SDK_Tooling-i486.tar.7z
sdk-assistant create $VENDOR-$DEVICE-$PORT_ARCH https://releases.sailfishos.org/sdk/targets/Sailfish_OS-4.5.0.18-Sailfish_SDK_Target-aarch64.tar.7z
```

## Cloning the "standard" configurations

Since the targets and tooling work we are ready to set up the rpm-configuration. To do that, we need to clone the repositories containing the FP4 rpm-configuration.
```
PLATFORM_SDK $

cd $ANDROID_ROOT
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-hal-device-FP4.git rpm
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-configs-FP4.git hybris/droid-configs
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-hal-version-FP4.git hybris/droid-hal-version-FP4
git clone --recurse-submodules git@github.com:Sailfishos-for-the-fairphone-4/hybris-installer hybris/hybris-installer/
```  

## Building middleware packages
#### Android Dynamic Partitions
```
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/parse-android-dynparts.git hybris/parse-android-dynparts
rpm/dhd/helpers/build_packages.sh --build=hybris/parse-android-dynparts -s rpm/parse-android-dynparts.spec
```  

#### Hidl Audio Fix
```
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/hidl_audio.git hybris/mw/hidl_audio
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/hidl_audio -s rpm/hidl_audio.spec
```  

#### Fingerprint deamon (TODO)
 
HABUILD
make libbiometry_fp_api 
make fake_crypt

SFOSSDK
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-biometry-fp.spec
OR
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-fake-crypt.spec
or
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community


## Package SailfishOS
We use the ```build_packages.sh``` script in the ```$ANDROID_ROOT/rpm/dhd/helpers/``` to package SailfishOS. We could do this either by:  

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

#### Fingerprint deamon (TODO)
 
HABUILD
make libbiometry_fp_api 
make fake_crypt

SFOSSDK
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-biometry-fp.spec
OR
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-fake-crypt.spec
or
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community


# Flashing SailfishOS



# Known Issues
### Voltage limit reached with speaker
If the volume is set to 100% and you play a loud audio, there is a voltage peak where it reaches its limit and the Fairphone will crash. You then need to simply reboot, and everything will work again. (This is replicable when playing the yolla remix ringtone at 100% volume)

### Broken Lockscreen
Sometimes the lockscreen does not work correctly and will show an endless loading circle. In that case, the phone has already booted and you can just swipe to unlock.

### Simcard lock is not supported
It is not possible (at the time of writing: 14-06-2023) to use a locked simcard. This is a problem in Sailfish OS, because Sailfish does not support the simcard unlock screen. To be able to use a simcard, you will need to remove the simcard pincode before inserting it in the Fairphone.

### Booting with broken audio
Whenever audio is corrupt, the phone needs to rebooted 3 times in order for it to start.

### Failed startup
When the phone takes longer than 60 seconds or the backlight turns off, the phone has failed to startup. In this state, you can only use the USB-interface. If this also doens't work, then you can only reboot or flash a new image.

### No splashcreen
During startup, there is no splashscreen displayed.



## Component specific known issues

### Earpiece speaker does not work
The earpiece speaker of the Fairphone does not work correctly when calling. 

### Bluetooth is not working
Bluetooth does not work at time of writing: 14-06-2023

### Mobile network does not work
Mobile network does not work in Sailfish version 4.5.0.18. In the newest version announced here: [[Release notes] Struven ketju 4.5.0.19](https://forum.sailfishos.org/t/release-notes-struven-ketju-4-5-0-19/15078). It is stated there has been a fix for IPv6-only mobile networks. Currently, there are no new latest toolings and targets availible for Sailfish verion 4.5.0.19 yet. see: [Index of /sdk/targets/](https://releases.sailfishos.org/sdk/targets/)




