   #/usr/bin/bash
   packages=(
      "$INIT_choice" 
      "fcron-$INIT_choice"
      "dhcpcd-$INIT_choice"
      "chrony-$INIT_choice" 
      "networkmanager-$INIT_choice"
      "seatd-$INIT_choice"
      "cryptsetup-$INIT_choice"
      "pam_rundir"
      "lolcat"
      "figlet"
      "bat"
      "cryptsetup"
      "libressl"
      "vim"
      "neovim"
      "nano"
      "realtime-privileges"
      "base"
      "base-devel"
      "linux-zen"
      "linux-zen-headers"
      "os-prober"
      "efibootmgr"
      "btrfs-progs"
      "mkinitcpio"
      "zstd"
      "lz4"
      "bc"
      "git"
    )
    printf -v PACKAGES_separated '%s ' "${packages[@]}"
    if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
      export MICROCODE_package="intel-ucode"
    elif grep -q AMD "/proc/cpuinfo"; then
      export MICROCODE_package="amd-ucode"
    fi
    basestrap /mnt opendoas $PACKAGES_separated $MICROCODE_package --needed
