# Getting Started
- [Requirements](#requirements)
  + [Host Device](#host-device)
  + [To-Be-Installed Packages](#to-be-installed-packages)
  + [Build Info](#build-info)
- [Setting up the SDKs](#setting-up-the-sdks)
  + [Setting up the Environment Variables](#setting-up-the-environment-variables)
- [Setup the Platform SDK](#setup-the-platform-sdk)
  + [Install Tooling](#install-tooling)
  + [Setup the Android build Environment](#setup-the-android-build-environment)
- [Building the Android Hardware Abstraction Layer](#building-the-android-hardware-abstraction-layer)
  + [Sourcing the Android Base](#sourcing-the-android-base)
  + [Syncing the Android Base](#syncing-the-android-base)
- [Configuring partitions and kernel configuration](#configuring-partitions-and-kernel-configuration)
- [Building boot and recovery image](#building-boot-and-recovery-image)
- [Fixing errors in kernelconfiguration](#fixing-errors-in-kernelconfiguration)
- [Install SDK-targets](#install-sdk-targets)
- [Check target and tooling installation](#check-target-and-tooling-installation)
- [Setting up rpm](#setting-up-rpm)
- [Building packages in PLATFORM_SDK](#building-packages-in-platform_sdk)
- [Generating an updater .zip](#generating-an-updater-zip)
  * [init script](#init-script)

## Requirements
### Host Device 
- Linux x86 64-bit
- 200gb of storage
- Preferably 16gb of ram

### To-Be-Installed Packages
- curl
- git
- cpio
- ccache

### Build Info
- Android-base: LineageOS-18.1
- Port: SailfishOS

## Setting up the SDK’S
### Setting up the Environment Variables
Before we are starting setting up the SDK’s, we need to make sure some environment
variables are set to our specific situation. In our case this results in the next code-block:

To mark in which environment we are working, we use this “ENVIRONMENT $”
notation.

```
HOST $

cat << 'EOF' > $HOME/.hadk.env
export ANDROID_ROOT="$HOME/hadk"
export VENDOR="fairphone"
export DEVICE="FP4"
export PORT_ARCH="aarch64"
EOF
```

```
HOST $

cat << 'EOF' >> $HOME/.mersdkubu.profile
function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
export PS1="HABUILD_SDK [\${DEVICE}] $PS1"
hadk
EOF
```
## Setup the Platform SDK
Now we going to set up the Platform SDK. This next code-block will do everything like a "quick start". With this we will initialize, create and enter the "new" PlatformSDK.

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
The sfossdk at the end of the funtion is used to enter the PlatformSDK 
environment.

### Install Tooling
We need to install a couple of tools which are not installed by default.

Run the next code-block to install these tools:
```
PLATFORM_SDK $

sudo zypper ref
sudo zypper in android-tools-hadk kmod createrepo_c
```

Great we successfully set up the PlatformSDK. We entered the PlatformSDK, so
we can continue to the next part of this guide!

### Setup the Android build Environment

```
PLATFORM_SDK $

TARBALL=ubuntu-focal-20210531-android-rootfs.tar.bz2
curl -O https://releases.sailfishos.org/ubu/$TARBALL
UBUNTU_CHROOT=$PLATFORM_SDK_ROOT/sdks/ubuntu
sudo mkdir -p $UBUNTU_CHROOT
sudo tar --numeric-owner -xjf $TARBALL -C $UBUNTU_CHROOT
```

We can now enter the Android Build environment using:

```
PLATFORM_SDK $

ubu-chroot -r $PLATFORM_SDK_ROOT/sdks/ubuntu
```

## Building the Android Hardware Abstraction Layer
### Sourcing the Android Base

We first need to setup our name and emailadress in the git-configuration.
```
HABUILD_SDK $

git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global color.ui "auto"
```

After configuring the git-configuration, we need the Android Repo tool for the next steps.
```
HABUILD_SDK $

mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
source $HOME/.profile
```

We run ```source $HOME/.profile``` to update the environment. This makes sure that ~/bin is included in the path variable.

Now that the repo command has been setup. We can use it to clone the LineageOS android-base. 
```
HABUILD_SDK $

sudo mkdir -p $ANDROID_ROOT
sudo chown -R $USER $ANDROID_ROOT
cd $ANDROID_ROOT
repo init -u https://www.github.com/Sailfishos-for-the-fairphone-4/android.git -b hybris-18.1
```

This creates a hidden .repo folder where the configuration is stored. This folder also contains a default.xml file which is used to configure the locations from where we obtain our android base.

### Syncing the Android Base

In the .repo folder which we initialized in the previous step, contains `.xml` files. These files are called Manifest files. We now have 3 manifest files: 
* snippets/lineage.xml
* default.xml
* $DEVICE.xml (this case: FP4.xml)

The $DEVICE.xml file is a device specific manifest file. We need to copy this file to a new directory: `local_manifests`

```
HABUILD_SDK $

mkdir -p $ANDROID_ROOT/.repo/local_manifests && cp $ANDROID_ROOT/.repo/manifests/FP4.xml $ANDROID_ROOT/.repo/local_manifests/FP4.xml
```
Now we are ready to "sync and build" the repo's that are configured in the manifest files. To do this, we need to run:

```
HABUILD_SDK $

repo sync --fetch-submodules
```
----
#### Errors while running `repo sync --fetch-submodules`
*error: Cannot fetch . . . (GitError: –force-sync not enabled; cannot overwrite a local work tree.*, usually
happens if repo sync --fetch-submodules gets interrupted. It is a bug of the repo tool. Ensure
all your changes have been safely stowed (check with repo status), and then workaround by:

```
HABUILD_SDK $
repo sync --force-sync
repo sync --fetch-submodules
```
----

The expected disk usage for the source tree after sync is **~120 GB**. Depending on your connection, this might take some time. In the meantime, you could make yourself familiar with the rest of this guide.

We are now going to apply the hybris patches to our codebase, so that the default lib-hybris gets configured to work with our specific android base version.

```
HABUILD_SDK $

cd $ANDROID_ROOT/
./hybris-patches/apply-patches.sh --mb
```

Before we can start our build we need change one of the Tests: CalendarTests -> CalendarCommonTests 

```
$ HABUILD

sed  -i \"s/CalendarTests/CalendarCommonTests/\" platform_testing/build/tasks/tests/platform_test_list.mk
```

We need to change the already existing CalendarTests to CalendarCommonTests.
This because we don't use the LineageOS calendar, but the AOSP calendar, so then we need to test the AOSP calendar.

# Configuring partitions and kernel configuration



Since we made changes to the kernel we need to commit these changes to prevent a dirty flag notation in the kernel version
```
HABUILD_SDK $

cd $ANDROID_ROOT/kernel/fairphone/sm7225/arch/arm64/configs

git add .
git commit -m "Setup FP4 configuration"

```
# Building boot and recovery image
Now we are ready to start building everything we sourced and synced so far:
```
HABUILD_SDK $

cd $ANDROID_ROOT
source build/envsetup.sh
breakfast $DEVICE
make -j$(nproc --all) hybris-hal droidmedia
```

This command will take a long time. This preferably runs with 16GB of RAM and and takes around 60GB of storage to complete the build.


# Fixing errors in kernelconfiguration 
```
HABUILD_SDK $
cd $ANDROID_ROOT

hybris/mer-kernel-check/mer_verify_kernel_config ./out/target/product/FP4/obj/DTBO_OBJ/.config ./out/target/product/FP4/obj/DTB_OBJ/.config ./out/target/product/FP4/obj/KERNEL_OBJ/.config
```
In case of errors; fix and recompile. Warning can be fixed later.
Fixes need te be made in ```$ANDROID_ROOT/kernel/fairphone/sm7225/arch/arm64/configs/lineage_FP4_defconfig```
**Important: Don't forget to commit changes to prevent the dirty flag** 

# Install SDK-targets
Now that everything is synced and built, we are ready to install the remaining platform sdk-tools
```
PLATFORM_SDK $

sdk-assistant create SailfishOS-4.5.0.18 https://releases.sailfishos.org/sdk/targets/Sailfish_OS-4.5.0.18-Sailfish_SDK_Tooling-i486.tar.7z
sdk-assistant create $VENDOR-$DEVICE-$PORT_ARCH https://releases.sailfishos.org/sdk/targets/Sailfish_OS-4.5.0.18-Sailfish_SDK_Target-aarch64.tar.7z
```
#  Check target and tooling installation
To test if the targets and tooling are installed correctly you can run:

```
PLATFORM_SDK $

cd $HOME
mkdir hadk-test-tmp
cd hadk-test-tmp
cat > main.c << EOF
#include <stdlib.h>
#include <stdio.h>
int main(void) {
  printf("Hello, world!\n");
  return EXIT_SUCCESS;
}
EOF

mb2 -t $VENDOR-$DEVICE-$PORT_ARCH build-init
mb2 -t $VENDOR-$DEVICE-$PORT_ARCH build-shell gcc main.c -o test
```

If the compilation was successful you can test the executable by running the following command (this will run the
executable using qemu as emulation layer, which is part of the mb2 setup):

```
PLATFORM_SDK $

mb2 -t $VENDOR-$DEVICE-$PORT_ARCH build-shell ./test
```

The above command should output “Hello, world!” on the console, this proves that the build tools can compile
binaries and execute them for your architecture.

# Setting up rpm

Since the targets and tooling work we are ready to set up the rpm-configuration. To do that, we need to clone the repositories containing the FP4 rpm-configuration.
```
PLATFORM_SDK $

cd $ANDROID_ROOT
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-hal-device-FP4.git rpm
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-configs-FP4.git hybris/droid-configs
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/droid-hal-version-FP4.git hybris/droid-hal-version-FP4
git clone --recurse-submodules git@github.com:Sailfishos-for-the-fairphone-4/hybris-installer hybris/hybris-installer/

# Extra MW packages
git clone --recurse-submodules git@github.com:SailfishOS-for-the-fairphone-4/parse-android-dynparts.git hybris/parse-android-dynparts

```


# Building packages in PLATFORM_SDK

rpm/dhd/helpers/build_packages.sh --build=hybris/parse-android-dynparts -s rpm/parse-android-dynparts.spec

# TODO:
rpm/dhd/helpers/build_packages.sh --build=hybris/hidl_audio -s rpm/hidl_audio.spec

add fingerprint deamon
 
HABUILD
make libbiometry_fp_api 
make fake_crypt

SFOSSDK
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-biometry-fp.spec
OR
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-fake-crypt.spec
or
rpm/dhd/helpers/build_packages.sh --build=hybris/mw/sailfish-fpd-community



After those commands we can build the packages:
```
PLATFORM_SDK $

# To build everything at once.
cd $ANDROID_ROOT
export VERSION=4.5.0.18
rpm/dhd/helpers/build_packages.sh 


# Build packages seperate by using the 
  rpm/dhd/helpers/build_packages.sh --droid-hal
  rpm/dhd/helpers/build_packages.sh --configs
  rpm/dhd/helpers/build_packages.sh --mw
  rpm/dhd/helpers/build_packages.sh --gg
  rpm/dhd/helpers/build_packages.sh --version
  rpm/dhd/helpers/build_packages.sh --mic
```









