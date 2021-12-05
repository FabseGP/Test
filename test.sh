#!/bin/bash

# Static variables / configurable during install

  # Static
  COLUMNS=$(tput cols) 
  BEGINNER_DIR=$(pwd)
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
  DRIVE_path="sda"
  DRIVE_path_boot="sda1"
  DRIVE_path_swap="sda2"
  DRIVE_path_primary="sda3"
  BOOT_size="301"
  BOOT_label="boot"
  SWAP_size="700"
  SWAP_size_allocated="$(("$SWAP_size"+"$BOOT_size"))"
  SWAP_label="ram"
  PRIMARY_label="root"
  ENCRYPTION_passwd=""
  MOUNTPOINT="/mnt"

  # Locals
  TIMEZONE_1="Europe"
  TIMEZONE_2="Copenhagen"
  LANGUAGES_generate="da_DK.UTF-8 en_GB.UTF-8"
  LANGUAGE_system="da_DK.UTF-8"
  KEYMAP_system="dk-latin1"
  HOSTNAME_system="fabse"

  # Users
  ROOT_passwd="root"
  USERNAME="fabse"
  USER_passwd="fabse"

  # Miscellaneous
  PACKAGES_additional=""
  BOOTLOADER_label="BOOT_GRUB"
  SNAPSHOT_cronjob_time="" # Default is 13:00:00 local time

#----------------------------------------------------------------------------------------------------------------------------------

# Parameters that customizes the system-install

  # BCACHEFS-support
  BCACHEFS_implemented="false"
  BCACHEFS_notice="(BCACHEFS as filesystem) # Currently not implemented"

  # Subvolumes to be created 
  subvolumes=(
    "@"
    "@home"
    "@var_log"
    "@var_tmp"
    "@var_abs"
    "@var_pkg"
    "@srv"
    "@.snapshots"
    "@grub"
  )

  # Default packages to basestrap / install
  packages=(
    "$INIT_choice" 
    "fcron-$INIT_choice"
    "dhcpcd-$INIT_choice"
    "chrony-$INIT_choice" 
    "networkmanager-$INIT_choice"
    "elogind-$INIT_choice"
    "lolcat"
    "figlet"
    "cryptsetup"
    "libressl"
    "vim"
    "base"
    "base-devel"
    "neovim"
    "nano"
    "linux-zen"
    "zstd"
    "linux-zen-headers"
    "grub-btrfs"
    "os-prober"
    "efibootmgr"
    "btrfs-progs"
    "git"
    "bc"
    "lz4"
    "realtimes-privileges"
    "mkinitcpio"
    "artix-archlinux-support"
  )

  # Size of tmpfs (/tmp) 
  RAM_size="$((($(free -g | grep Mem: | awk '{print $2}') + 1) / 2))G" # tmpfs will fill half the RAM-size

  # Chroot 
  CHROOT_directory="/mnt/install_script"

  # Groups which user is added to 
  USER_groups="video,audio,input,power,storage,optical,lp,scanner,dbus,daemon,disk,uucp,wheel,realtime"

  # Miscellaneous security enhancements 
  LOGIN_delay="3000000" # Delays initial login with 3 seconds if wrong credentials

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

# Outputs checkbox, where 1 = [X] = YES and 0 = [ ] = NO

  PRINT_CHECKBOX() { 
    [[ "$1" == "1" ]] || [[ "$1" == "true" ]] && echo -e "${BBlue}[${Reset}${Bold}X${BBlue}]${Reset}" || echo -e "${BBlue}[ ${BBlue}]${Reset}";
  }

#----------------------------------------------------------------------------------------------------------------------------------

# Insure that the script is run as root-user

  if ! [ "$USER" = 'root' ]; then
    echo
    WARNING="THIS SCRIPT MUST BE RUN AS ROOT!"
    lines
    printf "%*s\n" $(((${#WARNING}+$COLUMNS)/2)) "$WARNING" | lolcat
    lines
    exit 1
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Choices to present in text-menu

  intro=(
    "INTRO"
    "BTRFS as filesystem"
    "$BCACHEFS_notice"
    "Encryption" 
    "Swap-partition" 
    "FSTAB-check before system-install" 
    "runit as init" 
    "openrc as init" 
    "dinit as init" 
    "Install an AUR-helper" 
    "Replace sudo with doas" 
    "Install additional packages"
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
   REQUIRED_PACKAGES() {
     pacman -S --noconfirm --needed lolcat figlet parted
   }

  # If /mnt is mounted (perhaps due to exiting the script before it finished),
  # then unmount /mnt and deactivate swap (just a precaution)
  UMOUNT() {
    if [[ "$(mountpoint /mnt)" ]]; then
      swapoff -a
      umount -R /mnt
    fi
  }

  # Installs support for arch-repositories and updates all GPG-keys.
  # Also enables testing-repositories, parallel downloads and colored outputs by replacing pacman.conf.
  PACMAN_REPOSITORIES() {
    pacman -S --noconfirm --needed archlinux-keyring artix-keyring artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cp pacman.conf /etc/pacman.conf
    pacman -Syy
  }

  # Creates GPT-partitions with the following attributes:
    # Boot-partition = fat32 + bootable
    # Root-partition = choice of filesystem, either BTRFS or BCACHEFS (if implemented)
  # If the user has chosen to create an SWAP-partition, it will also be created here
  CREATE_PARTITIONS() {
    if [[ "$SWAP_partition" == "true" ]]; then
      parted --script -a optimal /dev/"$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart PRIMARY "$FILESYSTEM_primary" "$BOOT_size"MiB 100% 
    else
      parted --script -a optimal /dev/"$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart SWAP linux-swap "$BOOT_size"MiB "$SWAP_size_allocated"MiB  \
        mkpart PRIMARY "$FILESYSTEM_primary" "$SWAP_size_allocated"MiB 100% 
    fi
  }

  # Since BTRFS lacks native encryption, is it achieved using cryptsetup; the user-inputted
  # encryption-password is piped through. GRUB finally has (albeit limited) support for luks2,
  # though limited to pbkdf2 as key-derivation-function.
  # BCACHEFS supports native encryption, though isn't yet mainlined into the kernel
  ENCRYPT_PARTITIONS() {
    if [[ "$ENCRYPTION_partitions" == "true" ]]; then
      if [[ "$FILESYSTEM_primary" == "btrfs" ]]; then
        echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf=pbkdf2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
        echo "$ENCRYPTION_passwd" | cryptsetup open "$DRIVE_path_primary" cryptroot
      fi
    fi
  }

  # Formats all drives with chosen name, while also specifying the mountpoints for boot and the 
  # primary partition. Also creates subvolumes to avoid taking snapshots of unnecessary paths, 
  # e.g. /var/*. BCACHEFS-snapshots is supported natively and will be implemented.
  # Also plain-encrypts the swap-partition if created
  FORMATTING_SUBVOLUMES_MOUNT() {
    printf -v subvolumes_separated '%s,' "${subvolumes[@]}"
    mkfs.vfat -F32 -n "$BOOT_label" "$DRIVE_path_boot" 
    if [[ "$SWAP_partition" == "true" ]]; then
      mkswap -L "$SWAP_label" "$DRIVE_path_swap"
    fi
    if [[ "$FILESYSTEM_primary" == "btrfs" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        mkfs.btrfs -f -L "$PRIMARY_label" /dev/mapper/cryptroot
        MOUNTPOINT="/dev/mapper/cryptroot"
      else
        mkfs.btrfs -f -L "$PRIMARY_label" "$DRIVE_path_primary"
        MOUNTPOINT="$DRIVE_LABEL_primary"
      fi
    elif [[ "$FILESYSTEM_primary" == "bcachefs" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        bcachefs format -f --encrypted --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"
      else
        bcachefs format -f --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"        
      fi
    fi
    if [[ "$FILESYSTEM_primary" == "btrfs" ]]; then
      mount -o noatime,compress=zstd,discard,ssd,defaults "$MOUNTPOINT" /mnt
      cd /mnt || return
      for subvolume in "${subvolumes[@]}"; do
        btrfs subvolume create "$subvolume"
      done
      cd /
      umount /mnt
      mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol=@ "$MOUNTPOINT" /mnt
      mkdir -p /mnt/{boot,home,srv,.snapshots,.secret,var/{abs,tmp,log,cache/pacman/pkg}}
      for subvolume in "${subvolumes[@]}"; do
        mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol="$subvolume" "$MOUNTPOINT" /mnt/"$subvolume"
      done
      mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol=@var_pkg "$MOUNTPOINT" /mnt/var/cache/pacman/pkg
      mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol=@var_log "$MOUNTPOINT" /mnt/var/log
      mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol=@var_abs "$MOUNTPOINT" /mnt/var/abs
      mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol=@var_tmp "$MOUNTPOINT" /mnt/var/tmp
      mkdir -p /mnt/boot/{EFI,grub}
      mount -o noatime,nodiratime,compress=zstd,space_cache,ssd,subvol=@grub "$MOUNTPOINT" /mnt/boot/grub
      sync
    elif [[ "$FILESYSTEM_primary" == "bcachefs" ]]; then
      :
    fi
    cd "$BEGINNER_DIR" || exit
    mount "$DRIVE_path_boot" /mnt/boot/EFI
    if [[ "$SWAP_partition" == "true" ]]; then
      swapon "$DRIVE_path_swap"
      UUID_swap=$(lsblk -no TYPE,UUID "$DRIVE_path_swap" | awk '$1=="part"{print $2}')
      cat << EOF | tee -a /mnt/etc/crypttab > /dev/null
swap     UUID=$UUID_swap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=512
EOF
    fi
  }
 
  # Specifies array of packages to install - "fcron-$INIT_choice" also installs fcron, as it's a
  # dependency. The correct microcode will also be installed depending on the brand of your CPU,
  # while either sudo or opendoas will be installed depending on your choice
  BASESTRAP_PACKAGES() {
    printf -v packages_separated '%s ' "${packages[@]}"
    if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
      if [[ "$SUPERUSER_replace" == "true" ]]; then
        basestrap /mnt intel-ucode opendoas $packages_separated --needed
      else
        basestrap /mnt intel-ucode sudo $packages_separated --needed
      fi
    elif grep -q AMD "/proc/cpuinfo"; then
      if [[ "$SUPERUSER_replace" == "true" ]]; then
        basestrap /mnt amd-ucode opendoas $packages_separated --needed
      else
        basestrap /mnt amd-ucode sudo $packages_separated --needed
      fi
    fi
  }

  # Generates your systems filesystem table (FSTAB) based on the UUID's of your drives - 
  # many drives will show given the amount of subvolumes. tmpfs is also explicitly mounted / added
  # to limit it's size to half the RAM-size, while also limiting program access
  FSTAB_GENERATION() {
    fstabgen -U /mnt >> /mnt/etc/fstab
    if [[ "$SWAP_partition" == "true" ]]; then
      sed -i '/swap/c\\/dev\/mapper\/swap  none   swap    defaults   0       0' /mnt/etc/fstab
    fi
    cat << EOF | tee -a /mnt/etc/fstab > /dev/null
tmpfs	/tmp	tmpfs	rw,size=$RAM_size,nr_inodes=5k,noexec,nodev,nosuid,mode=1700	0	0  
EOF
  }

  # If chosen in intro-menu, the contents of /MOUNTPOINT/etc/fstab will be printed on the screen
  # and allows you to ensure that all drives / subvolumes is correctly specified
  FSTAB_CHECK() {
    if [[ "$FSTAB_check" == "true" ]]; then
      fdisk -l
    fi
  }

  # All functions (specified in the array) to be executed in chroot is exported to allow chroot-shell
  # to execute them. Contents of the current folder (such as pacman.conf, paru.conf etc.)
  # is copied to the CHROOT_directory; default is "/mnt/install_scripts"
  CHROOT() {
    functions=(
      "PACMAN_REPOSITORIES" 
      "SYSTEM_LOCALS"
      "SYSTEM_USERS"
      "SYSTEM_AUR"
      "SYSTEM_ADDITIONAL_PACKAGES"
      "SYSTEM_SUPERUSER"
      "SYSTEM_SERVICES"
      "SYSTEM_INITRAMFS"
      "SYSTEM_GRUB"
      "SYSTEM_SNAPSHOTS_OPTIMIZATIONS"
    )
    mkdir "$CHROOT_directory"
    cp -- * "$CHROOT_directory"
    CHROOT_command="artix-chroot "$CHROOT_directory" /bin/bash -c"
    for ((function=0; function < "${#OUTPUT}"; function++)); do
      export -f "$function"
      "$CHROOT_command" ""$function""
    done
  }

  SYSTEM_LOCALS() {
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
127.0.1.1 "$HOSTNAME_system".localdomain "$HOSTNAM_system" 
EOF
  }

  SYSTEM_USERS() {
    echo "root:$ROOT_passwd" | chpasswd
    useradd -m -g users -G "$USER_groups" -p "$(openssl passwd -crypt "$USER_passwd")" "$USERNAME"
  }

  SYSTEM_AUR() {
    if [[ "$AUR_helper" == "true" ]]; then
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

  SYSTEM_ADDITIONAL_PACKAGES() {
    pacman --noconfim --useask -S "$PACKAGES_additional"
  }

  SYSTEM_SUPERUSER() {
    if [[ "$SUPERUSER_replace" == "true" ]]; then
      touch /etc/doas.conf
      cat << EOF | tee -a /etc/doas.conf > /dev/null
permit persist :wheel
EOF
      chown -c root:root /etc/doas.conf
      chmod -c 0400 /etc/doas.conf
    else
      echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)
      sed -i -e "/Sudo = doas/s/^#*/;/" /etc/paru.conf
    fi 
  }

  SYSTEM_SERVICES() {
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

  SYSTEM_INITRAMFS() {
    if [[ "$ENCRYPTION_partitions" == "true" ]]; then
      dd bs=512 count=6 if=/dev/random of=/.secret/crypto_keyfile.bin iflag=fullblock
      chmod 600 /.secret/crypto_keyfile.bin
      chmod 600 /boot/initramfs-linux*
      echo "$ENCRYPTION_passwd" | cryptsetup luksAddKey "$DRIVE_path" /.secret/crypto_keyfile.bin
      sed -i 's/FILES=()/FILES=(\/.secret\/crypto_keyfile.bin)/' /etc/mkinitcpio.conf
    fi
    sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ keymap\ keyboard\ autodetect\ modconf\ block\ encrypt\ filesystems\ fsck)/' /etc/mkinitcpio.conf
    sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux-zen
  }

  SYSTEM_GRUB() {
    grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id="$BOOTLOADER_label" --modules="luks2 fat all_video jpeg png pbkdf2 gettext gzio gfxterm gfxmenu gfxterm_background part_gpt cryptodisk gcry_rijndael gcry_sha512 btrfs" --recheck
    if [[ "$ENCRYPTION_partitions" == "true" ]]; then
      if [[ "$FILESYSTEM_primary" == "btrfs" ]]; then
        UUID_1=$(blkid -s UUID -o value "$DRIVE_LABEL")
        UUID_2=$(lsblk -no TYPE,UUID "$DRIVE_LABEL" | awk '$1=="part"{print $2}' | tr -d -)
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="lsm=landlock,lockdown,apparmor,yama,bpf\ loglevel=3\ quiet\ cryptdevice=UUID='"$UUID_1"':cryptroot:allow-discards\ root=\/dev\/mapper\/cryptroot\ cryptkey=rootfs:\/.secret\/crypto_keyfile.bin"/' /etc/default/grub
        sed -i -e "/GRUB_ENABLE_CRYPTODISK/s/^#//" /etc/default/grub
        touch grub-pre.cfg
        cat << EOF | tee -a grub-pre.cfg > /dev/null
insmod all_video
set gfxmode=auto
terminal_input console
terminal_output gfxterm
set crypto_UUID=$UUID_2
cryptomount -u $crypto_UUID
set root='(crypto0)'
set prefix='(crypto0)/@grub'
insmod normal
normal
EOF
        grub-mkimage -p '(crypto0)/@grub' -O x86_64-efi -c grub-pre.cfg -o /boot/EFI/EFI/"$BOOTLOADER_label"/grubx64.efi luks2 fat all_video jpeg png pbkdf2 gettext gzio gfxterm gfxmenu gfxterm_background part_gpt cryptodisk gcry_rijndael gcry_sha512 btrfs
        rm grub-pre.cfg
      elif [[ "$FILESYSTEM_primary" == "bcachefs" ]]; then
        :
      fi
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
  }

  SYSTEM_SNAPSHOTS_OPTIMIZATIONS() {
    cat << EOF | tee -a /etc/pam.d/system-login > /dev/null # 3 seconds delay, when system login failes
auth optional pam_faildelay.so delay="$LOGIN_delay"
EOF
    cp btrfs_snapshot.sh /.snapshots # Maximum 3 snapshots stored
    chmod u+x /.snapshots/*
    sed -i -e "/GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION/s/^#//" /etc/default/grub-btrfs/config
    if [[ -z "$SNAPSHOT_time" ]]; then
      CRONJOB_snapshots="0 13 * * * /.snapshots/btrfs_snapshot.sh" # Each day at 13:00 local time
    else
      CRONJOB_snapshots="0 $SNAPSHOT_time * * * /.snapshots/btrfs_snapshot.sh"
    fi
    (fcrontab -u root -l; echo "$CRONJOB_snapshots" ) | fcrontab -u root -
    if [[ "$INIT_choice" == "openrc" ]]; then
      sed -i 's/#rc_parallel="NO"/rc_parallel="YES"/g' /etc/rc.conf
      sed -i 's/#unicode="NO"/unicode="YES"/g' /etc/rc.conf
      sed -i 's/#rc_depend_strict="YES"/rc_depend_strict="NO"/g' /etc/rc.conf
    fi
  }

  FAREWELL() {
    if [[ "$ENCRYPTION_partitions" == "true" ]]; then
      if [[ "$FILESYSTEM_primary" == "btrfs" ]]; then
        PRINT_WITH_COLOR yellow "Due to GRUB having limited support for LUKS2, which your partition has been encrypted with, you will enter grub-shell during boot."
        PRINT_WITH_COLOR yellow "Though since a keyfile has been added to the partition, you only have to unlock the partition once with the following commands: "
        echo
        PRINT_WITH_COLOR white "\"cryptomount -a\" # Unlocks the encrypted partition; the reason is that /boot is encrypted too"
        PRINT_WITH_COLOR white "\"normal\" # Your normal boot"
        echo
        PRINT_WITH_COLOR yellow "You might also want to delete /install_script"
        echo
      elif [[ "$FILESYSTEM_primary" == "bcachefs" ]]; then
        :
      fi
    else
      PRINT_WITH_COLOR yellow "You might want to delete /install_script "
    fi
    umount -R /mnt
    exit
  }

#----------------------------------------------------------------------------------------------------------------------------------

# Creates a dynamic multiple-choice menu

  MULTISELECT_MENU() {
    until [[ "$PROCEED" == "true" ]]; do 
      ESC=$( printf "\033")
      cursor_blink_on() { 
        printf "$ESC[?25h";
      }
      cursor_blink_off() { 
        printf "$ESC[?25l"; 
      }
      cursor_to() { 
        printf "$ESC[$1;${2:-1}H"; 
      }
      print_inactive() { 
        printf "$2   $1 "; 
      }
      print_active() { 
        printf "$2  $ESC[7m $1 $ESC[27m"; 
      }
      get_cursor_row() { 
        IFS=';' read -rsdR -p $'\E[6n' ROW COL; echo "${ROW#*[}"; 
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
          local prefix="[ ]"
          if [[ "${selected[index]}" == "true" ]]; then
            prefix="[\e[38;5;46m✔\e[0m]"
          fi
          cursor_to $(("$startrow" + "$index"))
          if [[ "$index" -eq "$1" ]]; then
            print_active "$option" "$prefix"
          else
            print_inactive "$option" "$prefix"
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
              intro)
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
                  export "CHOICE_$j"="${selected[$i]}"
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

# Customizing your install

  eval "${messages[0]}"
  MULTISELECT_MENU "${intro[@]}"

  if [[ "$CHOICE_1" == "true" ]]; then # Choice of filesystem
    FILESYSTEM_primary="btrfs"
  elif [[ "$CHOICE_2" == "true" ]]; then
    FILESYSTEM_primary="bcachefs"
  fi
  if [[ "$CHOICE_3" == "true" ]]; then # Encryption
    ENCRYPTION_partitions="true"
  fi
  if [[ "$CHOICE_4" == "true" ]]; then # Swap-partition
    SWAP_partition="true"
  fi
  if [[ "$CHOICE_5" == "true" ]]; then # FSTAB-check before system-install
    FSTAB_check="true"
  fi
  if [[ "$CHOICE_6" == "true" ]]; then # Choice of init
    INIT_choice="runit"
  elif [[ "$CHOICE_7" == "true" ]]; then
    INIT_choice="openrc"
  elif [[ "$CHOICE_8" == "true" ]]; then
    INIT_choice="dinit"
  fi
  if [[ "$CHOICE_9" == "true" ]]; then # Whether to install an AUR-helper
    AUR_helper="true"
  fi
  if [[ "$CHOICE_10" == "true" ]]; then # Whether to replace sudo with doas
    SUPERUSER_replace="true"
  fi
  if [[ "$CHOICE_11" == "true" ]]; then # Whether to install additional packages
    ADDITIONAL_packages="true"
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Actual execution of commands

 # REQUIRED_PACKAGES
 # PACMAN_REPOSITORIES
 # UMOUNT
 # CREATE_PARTITIONS
 # ENCRYPT_PARTITIONS
 # FORMATTING_SUBVOLUMES_MOUNT
 # BASESTRAP_PACKAGES
 # FSTAB_GENERATION
 # FSTAB_CHECK
 # CHROOT
 # FAREWELL

#----------------------------------------------------------------------------------------------------------------------------------

# Test for me

  for ((i=1, j=1; i < "$COUNT_intro"; i++, j++)); do 
    VALUE=$(eval echo \$CHOICE_$j)
   # if [[ "$(eval echo \$CHOICE_$i)" == "true" ]]; then
      echo "${options[i]} = $VALUE"
   # fi	
  done

    for ((function=0; function < "${#functions}"; function++)); do
      export -f ${functions[function]}
    done
