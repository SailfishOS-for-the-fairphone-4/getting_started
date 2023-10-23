#!/bin/bash

################################################################################
# Script Name   : Flash.sh
# Author        : Vincent van Setten
# Team          : Team Fairphone 499 "Zeilvis Helden" 2023
# Description   : Automates the flashing process
# Usage         : ./flash.sh [OPTIONS] or bash flash.sh [OPTIONS]
################################################################################

# Globals
## Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
GREY='\033[1;37m'
NC='\033[0m' # No Color

## Path Variables
recovery_img=""
boot_img=""
os_img=""

## Default path variables(for headless mode)
default_recovery_img="twrp.img"
default_boot_img="hybris-boot.img"
default_os_img="sailfishos-4.5.0.24-20231009-FP4.zip"

# Argument parsing
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --recovery=*) recovery_img="${1#*=}";;
        --boot=*) boot_img="${1#*=}";;
        --os=*) os_img="${1#*=}";;
        --headless) headless=true;;
        --help) help=true;;
        *) echo "Unknown parameter passed: $1"; exit 1;;
    esac
    shift
done


# Functions
## Function to validate if a file exists
validate_file() {
    while true; do
        read -e -p "$(echo -e "${CYAN}Enter the path for $1: ${NC}")" file_path
        if [ -e "$file_path" ]; then
            echo -e "$file_path"
            return
        else
            echo -e "${RED}$1 not found at: $file_path${NC}" >&2
        fi
    done
}

## Request needed files from user
request_files(){
    if [ -z "$recovery_img" ]; then
        recovery_img=$(validate_file "the recovery image (usually twrp.img)")
    fi
    if [ -z "$boot_img" ]; then
        boot_img=$(validate_file "the boot image (usually hybris-boot.img)")
    fi
    if [ -z "$os_img" ]; then
        os_img=$(validate_file "os package (usually sailfishos-*-.zip)")
    fi
}

## Function to wait for a fastboot device
wait_for_fastboot_device() {
    echo -e "${GREY}> Waiting for a fastboot device...${NC}"
    while ! fastboot devices | grep -q -E '[a-zA-Z0-9]'; do
        :
    done
    echo -e "${GREEN}>> Device found!${NC}"
}

## Function to flash hybris
flash_hybris() {
    echo -e "${GREY}> Flashing hybris: (fastboot flash boot_a $1 && fastboot flash boot_b $1)...${NC}"
    echo -e "${GREY}"
    fastboot flash boot_a $1 && fastboot flash boot_b $1
    echo -e "${NC}"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}>> Hybris flashing successful!${NC}"
    else
        echo -e "${RED}>> Hybris flashing failed!${NC}"
        exit 1
    fi
}
## Function to flash recovery
flash_recovery() {
    echo -e "${GREY}> Flashing recovery: (fastboot flash recovery $1)...${NC}"
    echo -e "${GREY}"
    fastboot flash recovery $1
    echo -e "${NC}"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}>> Recovery flashing successful!${NC}"
    else
        echo -e "${RED}>> Recovery flashing failed!${NC}"
        exit 1
    fi
}

## Function to wait for adb recovery device
wait_for_adb_recovery_device() {
    echo -e "${GREY}>> Please boot your device into recovery with adb enabled (This should be done automatically. Please wait...)${NC}"
    echo -e "${GREY}> Waiting for an adb device...${NC}"
    while ! adb devices | tail -n +2 | grep -q recovery; do
        :
    done
    echo -e "${GREEN}>> Device found!${NC}"
}

## Prompt
prompt_to_continue() {
    while true; do
        read -p "$(echo -e "${CYAN}Press 'y' to continue: ${NC}")" choice
        case "$choice" in
            [Yy]* ) break;;
            * ) echo -e "${RED}Please press 'y' to continue.${NC}";;
        esac
    done
}

## Function to flash OS
flash_os() {
    echo -e "${GREY}> Flashing OS: (adb sideload $1)...${NC}"
    echo -e "${GREY}"
    adb sideload $1
    echo -e "${NC}"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}>> OS flashing successful!${NC}"
    else
        echo -e "${RED}>> OS flashing failed!${NC}"
        if [ "$2" = true ]; then
            exit 1
        fi
    fi
}

## Help Command
help(){
    if [ "$help" = true ]; then
        echo -e "Usage: $0 [OPTIONS]"
        echo -e "  --recovery=<path_to_recovery_image>  Specify the path to the recovery image."
        echo -e "  --boot=<path_to_boot_image>          Specify the path to the boot image."
        echo -e "  --os=<path_to_os_zip>                Specify the path to the OS zip package."
        echo -e "  --headless                           Run the script without requiring any user input. (Please set default variables in the script)"
        echo -e "  --help                               Show this help message."
        exit 0
    fi
}

# Main Start
main(){
    help # Check if help is passed
    
    if [ "$headless" != true ]; then
        request_files
    else
        recovery_img="$default_recovery_img"
        boot_img="$default_boot_img"
        os_img="$default_os_img" # Change for headless
        echo -e "!!!! ${CYAN}Running in headless mode. Not prompting. Waiting 10 seconds after requesting a task, instead of requesting a 'y'!${NC}"
    fi
    
    echo -e "${CYAN}>> Please boot your device into the bootloader with fastboot enabled${NC}"
    wait_for_fastboot_device
    flash_hybris $boot_img
    flash_recovery $recovery_img
    echo -e "${GREY}> Rebooting into twrp recovery...${NC}"
    echo -e "${GREY}"
    fastboot reboot recovery # Reboots to TWRP
    echo -e "${NC}"
    wait_for_adb_recovery_device
    echo -e "${CYAN}>> Please verify the partitions 'system' and 'data' are mounted (TWRP -> Mount). Press 'y' when done.${NC}"
    if [ "$headless" = true ]; then
        sleep 10
    else
        prompt_to_continue
    fi
    echo -e "${CYAN}>> Please start adb sideloading(TWRP -> Advanced -> ADB Sideload). Press 'y' when done.${NC}"
    if [ "$headless" = true ]; then
        sleep 10
    else
        prompt_to_continue
    fi
    echo -e "${GREY}> Flashing will be done twice. The first one will likely fail${NC}"
    flash_os $os_img false
    echo -e "${CYAN}>> Please start adb sideloading(TWRP -> Advanced -> ADB Sideload). Press 'y' when done.${NC}"
    if [ "$headless" = true ]; then
        sleep 10
    else
        prompt_to_continue
    fi
    echo -e "${GREY}> Flashing for the second time. This should not fail.${NC}"
    flash_os $os_img false # False because adb sideload 'fails' even if it succeeds(failed to read command: Success)
    echo -e "${GREY}>> Flashing complete. Rebooting to fastboot...${NC}"
    sleep 5
    echo -e "${GREY}"
    adb reboot bootloader
    echo -e "${NC}"
    echo -e "${GREY}>> Please boot your device into the bootloader with fastboot enabled. This should happen automatically. Please wait.${NC}"
    wait_for_fastboot_device
    flash_hybris $boot_img
    echo -e "${GREEN}>>> Done!${NC}"
    echo -e "${GREEN}>>> Starting system. Goodbye${NC}"
    echo -e "${GREY}"
    fastboot reboot
    echo -e "${NC}"
}

main
