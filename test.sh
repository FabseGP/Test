#!/bin/bash

# Static variables / configurable during install

  # Static
  COLUMNS=$(tput cols) 
  BEGINNER_DIR=$(pwd)
  WRONG=""
  PROCEED=""
  
  # Choices during install; either true or nothing (interpreted as false)
  FILESYSTEM_primary="" # Future support for bcachefs once mainlined
  ENCRYPTION_partitions=""
  SWAP_partition=""
  FSTAB_check=""
  INIT_choice=""
  AUR_helper=""
  SUPERUSER_replace=""
  ADDITIONAL_packages=""

  # Drives and partitions + encryption + mountpoint
  export DRIVE_path="sda"
  export DRIVE_path_boot="/dev/sda1"
  export DRIVE_path_swap="/dev/sda2"
  export DRIVE_path_primary="/dev/sda3"
  export BOOT_size="300"
  export BOOT_label="boot"
  export SWAP_size="700"
  export SWAP_size_allocated="1000"
  export SWAP_label="ram_co"
  export PRIMARY_label="root"
  export ENCRYPTION_passwd="hallo"
  MOUNTPOINT=""

  # Locals
  export TIMEZONE_1="Europe"
  export TIMEZONE_2="Copenhagen"
  export LANGUAGES_generate="da_DK.UTF-8 en_GB.UTF-8"
  export LANGUAGE_system="da_DK.UTF-8"
  export KEYMAP_system="dk-latin1"
  export HOSTNAME_system="fabse"

  # Users
  export ROOT_passwd="root"
  export USERNAME="fabse"
  export USER_passwd="fabse"

  # Miscellaneous
  BOOTLOADER_label=""
  SNAPSHOT_cronjob_time="" # Default is 13:00:00 local time
  PACKAGES_additional=""
  GITHUB_repo=""

#----------------------------------------------------------------------------------------------------------------------------------

# Parameters that customizes the system-install

  # BCACHEFS-support
  BCACHEFS_implemented="false"
  BCACHEFS_notice="(BCACHEFS as filesystem) # Currently not implemented"

  # Subvolumes to be created 
  subvolumes=(
    \@
    \@"home"
    \@"var"
    \@"opt"
    \@"tmp"
    \@"srv"
    \@\."snapshots"
  )

  # Size of tmpfs (/tmp) 
  RAM_size="$((($(free -g | grep Mem: | awk '{print $2}') + 1) / 2))G" # tmpfs will fill half the RAM-size

  # Groups which user is added to 
  export USER_groups="video,audio,seatd,input,power,storage,optical,lp,scanner,dbus,daemon,disk,uucp,wheel,realtime"

  # Miscellaneous security enhancements 
  export LOGIN_delay="3000000" # Delays initial login with 3 seconds if wrong credentials

#----------------------------------------------------------------------------------------------------------------------------------

# Colors for any output

  PRINT_WITH_COLOR(){
    case "$1" in
      red)
        echo -e "\033[91m$2\033[0m"
        ;;
      green)
        echo -e "\033[92m$2\033[0m"
        ;;
      yellow)
        echo -e "\033[93m$2\033[0m"
        ;;
      blue)
        echo -e "\033[94m$2\033[0m"
        ;;
      purple)
        echo -e "\033[95m$2\033[0m"
        ;;
      cyan)
        echo -e "\033[96m$2\033[0m"
        ;;
      white)
        echo -e "\033[97m$2\033[0m"
        ;;
    esac
  }

#----------------------------------------------------------------------------------------------------------------------------------

# Prints lines to separate each part; also space before and after if specified

  PRINT_LINES() {
  if [[ "$1" == "SPACE" ]]; then
    echo
  fi
  echo "--------------------------------------------------------------------------------------------------"
  if [[ "$1" == "SPACE" ]]; then
    echo
  fi
}

#----------------------------------------------------------------------------------------------------------------------------------

# 1) Outputs chosen message with lines that fills the width of your tty + space before and after
# 2) Outputs text as ASCII-art + piped through lolcat for rainbow colors!

  PRINT_MESSAGE() {
    OUTPUT="$*"
    echo
    printf '%0.s-' $(seq 1 "$COLUMNS")
    printf "%*s\n" $(((${#OUTPUT}+$COLUMNS)/2)) "$OUTPUT" | lolcat
    printf '%0.s-' $(seq 1 "$COLUMNS")
    echo
  }

  ASCII_rainbow() {
    figlet -c -t -k "$@" | lolcat && echo
  }

#----------------------------------------------------------------------------------------------------------------------------------

  PRINT_PROGRESS_BAR() {
    local progress_bar="."
    printf "%s" "${progress_bar}"
  }

#----------------------------------------------------------------------------------------------------------------------------------

# Outputs checkbox, where 1 = [X] = YES and 0 = [ ] = NO

  PRINT_CHECKBOX() { 
    [[ "$1" == "1" ]] || [[ "$1" == "true" ]] && echo -e "${BBlue}[${Reset}${Bold}X${BBlue}]${Reset}" || echo -e "${BBlue}[ ${BBlue}]${Reset}";
  }

#----------------------------------------------------------------------------------------------------------------------------------

# Insure that the script is run as root-user

  if [ -z "$1" ]; then
    if ! [ "$USER" = 'root' ]; then
      echo
      WARNING="THIS SCRIPT MUST BE RUN AS ROOT!"
      PRINT_LINES
      printf "%*s\n" $(((${#WARNING}+$COLUMNS)/2)) "$WARNING"
      PRINT_LINES
      exit 1
    fi
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Choices to present in text-menu

  intro=(
    "INTRO"
    "FILESYSTEM_primary_btrfs:BTRFS as filesystem"
    "FILESYSTEM_primary_bcachefs:$BCACHEFS_notice"
    "ENCRYPTION_partitions:Encryption" 
    "SWAP_partition:Swap-partition" 
    "FSTAB_check:FSTAB-check before system-install" 
    "INIT_choice_runit:runit as init" 
    "INIT_choice_openrc:openrc as init" 
    "INIT_choice_dinit:dinit as init" 
    "SUPERUSER_replace:Replace sudo with doas" 
    "AUR_helper:Install an AUR-helper" 
    "ADDITIONAL_packages:Install additional packages"
    "CUSTOM_script:Pull and execute custom scripts from Github while in chroot"
   )

  partitions=(
    "PARTITIONS"
    "BOOT" 
    "SWAP"
    "ROOT"
   ) 

  settings=(
    "SETTINGS"
    "TIMEZONE" 
    "LANGUAGE/LANGUAGES"
    "KEYMAP"
    "HOSTNAME"
    "USERS"
    "ADDITIONAL PACKAGES"
    "BTRFS-SNAPSHOTS TIME"
    "BOOTLOADER-ID"
   )
 
#----------------------------------------------------------------------------------------------------------------------------------

# Messages to print

  messages=(
    "figlet -c -t -k WELCOME | lolcat -a -d 3 && echo && figlet -c -t -k You are about to install Artix Linux! | lolcat -a -d 2" # Intro
    "figlet -c -t -k FAREWELL - THIS TIME FOR REAL! | lolcat -a -d 3 && echo" # Goodbye
    "To tailer the installation to your needs, you have the following options: " # Choices for customizing install
    "USAGE: Tapping SPACE reverts the value, while tapping ENTER confirms your choices! " # Usage of text-menu
    "YOU NEED TO CHOOSE ONE OF THE LISTED INIT! " # If none of the init is chosen
    "TIME TO FORMAT THESE DRIVES!" # While specifying sizes / labels for the partitions
    "TIME TO ZONE YOUR TIME!" # While configuring the timezone
    "YOU DECIDE YOUR COMPUTERS VOCABULARY!" # While configuring the systemwide language(s)
    "THAT KEY MUST BE MAPPED!" # While configuring the systemwide keymap
    "WE CAN ALL BENEFIT FROM MORE USERS!" # While configuring the users
    "TIME TO PACK UP!" # Installing packages
    "DISCLAIMER: NOT AN ACTUAL SHOT!" # While specifying the time for which snapshots will be taken
    "IF YOU CHOOSE A BAD NAME, YOUR COMPUTER WILL NOT BOOT!" # While setting the bootloader-id
    "BACK TO SQUARE ONE!" # Whenever an command / part of the script has to be run again
    "BE CONSIDERATE TOWARD YOUR COMPUTER!" # While setting the hostname
  )

#----------------------------------------------------------------------------------------------------------------------------------

# Functions

  # Installs packages required by script
  SCRIPT_01_REQUIRED_PACKAGES() {
     if [[ -z "$(pacman -Qs lolcat)" ]]; then
       printf "%s" "Installing dependencies "
       local command="pacman -S --noconfirm --needed lolcat figlet parted"
       $command > /dev/null &
       while [[ ! $(pacman -Qs lolcat) ]]; do
         PRINT_PROGRESS_BAR 
         sleep 1
       done
       printf " [%s]\n" "Success!"
     fi
   }

  # Customizing your install
  SCRIPT_02_CUSTOMIZING() {
    eval "${messages[0]}"
    MULTISELECT_MENU "${intro[@]}"
    for ((i=1, j=1, options=1; i < "$COUNT_intro"; i++, j++, options++)); do 
      VALUE=$(eval echo \$CHOICE_$j)
      CHOICE=${options[i]}
      SORTED=${CHOICE%%:*}
      if [[ "$VALUE" == "true" ]]; then
        export "$SORTED"="$VALUE"
      fi	
    done
  }

  # If /mnt is mounted (perhaps due to exiting the script before it finished),
  # then unmount /mnt and deactivate swap (just a precaution)
  SCRIPT_03_UMOUNT_MNT() {
    if [[ "$(mountpoint /mnt)" ]]; then
      swapoff -a
      umount -R /mnt
    fi
  }

  # Installs support for arch-repositories and updates all GPG-keys.
  # Also enables testing-repositories, parallel downloads and colored outputs by replacing pacman.conf.
  SCRIPT_04_PACMAN_REPOSITORIES() {
    if [[ -z "$(pacman -Qs artix-archlinux-support)" ]]; then
      pacman -S --noconfirm --needed artix-archlinux-support
      pacman-key --init
      pacman-key --populate archlinux artix
      cp pacman.conf /etc/pacman.conf
      pacman -Syy 
    fi
  }

  # Creates GPT-partitions with the following attributes:
    # Boot-partition = fat32 + bootable
    # Root-partition = choice of filesystem, either BTRFS or BCACHEFS (if implemented)
  # If the user has chosen to create an SWAP-partition, it will also be created here
  SCRIPT_05_CREATE_PARTITIONS() {
    if [[ "$SWAP_partition" == "true" ]]; then
      parted --script -a optimal /dev/"$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart SWAP linux-swap "$BOOT_size"MiB "$SWAP_size_allocated"MiB  \
        mkpart PRIMARY "$FILESYSTEM_primary" "$SWAP_size_allocated"MiB 100% 
    else
      parted --script -a optimal /dev/"$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart PRIMARY "$FILESYSTEM_primary" "$BOOT_size"MiB 100% 
    fi
  }

  # Since BTRFS lacks native encryption, is it achieved using cryptsetup; the user-inputted
  # encryption-password is piped through. GRUB finally has (albeit limited) support for luks2,
  # though limited to pbkdf2 as key-derivation-function.
  # BCACHEFS supports native encryption, though isn't yet mainlined into the kernel
  # Formats all drives with chosen name, while also specifying the mountpoints for boot and the 
  # primary partition. 
  SCRIPT_06_FORMAT_AND_ENCRYPT_PARTITIONS() {
    mkfs.vfat -F32 -n "$BOOT_label" "$DRIVE_path_boot" 
    if [[ "$SWAP_partition" == "true" ]]; then
      mkswap -L "$SWAP_label" "$DRIVE_path_swap"
      swapon "$DRIVE_path_swap"
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf=pbkdf2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
      echo "$ENCRYPTION_passwd" | cryptsetup open "$DRIVE_path_primary" cryptroot
      mkfs.btrfs -f -L "$PRIMARY_label" /dev/mapper/cryptroot
      MOUNTPOINT="/dev/mapper/cryptroot"
    elif [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      mkfs.btrfs -f -L "$PRIMARY_label" "$DRIVE_path_primary"
      MOUNTPOINT="$DRIVE_path_primary"
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      bcachefs format -f --encrypted --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      bcachefs format -f --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"        
    fi
  }

  # Also creates subvolumes to avoid taking snapshots of unnecessary paths, 
  # e.g. /var/*. BCACHEFS-snapshots is supported natively and will be implemented.
  # Also plain-encrypts the swap-partition if created
  SCRIPT_07_CREATE_SUBVOLUMES_AND_MOUNT_PARTITIONS() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      mount -o noatime,compress=zstd "$MOUNTPOINT" /mnt
      cd /mnt || exit
      for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
        btrfs subvolume create "${subvolumes[subvolume]}"
      done
      cd / || exit
      umount /mnt
      mount -o noatime,compress=zstd,subvol=@ "$MOUNTPOINT" /mnt
      mkdir -p /mnt/{boot/EFI,home,srv,var,opt,tmp,.snapshots,.secret}
      printf -v subvolumes_separated '%s,' "${subvolumes[@]}"
      for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
        subvolume_path=$(string="${subvolumes[subvolume]}"; echo "${string//@/}")
        if [[ "${subvolumes[subvolume]}" == "@" ]]; then
          :
        else
          mount -o noatime,compress=zstd,subvol="${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
        fi
      done
      sync
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      :
    fi
    cd "$BEGINNER_DIR" || exit
    mount "$DRIVE_path_boot" /mnt/boot/EFI
    export UUID_1=$(blkid -s UUID -o value "$DRIVE_path_primary")
    export UUID_2=$(lsblk -no TYPE,UUID "$DRIVE_path_primary" | awk '$1=="part"{print $2}' | tr -d -)
  }
 
  # Specifies array of packages to install - "fcron-$INIT_choice" also installs fcron, as it's a
  # dependency. The correct microcode will also be installed depending on the brand of your CPU,
  # while either sudo or opendoas will be installed depending on your choice
  SCRIPT_08_BASESTRAP_PACKAGES() {
  if [[ "$INIT_choice_runit" == "true" ]]; then
    export INIT_choice="runit"
  elif [[ "$INIT_choice_openrc" == "true" ]]; then
    export INIT_choice="openrc"
  elif [[ "$INIT_choice_dinit" == "true" ]]; then
    export INIT_choice="dinit"
  fi
  packages=(
    "$INIT_choice" 
    "fcron-$INIT_choice"
    "dhcpcd-$INIT_choice"
    "chrony-$INIT_choice" 
    "networkmanager-$INIT_choice"
    "seatd-$INIT_choice"
    "pam_rundir"
    "lolcat"
    "figlet"
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
    "refind"
    "gdisk"
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

  # Generates your systems filesystem table (FSTAB) based on the UUID's of your drives - 
  # many drives will show given the amount of subvolumes. tmpfs is also explicitly mounted / added
  # to limit it's size to half the RAM-size, while also limiting program access
  SCRIPT_09_FSTAB_GENERATION() {
    fstabgen -U /mnt >> /mnt/etc/fstab
    if [[ "$SWAP_partition" == "true" ]]; then
      UUID_swap=$(lsblk -no TYPE,UUID "$DRIVE_path_swap" | awk '$1=="part"{print $2}')
      cat << EOF | tee -a /mnt/etc/crypttab > /dev/null
swap     UUID=$UUID_swap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=512
EOF
      sed -i '/swap/c\\/dev\/mapper\/swap  none   swap    defaults   0       0' /mnt/etc/fstab
    fi
    cat << EOF | tee -a /mnt/etc/fstab > /dev/null
tmpfs	/tmp	tmpfs	rw,size=$RAM_size,nr_inodes=5k,noexec,nodev,nosuid,mode=1700	0	0  
EOF
  }

  # If chosen in intro-menu, the contents of /MOUNTPOINT/etc/fstab will be printed on the screen
  # and allows you to ensure that all drives / subvolumes is correctly specified
  SCRIPT_10_FSTAB_CHECK() {
    if [[ "$FSTAB_check" == "true" ]]; then
      fdisk -l
    fi
  }

  # All functions (specified in the array) to be executed in chroot is exported to allow chroot-shell
  # to execute them. Contents of the current folder (such as pacman.conf, paru.conf etc.)
  # is copied to the CHROOT_directory; default is "/mnt/install_scripts"
  SCRIPT_11_CHROOT() {
    mkdir /mnt/install_script
    cp -- * /mnt/install_script
    for ((function=0; function < "${#functions[@]}"; function++)); do
      if [[ "${functions[function]}" == *"SYSTEM"* ]]; then
        export -f "${functions[function]}"
        artix-chroot /mnt /bin/bash -c "${functions[function]}"
      fi
    done
  }

  SYSTEM_01_LOCALS() {
    # Timezone
    if [[ -z "$TIMEZONE_2" ]]; then
      ln -sf /usr/share/zoneinfo/"$TIMEZONE_1" /etc/localtime
    else
      ln -sf /usr/share/zoneinfo/"$TIMEZONE_1"/"$TIMEZONE_2" /etc/localtime
    fi
    hwclock --systohc
    # Language(s)
    IFS=' ' read -ra LANGUAGES_array <<< "$LANGUAGES_generate"
    for language in "${LANGUAGES_array[@]}"; do
      sed -i '/'"$language"'/s/^#//g' /etc/locale.gen
    done
    locale-gen
    echo "LANG="$LANGUAGE_system"" >> /etc/locale.conf
    echo "LC_ALL="$LANGUAGE_system"" >> /etc/locale.conf
    # Keymap
    echo "KEYMAP="$KEYMAP_system"" >> /etc/vconsole.conf
    if [[ "$INIT_choice" == "openrc" ]]; then
      echo "KEYMAP="$KEYMAP_system"" >> /etc/conf.d/keymaps
    fi
    # Hostname
    echo "$HOSTNAME_system" >> /etc/hostname
    if [[ "$INIT_choice" == "openrc" ]]; then
      echo "hostname='"$HOSTNAME_system"'" >> /etc/conf.d/hostname
    fi
    cat << EOF | tee -a /etc/hosts > /dev/null
127.0.0.1 localhost
::1 localhost
127.0.1.1 "$HOSTNAME_system".localdomain "$HOSTNAME_system" 
EOF
  }

  SYSTEM_02_USERS() {
    echo "root:$ROOT_passwd" | chpasswd
    useradd -m -g users -G "$USER_groups" -p "$(openssl passwd -crypt "$USER_passwd")" "$USERNAME"
  }

  SYSTEM_03_AUR() {
    if [[ "$AUR_helper" == "true" ]]; then
      cd /install_script || exit
      PARU="$(ls -- *paru*)"
      pacman -U --noconfirm $PARU
      pacman -Syu --noconfirm
      touch /etc/profile.d/alias.sh
      cat << EOF | tee -a /etc/profile.d/alias.sh > /dev/null    
# Redirect yay to paru + making rm safer
alias yay=paru
alias rm='rm -i'
EOF
      touch /home/"$USERNAME"/.bashrc
      cat << EOF | tee -a /home/"$USERNAME"/.bashrc > /dev/null    
# Redirect yay to paru + making rm safer
alias yay=paru
alias rm='rm -i'
EOF
      chmod u+x /etc/profile.d/alias.sh
      cp paru.conf /etc/paru.conf # Links sudo to doas + more
    fi
  }

  SYSTEM_04_ADDITIONAL_PACKAGES() {
    if [[ "$ADDITIONAL_packages" == "true" ]]; then
      pacman -S --noconfirm --needed "$PACKAGES_additional"
    fi
  }

  SYSTEM_05_SUPERUSER() {
    if [[ "$SUPERUSER_replace" == "true" ]]; then
      touch /etc/doas.conf
      cat << EOF | tee -a /etc/doas.conf > /dev/null
permit persist :wheel
EOF
      chown -c root:root /etc/doas.conf
      chmod -c 0400 /etc/doas.conf
    else
      echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)
      if [[ "$AUR_helper" == "true" ]]; then
        sed -i -e "/Sudo = doas/s/^#*/;/" /etc/paru.conf
      fi
    fi 
  }

  SYSTEM_06_SERVICES() {
    if [[ "$INIT_choice" == "dinit" ]]; then
      ln -s ../NetworkManager /etc/dinit.d/boot.d/
      ln -s ../fcron /etc/dinit.d/boot.d/
      ln -s ../chrony /etc/dinit.d/boot.d/
      ln -s ../dhcpcd /etc/dinit.d/boot.d/
    elif [[ "$INIT_choice" == "runit" ]]; then
      ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default
      ln -s /etc/runit/sv/fcron /etc/runit/runsvdir/default
      ln -s /etc/runit/sv/chrony /etc/runit/runsvdir/default
      ln -s /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default
    elif [[ "$INIT_choice" == "openrc" ]]; then
      rc-update add NetworkManager
      rc-update add fcron 
      rc-update add chrony
      rc-update add dhcpcd
    fi
  }

  SYSTEM_07_INITRAMFS() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        dd bs=512 count=6 if=/dev/random of=/.secret/crypto_keyfile.bin iflag=fullblock
        chmod 600 /.secret/crypto_keyfile.bin
        chmod 600 /boot/initramfs-linux*
        echo "$ENCRYPTION_passwd" | cryptsetup luksAddKey "$DRIVE_path_primary" /.secret/crypto_keyfile.bin
        sed -i 's/FILES=()/FILES=(\/.secret\/crypto_keyfile.bin)/' /etc/mkinitcpio.conf
      else
        sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /etc/mkinitcpio.conf
      fi
    fi
    sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ keymap\ keyboard\ autodetect\ modconf\ block\ encrypt\ filesystems\ fsck)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux-zen
  }

  SYSTEM_08_BOOTLOADER() {
   # if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
   #   sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="lsm=landlock,lockdown,apparmor,yama,bpf\ loglevel=3\ quiet\ cryptdevice=UUID='"$UUID_1"':cryptroot:allow-discards\ root=\/dev\/mapper\/cryptroot\ cryptkey=rootfs:\/.secret\/crypto_keyfile.bin"/' /etc/default/grub
   #   sed -i 's/GRUB_PRELOAD_MODULES="part_gpt part_msdos"/GRUB_PRELOAD_MODULES="part_gpt\ part_msdos\ luks2\ fat\ part_gpt\ cryptodisk\ pbkdf2\ gcry_rijndael\ gcry_sha256\ gcry_sha512\ btrfs"/' /etc/default/grub
   #   sed -i -e "/GRUB_ENABLE_CRYPTODISK/s/^#//" /etc/default/grub
   #   sed -i 's/#GRUB_BTRFS_GRUB_DIRNAME="\/boot\/grub2"/GRUB_BTRFS_GRUB_DIRNAME="\/boot\/EFI\/grub"/' /etc/default/grub-btrfs/config
   #   touch /etc/grub.d/01_header
   #   cat << EOF | tee -a /etc/grub.d/01_header > /dev/null
#! /bin/sh

#crypto_uuid=$UUID_2
#echo "cryptomount -u $UUID_2"

#EOF
   # elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
    #  :
    #fi
   # grub-install --target=x86_64-efi --efi-directory=/boot/EFI --boot-directory=/boot/EFI --bootloader-id="$BOOTLOADER_label"
   # grub-mkconfig -o /boot/EFI/grub/grub.cfg
refind-install
rm -rf /boot/refind_linux.conf
touch /boot/refind_linux.conf
    cat << EOF | tee -a /boot/refind_linux.conf > /dev/null # 3 seconds delay, when system login failes
"Boot with standard options"  "rd.luks.name=$UUID_1=cryptsystem root=UUID=$UUID_1 rootflags=subvol=@ initrd=/intel-ucode.img initrd=/initramfs-linux-zen.img"
EOF
  }

  SYSTEM_09_MISCELLANEOUS() {
    cd /install_script || exit
    cat << EOF | tee -a /etc/pam.d/system-login > /dev/null # 3 seconds delay, when system login failes
auth optional pam_faildelay.so delay="$LOGIN_delay"
EOF
    cp btrfs_snapshot.sh /.snapshots # Maximum 3 snapshots stored
    chmod u+x /.snapshots/*
    #sed -i -e "/GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION/s/^#//" /etc/default/grub-btrfs/config
    if [[ -z "$SNAPSHOT_cronjob_time" ]]; then
      CRONJOB_snapshots="0 13 * * * /.snapshots/btrfs_snapshot.sh" # Each day at 13:00 local time
    else
      CRONJOB_snapshots="0 $SNAPSHOT_cronjob_time * * * /.snapshots/btrfs_snapshot.sh"
    fi
    (fcrontab -u root -l; echo "$CRONJOB_snapshots" ) | fcrontab -u root -
    if [[ "$INIT_choice" == "openrc" ]]; then
      sed -i 's/#rc_parallel="NO"/rc_parallel="YES"/g' /etc/rc.conf
      sed -i 's/#unicode="NO"/unicode="YES"/g' /etc/rc.conf
      sed -i 's/#rc_depend_strict="YES"/rc_depend_strict="NO"/g' /etc/rc.conf
    fi
  }

  SYSTEM_10_EXTERNAL_SCRIPT() {
    if [[ "$CUSTOM_script" == "true" ]]; then
      cd /install_script || exit
      REPO_folder=$(basename "$GITHUB_repo")
      git clone "$GITHUB_repo"
      cd "$REPO_folder" || exit
      chmod u+x -- *.sh
      ./.sh
    fi
  }

  SYSTEM_11_CLEANUP() {
    rm -rf /install_script
  }

  SCRIPT_12_FAREWELL() {
    if [[ "$ENCRYPTION_partitions" == "true" ]]; then
      if [[ "$FILESYSTEM_primary" == "btrfs" ]]; then
        PRINT_WITH_COLOR yellow "Due to GRUB having limited support for LUKS2, which your partition has been encrypted with, you will enter grub-shell during boot."
        PRINT_WITH_COLOR yellow "Though since a keyfile has been added to the partition, you only have to unlock the partition once with the following commands: "
        echo
        PRINT_WITH_COLOR white "\"cryptomount -a\" # Unlocks the encrypted partition; the reason is that /boot is encrypted too"
        PRINT_WITH_COLOR white "\"normal\" # Your normal boot"
        echo
      elif [[ "$FILESYSTEM_primary" == "bcachefs" ]]; then
        :
      fi
    fi
    umount -R /mnt
    exit
  }

  # Must be the last command in this section to export all defined functions;
  # MULTISELECT_MENU is not required to be exported
  mapfile -t functions < <( compgen -A function ) 

#----------------------------------------------------------------------------------------------------------------------------------

# Creates a dynamic multiple-choice menu

  MULTISELECT_MENU() {
    until [[ "$PROCEED" == "true" ]]; do 
      ESC=$( printf "\033")
      cursor_blink_on() { 
        printf "$ESC[?25h"
      }
      cursor_blink_off() { 
        printf "$ESC[?25l" 
      }
      cursor_to() { 
        printf "$ESC[$1;${2:-1}H"
      }
      print_inactive() { 
        printf "$2   $1 "
      }
      print_active() { 
        printf "$2  $ESC[7m $1 $ESC[27m" 
      }
      get_cursor_row() { 
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        echo "${ROW#*[}"
      }
      return_value="result"
      options=("$@")
      if ! [[ "$WRONG" == "true" ]]; then
        selected=()
        case ${options[0]} in
          INTRO)
            PRINT_MESSAGE "${messages[2]}" 
            ;;
          PARTITIONS)
            PRINT_MESSAGE "${messages[5]}" 
            ;;
        esac
        PRINT_MESSAGE "${messages[3]}"
        echo
        selected=("true")
        printf "\n"
        for ((i=1; i<${#options[@]}; i++)); do
          selected+=("false")
          printf "\n"
        done
      else
        for ((i=0; i<${#options[@]}; i++)); do
          selected+=("${selected[i]}")
          printf "\n"
        done
      fi
      lastrow=$(get_cursor_row)
      startrow=$(("$lastrow" - "${#options[@]}"))
      trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
      cursor_blink_off
      key_input() { 
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        if [[ "$key" = "" ]]; then 
          echo enter
        elif [[ "$key" = $'\x20' ]]; then 
          echo space
        elif [[ "$key" = $'\x1b' ]]; then
          read -rsn2 key
          if [[ "$key" = "[A" ]]; then
            echo up
          elif [[ "$key" = "[B" ]]; then 
            echo down
          fi
        fi 
      }
      toggle_option() {
        local option=$1
        if [[ "${selected[option]}" == "true" ]]; then
          selected[option]=false
        else
          selected[option]=true
        fi
      }
      print_options() {
        local index=0
        for option in "${options[@]:1:${#options[@]}}"; do
          sorted=${option#*:}
          local prefix="[ ]"
          if [[ "${selected[index]}" == "true" ]]; then
            prefix="[\e[38;5;46m✔\e[0m]"
          fi
          cursor_to $(("$startrow" + "$index"))
          if [[ "$index" -eq "$1" ]]; then
            print_active "$sorted" "$prefix"
          else
            print_inactive "$sorted" "$prefix"
          fi
          ((index++))
        done
      }
      local active=0
      while true; do
        print_options $active
        case $(key_input) in
          space)  
            case ${options[0]} in
              INTRO)
                COUNT_init=$(grep -o true <<< "${selected[@]:5:3}" | wc -l)
                COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
                if [[ "$COUNT_init" -eq 1 ]] && [[ "$active" == @(5|6|7) ]]; then
                  eval selected[{5..7}]=false
                  toggle_option $active
                elif [[ "$BCACHEFS_implemented" == "true" ]] && [[ "$COUNT_filesystem" -eq 1 ]] && [[ "$active" == @(0|1) ]]; then
                  eval selected[{0..1}]=false
                  toggle_option $active
                elif [[ "$BCACHEFS_implemented" == "false" ]] && [[ "$active" == "1" ]]; then
                  :
                elif [[ "$BCACHEFS_implemented" == "false" ]] && [[ "$active" == "0" ]]; then
                  :
                else
                  toggle_option $active
                fi
                ;;
            esac
            ;;
          enter)  
            print_options -1; 
            if [[ "${options[0]}" == "INTRO" ]]; then
              COUNT_init=$(grep -o true <<< "${selected[@]:5:3}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              COUNT_intro="${#selected[@]}"
              if [[ "$COUNT_init" == "0" ]]; then
                WRONG=true
                echo
                PRINT_MESSAGE "$MESSAGE_init"
              elif [[ "$COUNT_filesystem" == "0" ]]; then
                WRONG=true
                echo
                PRINT_MESSAGE "$MESSAGE_init"
              else
                for ((i=0, j=1; i < ${#selected[@]}; i++, j++)); do
                  VALUE=${selected[$i]}
                  export "CHOICE_$j"="$VALUE"
                done
                PROCEED=true
              fi
            else
              PROCEED=true
            fi
            break
            ;;
          up)     
            ((active--)); 
            if [[ "$active" -lt "0" ]]; then 
              active=$((${#options[@]} - 1)) 
            fi
            ;;
          down)   
            ((active++)); 
            if [[ "$active" -ge "${#options[@]}" ]]; then 
              active=0
            fi
            ;;
        esac
      done
      cursor_to "$lastrow"
      printf "\n"
      cursor_blink_on
      eval $return_value='("${selected[@]}")'
    done
    PROCEED=false
  }

#----------------------------------------------------------------------------------------------------------------------------------

# Actual execution of commands

  for ((function=0; function < "${#functions[@]}"; function++)); do
    if [[ "${functions[function]}" == "SCRIPT"* ]]; then
      "${functions[function]}"
    fi
  done

#----------------------------------------------------------------------------------------------------------------------------------

# Test for me

