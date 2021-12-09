#!/bin/bash
#
# Copyright: 2666680 Ontario Inc
# Reason: libvf.io bash functions
#



function root_kick() {
  if [[ $(/usr/bin/id -u) == 0 ]]; then
    echo "This script should not be run as root."
    exit
  fi

}

function check_dir() {
  if [ ! -f ./src/arcd.nim ];then
    echo "Run the script from the main libvfio directory, using ./scripts/uninstall-libvfio.sh"
    exit
  else
    current_path=$(pwd)
  fi
}

function check_distro() {
  distro=$(uname -n)
  if [ $distro != "fedora" ] &&  [ $distro != "ubuntu" ] && [ $distro != "arch" ];then
    echo What linux distribution are you running? 
    echo -e "Type 1 or 'Fedora'\nType 2 or 'Ubuntu'\nType 3 or 'Arch'"
    read -p "Response: " a1_distro

    a_distro=$(echo $a1_distro | tr '[:lower:]' '[:upper:]')

    if [ $a_distro == "1" ] || [ $a_distro == "FEDORA" ];then
      distro="fedora"
    elif [ $a_distro == "2" ] || [ $a_distro == "UBUNTU" ];then
      distro="ubuntu"
    elif [ $a_distro == "3" ] || [ $a_distro == "ARCH" ];then
      distro="arch"
    else
      echo "Make a valid choice"
      exit
    fi
  fi
  echo Running uninstall script for $distro distribution.
}

function set_sandbox_dir {
  compile_sandbox=$(echo ~)"/.cache/libvf.io/compile/"
  mkdir -p $compile_sandbox
}

function add_kvm_group {
  sudo usermod -a -G kvm $USER 
}

function distro_update() {
  check_distro
  case $distro in
    "fedora")	sudo dnf upgrade -y;;
    "ubuntu")	sudo apt update -y; sudo apt upgrade -y;;
    "arch")	sudo yay -Syu;;
    *)		echo "distro isnt fedora, ubuntu, or arch. unsure how to proceed.";;
  esac
}

function ls_depen() {
  lookingglass_dep_fedora=" binutils-devel cmake texlive-gnu-freefont fontconfig-devel SDL2-devel SDL2_ttf-devel spice-protocol libX11-devel nettle-devel wayland-protocols-devel libXScrnSaver-devel libXfixes-devel libXi-devel wayland-devel libXinerama-devel "
  lookingglass_dep_ubuntu="  " 
  lookingglass_dep_arch="  "
  xyz_dep_fedora="  "
}

function add_depen() {
  check_distro
  ls_depen
  case $distro in
    "fedora") 	sudo dnf install -y nsis plasma-wayland-protocols dkms mingw64-gcc $lookingglass_dep_fedora qemu patch kernel-devel openssl;;
    "ubuntu")	sudo apt install -y mokutil dkms libglvnd-dev curl gcc cmake fonts-freefont-ttf libegl-dev libgl-dev libfontconfig1-dev libgmp-dev libspice-protocol-dev make nettle-dev pkg-config python3 python3-pip binutils-dev qemu qemu-utils qemu-kvm libx11-dev libxfixes-dev libxi-dev libxinerama-dev libxss-dev libwayland-bin libwayland-dev wayland-protocols gcc-mingw-w64-x86-64 nsis mdevctl git libpulse-dev libasound2-dev;;
    "arch")	yay -S "nsis" mdevctl base-devel libxss libglvnd mingw-w64-gcc curl spice-protocol wayland-protocols cdrkit mokutil dkms make cmake gcc nettle python3 qemu alsa-lib libpulse;;
     *)		echo "distro isnt fedora, ubuntu, or arch. unsure how to proceed.";;
  esac
}

function add_boot_param() {
  check_distro
  echo "Updating kernel boot parameters."
  # Intel users
  if [[ $cpuModel == *"GenuineIntel"* ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"intel_iommu=on iommu=pt vfio_pci vfio mdev /g' /etc/default/grub
  # AMD users
  elif [[ $cpuModel == *"AuthenticAMD"* ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"amd_iommu=on iommu=pt vfio_pci vfio mdev /g' /etc/default/grub
  fi
  # GRUB
  case $distro in 
    "fedora")	sudo grub2-mkconfig -o /boot/grub2/grub.cfg;;
    "ubuntu")	sudo update-grub;;
    "arch")	sudo grub-mkconfig -o /boot/grub/grub.cfg;;
     *)		echo "distro isnt fedora, ubuntu, or arch. unsure how to proceed.";;
  esac
}


function add_policies() {
  if [ $distro == "ubuntu" ] || [ $distro == "arch" ];then
    # Configure AppArmor policies, shared memory file permissions, and blacklisting non-mediated device drivers.
    echo "Updating AppArmor policies."
    sudo su root -c "mkdir -p /etc/apparmor.d/local/abstractions/ && echo '/dev/shm/kvmfr-* rw,' >> /etc/apparmor.d/local/abstractions/libvirt-qemu"
  fi
}

function mem_permissions() {
  echo "Configuring shared memory device file permissions."
  sudo su root -c "echo \"f /dev/shm/kvmfr-* 0660 $USER kvm -\" >> /etc/tmpfiles.d/10-looking-glass.conf"
}

functishell_path=$SHELLon blacklist_drivers() {
  echo "Blacklisting non-mediated device drivers."
  sudo su root -c "echo '# Libvf.io GPU driver blacklist' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdgpu' >> /etc/modprobe.d/blacklist.conf && echo 'blacklist amdkfd' >> /etc/modprobe.d/blacklist.conf"

}  

function restart_apparmor() {
  # Restarting apparmor service
  if [ $distro == "ubuntu" ] || [ $distro == "arch" ];then
    sudo systemctl restart apparmor
  fi
}

function update_initramfs() {
  # Updating initramfs
  case $distro in
    "fedora")	sudo dracut -fv --regenerate-all;;
    "ubuntu")	sudo update-initramfs -u -k all;;
    "arch")	sudo mkinitcpio -P;;
    *)		echo "distro isnt fedora, ubuntu, or arch. unsure how to proceed.";;
  esac
}

function rm_nouveau() {
  sudo rmmod nouveau
}

function check_shell() {
  shell_path=$SHELL
  case $shell_path in
    *zsh*)	shell_current="zsh";echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.zshrc;;
    *bash*)	shell_current="bash";echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.bashrc;;
    *fish*)	shell_current="fish";echo "What do FISH pray to?"; echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.config/fish/config.fish;;
    *csh*)	shell_current="zsh";echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.cshrc;;
    *tcsh*)	shell_current="zsh";echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.tcshrc;;
    *sh*)	shell_current="sh";;
    *)		echo "cannot find your current shell"
  esac
}

function install_choosenim() {
  check_shell
  if ! which nimble;then
    curl https://nim-lang.org/choosenim/init.sh -sSf | sh
    echo "export PATH=$HOME/.nimble/bin:$PATH" >> ~/.${shell_current}rc
    export PATH=$HOME/.nimble/bin:$PATH
    choosenim update stable
  fi
}

function install_libvfio() {
  # Compile and install libvf.io
  cd $current_path
  nimble install -y
  rm ./arcd
}

function dl_lookingglass() {
  set_sandbox_dir
 # Download Looking Glass beta 4 sources
  mkdir -p $compile_sandbox
  cd $compile_sandbox
  rm -rf LookingGlass
  git clone --recursive https://github.com/gnif/LookingGlass/
  cd LookingGlass
  git checkout Release/B4
}

function install_lookingglass() {
 # Compile & install Looking Glass sources
  mkdir client/build
  mkdir host/build
  cd client/build
  cmake ../
  make
  sudo make install
  # Cause we cannot use looking glass host binary
  cd ../../host/build
  cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain-mingw64.cmake ..
  make
  cd platform/Windows
  makensis installer.nsi
}

function get_scream() {
  set_sandbox_dir
  # Download Scream sources
  cd $compile_sandbox
  git clone https://github.com/duncanthrax/scream/
  cd scream/Receivers/unix
  # Compile & install scream sources
  mkdir build && cd build
  cmake ..
  make
  sudo make install
}

function get_introspection() {
  mkdir -p $HOME/.local/libvf.io/
  rm -rf $HOME/.local/libvf.io/introspection-installations
  mkdir -p $HOME/.local/libvf.io/introspection-installations
  wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip
  wget https://github.com/duncanthrax/scream/releases/download/3.8/Scream3.8.zip
  cp $HOME/.cache/libvf.io/compile/LookingGlass/host/build/platform/Windows/looking-glass-host-setup.exe ./
  echo "REG ADD HKLM\SYSTEM\CurrentControlSet\Services\Scream\Options /v UseIVSHMEM /t REG_DWORD /d 2" >> scream-ivshmem-reg.bat
  cp -r * $HOME/.local/libvf.io/introspection-installations
  cd $HOME/.local/libvf.io/
  mkisofs -A introspection-installations.rom -l -allow-leading-dots -allow-lowercase -allow-multidot -relaxed-filenames -d -D -o ./introspection-installations.rom introspection-installations
  cp introspection-installations.rom ~/.config/arc/
}

function arcd_deploy() {
  # Deploying arcd (libvfio component)
  arcd deploy --root=$HOME/.local/libvf.io/
}

function check_optional_driver() {
  if [ ! -f $current_path/optional/*.run ]; then
    echo "Optional drivers not found."
    exit 0
  else 
    cd $current_path/optional
    chmod 755 *.run
  fi
}


function check_k_version() {
  # Check kernel version
  kernel_release=$(uname -r)
  major=`awk '{split($0, a, "."); print a[1]}' <<< $kernel_release`
  minor=`awk '{split($0, a, "."); print a[2]}' <<< $kernel_release`
  echo "MAJOR: $major"
  echo "MINOR: $minor"
}

function patch_nv() {
  # Patch NV driver according to kernel version 
  check_k_version
  custom=""  
  if [[ ($major -eq 5) && ($minor -ge 13) ]];then
    echo "Modifying the driver to have the version 5.14/15 patches."
    custom="-custom"
    ./*.run --apply-patch $current_path/patches/fourteen.patch 
  elif [[ ($major -eq 5) && ($minor -ge 12) ]];then
    echo "Modifying the driver to have the version 5.12 patches."
    custom="-custom"
    ./*.run --apply-patch $current_path/patches/twelve.patch 
  fi
}

function install_nv() {
  # To ensure these are loaded beforehand
  sudo modprobe vfio
  sudo modprobe mdev
  # Generate a driver signing key
  mkdir -p ~/.ssh/
  openssl req -new -x509 -newkey rsa:4096 -keyout ~/.ssh/module-private.key -outform DER -out ~/.ssh/module-public.key -nodes -days 3650 -subj "/CN=kernel-module"
  echo "The following password will need to be used in enroll MOK on your next startup."
  sudo mokutil --import ~/.ssh/module-public.key
  sudo ./*$custom.run --module-signing-secret-key=$HOME/.ssh/module-private.key --module-signing-public-key=$HOME/.ssh/module-public.key -q
}

# Check if nouveau is unloaded (pc rebooted)
# Install nvidia if nouveau is inloaded
function pt1_end() {
  if ! lsmod | grep "nouveau";then
    install_nv
    echo "Install of Libvfio has been finalized! Reboot may be necessary."
    rm $HOME/preinstall
  else
    touch $HOME/preinstall
    echo "Nouveau was found, please reboot and run ./install.sh again, it will start from this point."
  fi
}

function pt2_check() {
  if [ -f "$HOME/preinstall" ] && [ -f "$HOME/.local/libvf.io/"] && lsmod | grep "nouveau";then
    echo "Error, It seems you've been through the first part of install and reboot, but Nouveau is still loaded"
    echo "Try removing Nouveau manually, reboot, then run install script again to install NV drivers."
    exit
  elif [ -f "$HOME/preinstall" ] && [ ! -f "$HOME/.local/libvf.io/"] && lsmod | grep "nouveau";then
    echo "Nouveau is still loaded, and you seem to be missing files that should've been added in Part 1 of libvfio install"
    echo "Try the install from the beginning. Otherwise submit an error report."
    rm $HOME/preinstall
    exit
  elif [ -f "$HOME/preinstall" ]; then
    install_nv
    echo "Install of Libvfio has been finalized! Reboot may be necessary."
    rm $HOME/preinstall
    exit
  fi
}



function rm_kvm_group() {
  check_distro
  case $distro in
    "fedora")	sudo gpasswd -d $USER kvm;;
    "ubuntu")	deluser $USER kvm;;
    "arch")	
}

function rm_depen() {
  check_distro
  ls_depen 
  case $distro in
    "fedora")	sudo dnf install -y nsis plasma-wayland-protocols dkms mingw64-gcc $lookingglass_dep_fedora qemu patch kernel-devel openssl;;
    "ubuntu")	sudo apt remove -y mokutil dkms libglvnd-dev curl gcc cmake fonts-freefont-ttf libegl-dev libgl-dev libfontconfig1-dev libgmp-dev libspice-protocol-dev make nettle-dev pkg-config python3 python3-pip binutils-dev qemu qemu-utils qemu-kvm libx11-dev libxfixes-dev libxi-dev libxinerama-dev libxss-dev libwayland-bin libwayland-dev wayland-protocols gcc-mingw-w64-x86-64 nsis mdevctl git libpulse-dev libasound2-dev;;
    "arch")	yay -R "nsis" mdevctl base-devel libxss libglvnd mingw-w64-gcc curl spice-protocol wayland-protocols cdrkit mokutil dkms make cmake gcc nettle python3 qemu alsa-lib libpulse;;
    *)		echo "distro isnt fedora, ubuntu, or arch. unsure how to proceed.";;
  esac
}

function rm_stuff() {
  rm -rf ~/.local/libvf.io
  rm -rf ~/.cache/libvf.io
  rm -rf ~/.config/arc
  sudo rm /etc/tmpfiles.d/10-looking-glass.conf
}

function rm_nim() {
  rm -rf ~/.choosenim
  rm -rf ~/.nimble
  rm -rf ~/.cache/nim
  shell_path=$SHELL 
  case $shell_path in
    *zsh*)	shell_current="zsh";sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.zshrc;;
    *bash*)	shell_current="bash";sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.bashrc;;
    *fish*)	shell_current="fish";echo "What do FISH pray to?";sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/ >> ~/.config/fish/config.fish;;
    *csh*)	shell_current="zsh";sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.cshrc;;
    *tcsh*)	shell_current="zsh";sed -i "s|export PATH=$HOME/.nimble/bin:$PATH| |g" ~/.tcshrc;;
    *sh*)	shell_current="sh";;
    *)		echo "cannot find your current shell"
  esac
  #also counter   export PATH=$HOME/.nimble/bin:$PATH ?
}

function def_driver() {
  #GRUB
  if [[ $cpuModel == *"GenuineIntel"* ]]; then
    sudo sed -i 's/intel_iommu=on iommu=pt vfio_pci vfio mdev//g' /etc/default/grub
    sudo sed -i 's/intel_iommu=on iommu=pt vfio_pci//g' /etc/default/grub
  elif [[ $cpuModel == *"AuthenticAMD"* ]]; then
    sudo sed -i 's/amd_iommu=on iommu=pt vfio_pci vfio mdev//g' /etc/default/grub
    sudo sed -i 's/amd_iommu=on iommu=pt vfio_pci//g' /etc/default/grub
  else 
    echo cpu model?
    exit
  fi
  check_distro
  case $distro in
    "fedora")	sudo grub2-mkconfig -o /boot/grub2/grub.cfg;;
    "ubuntu")	sudo update-grub;;
    "arch")	sudo grub-mkconfig -o /boot/grub/grub.cfg;;
    *)          echo "distro isnt fedora, ubuntu, or arch. unsure how to proceed.";;
  esac
  #blacklist
  sudo sed -i 's/# Libvf.io GPU driver blacklist//g' /etc/modprobe.d/blacklist.conf
  sudo sed -i 's/blacklist nouveau//g' /etc/modprobe.d/blacklist.conf
  sudo sed -i 's/blacklist amdgpu//g' /etc/modprobe.d/blacklist.conf
  sudo sed -i 's/blacklist amdkfd//g' /etc/modprobe.d/blacklist.conf
  update_initramfs

  #uninstall nvidia driver
  sudo nvidia-uninstall

  #load nouveau driver
  sudo modprobe nouveau
  #Fedora unload vfio and mdev modules
  if [ $distro == "fedora" ];then sudo modprobe -r vfio;    sudo modprobe -r mdev;  fi
}

function rm_main() {
  libvf=$(pwd)
  cd ..
  rm -rf $libvf
}


