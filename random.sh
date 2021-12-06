 INIT_choice="runit"
 
 BASESTRAP_PACKAGES() {
  packages=(
    "$INIT_choice" 
    "fcron-$INIT_choice"
    "dhcpcd-$INIT_choice"
    "chrony-$INIT_choice" 
    "networkmanager-$INIT_choice"
    "seatd-$INIT_choice"
    "lolcat"
    "figlet"
    "cryptsetup"
    "libressl"
    "vim"
    "neovim"
    "nano"
    "realtimes-privileges"
    "artix-archlinux-support"
    "base"
    "base-devel"
    "linux-zen"
    "linux-zen-headers"
    "grub-btrfs"
    "os-prober"
    "efibootmgr"
    "btrfs-progs"
    "mkinitcpio"
    "zstd"
    "lz4"
    "bc"
    "git"
  )
    printf -v packages_separated '%s ' "${packages[@]}"
    if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
      if [[ "$SUPERUSER_replace" == "true" ]]; then
        basestrap /mnt --needed intel-ucode opendoas $packages_separated
      else
        basestrap /mnt --needed intel-ucode sudo $packages_separated
      fi
    elif grep -q AMD "/proc/cpuinfo"; then
      if [[ "$SUPERUSER_replace" == "true" ]]; then
        basestrap /mnt --needed amd-ucode opendoas $packages_separated
      else
        basestrap /mnt --needed amd-ucode sudo $packages_separated
      fi
    fi
  }
  
  BASESTRAP_PACKAGES
