# Getting Started

## Requirements
### Packages:
- Curl
- Git
- Ccache (optional)

### Computer-spec-requirements
- Linux x86 64-bit
- 200gb of storage
- Preferably 16gb of ram

### build requirements:
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

cat <<'EOF' > $HOME/.hadk.env
export ANDROID_ROOT="$HOME/hadk"
export VENDOR="fairphone"
export DEVICE="FP4"
export PORT_ARCH="aarch64"
EOF
```

```
HOST$

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

exec bash
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

## Building the Android Hardware Abstraction Layer (HAL)
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
```

then run ```source $HOME/.profile``` to update the environment. This makes sure that ~/bin is included in the path variable.

Now that the repo command has been setup. We can use it to clone the LineageOS android-base. 
```
HABUILD_SDK $

sudo mkdir -p $ANDROID_ROOT
sudo chown -R $USER $ANDROID_ROOT
cd $ANDROID_ROOT
repo init -u https://www.github.com/Sailfishos-for-the-fairphone-4/android.git -b lineage-18.1
```

This creates a hidden .repo folder where the configuration is stored.

### Syncing the Android Base
We need a Manifest file to configure our android base. The first one we need to create is local_manifest/$DEVICE.xml. This file needs to contain some device configurations.


```
HABUILD_SDK $

mkdir -p $ANDROID_ROOT/.repo/local_manifests && cp $ANDROID_ROOT/.repo/manifests/FP4.xml $ANDROID_ROOT/.repo/local_manifests/FP4.xml
```

As we can see, all the revisions are lined up with LineagoOS version 18.1. Now we are ready to "sync and build" the repo's that are configured in the manifests. Therefor we need to run:


```
HABUILD_SDK $

repo sync --fetch-submodules
```

The expected disk usage for the source tree after sync is **150 GB**. Depending on your connection, this might take some time. In the meantime, you could make yourself familiar with the rest of this guide.

We now need to sync lib-hybris into our worktree.
```
HABUILD_SDK $

cd $ANDROID_ROOT/external
git clone --recurse-submodules https://github.com/mer-hybris/libhybris.git
cd $ANDROID_ROOT
```

We are now going to apply the hybris patches to our codebase.
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

# Configuring file and kernelconfig

The next step is to configure the file and kernel therefor we download the setup configuration files for the FP4. 

```
HABUILD_SDK $

cd $ANDROID_ROOT/hybris/hybris-boot/
curl https://raw.githubusercontent.com/SailfishOS-for-the-fairphone-4/hybris-boot/master/fixup-mountpoints -o fixup-mountpoints
chmod 775 fixup-mountpoints

cd $ANDROID_ROOT/device/fairphone/FP4/rootdir/etc/
curl https://raw.githubusercontent.com/SailfishOS-for-the-fairphone-4/android_device_fairphone_FP4/lineage-18.1/rootdir/etc/fstab.default -o fstab.default

cd $ANDROID_ROOT/kernel/fairphone/sm7225/arch/arm64/configs
curl https://raw.githubusercontent.com/SailfishOS-for-the-fairphone-4/android_kernel_fairphone_sm7225/lineage-18.1/arch/arm64/configs/lineage_FP4_defconfig -o lineage_FP4_defconfig
```

Since we made changes to the kernel we need to commit these changes to prevent a dirty flag notation in the kernel version
```
cd $ANDROID_ROOT/kernel/fairphone/sm7225/arch/arm64/configs

git add .
git commit -m "Setup FP4 configuration"

```

# add xmllint to allowed programs
We now need to add xmllint to the allowed programs. This is to suppress the buildwarnings caused by the buildaystem trying to use xmllint but not being allowed to use it.
add ```"xmllint": Allowed,``` to the configuration list in ```$hadk/build/soong/ui/build/paths/config.go```

# Building boot and recovery image
Now we are ready to start building everything we sourced and synced so far:
```
HABUILD_SDK $

cd $ANDROID_ROOT
source build/envsetup.sh
(optional) export USE_CCACHE=1
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
In case of errors fix and recompile warning can be fixed later.
Fixes need te be made in ```$ANDROID_ROOT/kernel/fairphone/sm7225/arch/arm64/configs/lineage_FP4_defconfig```
**Important: Don't forget to commit changes to prevent the dirty flag** 

# Install SDK-targets
Now that everything is synced and built we are ready to install the remaining platform sdk-tools
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

Since the targets and tooling work we are ready to set up the rpm-configuration tondo that we need to clone the repositories containg the FP4 rpm-configuration
```
PLATFORM_SDK $

cd $ANDROID_ROOT
mkdir rpm
cd rpm
git clone --recurse-submodules https://github.com/SailfishOS-for-the-fairphone-4/droid-hal-device-FP4.git

cd -
mkdir -p hybris/droid-configs
cd hybris/droid-configs
git clone --recurse-submodules https://github.com/SailfishOS-for-the-fairphone-4/droid-configs-FP4.git

cd -
rpm/dhd/helpers/add_new_device.sh

cd -
mkdir -p hybris/droid-hal-version-FP4
cd hybris/droid-hal-version-FP4
git clone --recurse-submodules https://github.com/SailfishOS-for-the-fairphone-4/droid-hal-version-FP4.git
```

Then add ```Requires: droid-hal-FP4-detritus``` to ```$ANDROID_ROOT/hybris/droid-configs/patters/patterns-sailfish-device-adaptation-FP4.inc```


# Building packages in PLATFORM_SDK

After those commands we can build the packages:
```
PLATFORM_SDK $

cd $ANDROID_ROOT
yes | rpm/dhd/helpers/build_packages.sh --droid-hal
yes | rpm/dhd/helpers/build_packages.sh --configs
yes | rpm/dhd/helpers/build_packages.sh --mw
yes | rpm/dhd/helpers/build_packages.sh --gg
yes | rpm/dhd/helpers/build_packages.sh --version

export VERSION=4.5.0.18
export EXTRA_NAME=-alpha
yes | rpm/dhd/helpers/build_packages.sh --mic
```


# Generating an updater .zip
In this project we use the hybris-installer repo to generate an updater zip-file. Set it up with the following commands:

```
PLATFORM_SDK $

cd $ANDROID_ROOT/
git clone https://github.com/sailfishos-oneplus5/hybris-installer hybris/hybris-installer/
mkdir hybris/droid-configs/kickstart/
curl -L https://git.io/Je2JI -o hybris/droid-configs/kickstart/pack_package-droid-updater
```

The update binary script has to be slightly modified to be compatible with the Fairphone 4. Please make the following changes to hybris/hybris-installer/META-INF/com/google/android/update-binary:
* Change boot to boot_a on line 144 and 151
* Change *.ext4 to *.f2fs on line 57

The pack_package-droid-updater included is made for the OnePlus-5 and needs to be adapted to support the Fairphone make the following changes:
* Set LOS_VER to 18.01 on line 42
* Set DEVICE to FP4 on line 3
* Set EXTRA_NAME to -alpha on line 4

Run the following commando to create the .zip from the directory containing the tar.bz2:
```
PLATFORM_SDK $

source ../hybris/droid-configs/kickstart/pack_package-droid-updater
```

## init script
The init-script in the hyris-boot repo needs to be updated. hadk/hybris/hybris-boot/init-script.
This part of the wiki is intended for use within the development team only. Required changes will be pushed to GitHub.
- Change BOOTLOGO on line 27 to 1
- Change ALWAYSDEBUG on line 28 to 0
- (temporary) Change sleep on line 276 from 60 to 5
- (temporary) Comment out reboot-f on line 277
- (optional) add cp /init.log /target/debug.log on line 388
- (optional) add cp /diagnosis.log /target/diag.log on line 388




