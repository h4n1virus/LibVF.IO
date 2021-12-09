#!/bin/bash
#
# Copyright: 2666680 Ontario Inc.
# Reason: Installation of libvf.io
#

source ./scripts/funcs-libvfio.sh

## Place optional driver packages in the optional directory before running this installation script

# Prevents user from running script with root
root_kick
# Ensures script is ran from proper directory
check_dir
# Checks which distribution user is using
check_distro

# Checks if first stage of install script is complete
pt2_check

# Set compile sandbox path
set_sandbox
# Adds user to KVM Group
add_kvm_group
# Updates packages
distro_update
# Installs libvfio dependencies
add_depen

# Looking Glass and AppArmor Policies and Shared memory permissions
mem_permissions
add_policies
restart_apparmor

# Configure kernel boot parameters
add_boot_param
# Blacklisting non-mediated device drivers
blacklist_drivers
# Updating Initramfs
update_initramfs

# Installing Choosenim
install_choosenim
# Compile and install libvfio
install_libvfio

# Download Looking Glass beta 4 sources
dl_lookingglass
# Compile & install Looking Glass sources
install_lookingglass

# Download and install scream sources
get_scream
# Install and configure introspection files
get_introspection

# Deploying arcd (libvfio component)
arcd_deploy

# Patch NV driver according to kernel version
patch_nv
# Install Nvidia Optional Driver
install_nv


# Rmmod Nouveau
rm_nouvea

# Check if nouveau is unloaded (pc rebooted)
# IF no, prime system to continue where install script left off after reboot
# IF yes, install nvidia if nouveau is not loaded
pt1_end


# Reload systemd daemons
sudo systemctl daemon-reload
exit
