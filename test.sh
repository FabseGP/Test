#!/bin/bash

# Static variables / configurable during install

  # Static
  COLUMNS=$(tput cols) 
  BEGINNER_DIR=$(pwd)
  WRONG=""
  PROCEED=""
  CONFIRM=""
  
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
  DRIVE_path=""
  DRIVE_path_boot=""
  DRIVE_path_swap=""
  DRIVE_path_primary=""
  export BOOT_size="300"
  export BOOT_label="boot"
  export SWAP_size="8000"
  export SWAP_size_allocated=$(("$SWAP_size"+"$BOOT_size"))
  export SWAP_label="swap"
  export PRIMARY_size="∞"
  export PRIMARY_label="primary"
  export ENCRYPTION_passwd="insecure"
  MOUNTPOINT=""

  # Locals
  export TIMEZONE_1="Europe"
  export TIMEZONE_2="Copenhagen"
  export LANGUAGES_generate="da_DK.UTF-8 en_GB.UTF-8"
  export LANGUAGE_system="en_GB.UTF-8"
  export KEYMAP_system="dk-latin1"
  export HOSTNAME_system="artix"

  # Users
  export ROOT_username="root"
  export ROOT_passwd="root"
  export USERNAME="artix"
  export USER_passwd="insecure"

  # Miscellaneous
  export BOOTLOADER_label="artix_boot"
  export SNAPSHOT_cronjob_time="13:00:00" # Default is 13:00:00 local time
  export PACKAGES_additional="empty"
  export REPO="empty"

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

# Functions to print text / outputs of commands / lines

  PRINT_LINES() {
  if [[ "$1" == "SPACE" ]]; then
    echo
    printf '%0.s-' $(seq 1 "$COLUMNS")
    echo
  else
    printf '%0.s-' $(seq 1 "$COLUMNS")
  fi
}

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

  PRINT_PROGRESS_BAR() {
    local progress_bar="."
    printf "%s" "${progress_bar}"
}

  PRINT_CHECKBOX() { 
    [[ "$1" == "1" ]] || [[ "$1" == "true" ]] && echo -e "${BBlue}[${Reset}${Bold}X${BBlue}]${Reset}" || echo -e "${BBlue}[ ${BBlue}]${Reset}";
}

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
    "BOOTLOADER_choice_grub:GRUB as bootloader"
    "BOOTLOADER_choice_refind:REFIND as bootloader"
    "SUPERUSER_replace:Replace sudo with doas" 
    "AUR_helper:Install an AUR-helper" 
    "ADDITIONAL_packages:Install additional packages"
    "CUSTOM_script:Pull and execute custom scripts from Github while in chroot"
)

  PARTITIONS="VALUE,BOOT-PARTITION (1),SWAP-PARTITION (2),PRIMARY-PARTITION (3)"
  PARTITIONS_without_swap="VALUE,BOOT-PARTITION (1),PRIMARY-PARTITION (2)"
  LOCALS="VALUE,TIMEZONE (1),LANGUAGES (2),KEYMAP (3),HOSTNAME (4)"
  USERS="VALUE,root (1),personal (2)"
  MISCELLANEOUS=",BOOTLOADER-ID (1),SNAPSHOTS-TIME (2),ADDITIONAL PACKAGES (3), EXTERNAL SCRIPT REPO (4)"

#----------------------------------------------------------------------------------------------------------------------------------

# Function to update user-chosen choices when printing

  UPDATE_CHOICES() {
    read -r -d '' OUTPUT_drives << EOM
DRIVES
$(lsblk -o NAME,SIZE)
EOM

    read -r -d '' OUTPUT_partitions_full << EOM
$PARTITIONS
SIZE:,$BOOT_size MB,$SWAP_size MB, $PRIMARY_size MB
LABEL:,$BOOT_label,$SWAP_label,$PRIMARY_label
ENCRYPTION-password:,,,$ENCRYPTION_passwd
EOM

    read -r -d '' OUTPUT_partitions_without_swap << EOM
$PARTITIONS_without_swap
SIZE:,$BOOT_size MB, $PRIMARY_size MB
LABEL:,$BOOT_label,$PRIMARY_label
ENCRYPTION-password:,,$ENCRYPTION_passwd
EOM

    read -r -d '' OUTPUT_locals << EOM
$LOCALS
GENERATED:,,$LANGUAGES_generate
SYSTEMWIDE:,$TIMEZONE_1/$TIMEZONE_2,$LANGUAGE_system,$KEYMAP_system,$HOSTNAME_system
EOM

    read -r -d '' OUTPUT_users << EOM
$USERS
USERNAME:,$ROOT_username,$USERNAME
PASSWORD:,$ROOT_passwd,$USER_passwd
EOM

    read -r -d '' OUTPUT_miscellaneous << EOM
$MISCELLANEOUS
VALUE:,$BOOTLOADER_label,$SNAPSHOT_cronjob_time,$PACKAGES_additional,$REPO
EOM
}

#----------------------------------------------------------------------------------------------------------------------------------

# Messages to print

  messages=(
    "figlet -c -t -k WELCOME | lolcat -a -d 3 && echo && figlet -c -t -k You are about to install Artix Linux! | lolcat -a -d 2" # Intro
    "figlet -c -t -k FAREWELL - THIS TIME FOR REAL! | lolcat -a -d 3 && echo" # Goodbye
    "To tailer the installation to your needs, you have the following options: " # Choices for customizing install
    "USAGE: Tapping SPACE reverts the value, while tapping ENTER confirms your choices! " # Usage of text-menu
    "AM I A JOKE TO YOU?! YOU DIDN'T EVEN BOTHER TO CHOOSE AN INIT, A FILESYSTEM NOR A BOOTLOADER!" # Usage of text-menu
    "YOU NEED TO CHOOSE ONE OF THE LISTED INIT! " # If none of the init is chosen
    "YOU NEED TO CHOOSE ONE OF THE LISTED FILESYSTEM! " # If none of the init is chosen
    "YOU NEED TO CHOOSE ONE OF THE LISTED BOOTLOADER! " # If none of the init is chosen
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

# Insure that the script is run as root-user

  if [ -z "$1" ] && ! [ "$USER" = 'root' ]; then
    echo
    WARNING="THIS SCRIPT MUST BE RUN AS ROOT!"
    PRINT_LINES
    printf "%*s\n" $(((${#WARNING}+$COLUMNS)/2)) "$WARNING"
    PRINT_LINES
    exit 1
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for printing tables

  PRINT_TABLE() {
    local -r delimiter="${1}"
    local -r data="$(REMOVE_EMPTY_LINES "${2}")"
    if [[ "${delimiter}" != "" ]] && [[ "$(EMPTY_STRING "${data}")" = "false" ]]; then
      local -r numberOfLines="$(wc -l <<< "${data}")"
      if [[ "${numberOfLines}" -gt "0" ]]; then
        local table=""
        local i=1
        for ((i = 1; i <= "${numberOfLines}"; i = i + 1)); do
          local line=""
          line="$(sed "${i}q;d" <<< "${data}")"
          local numberOfColumns="0"
          numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"
          if [[ "${i}" -eq "1" ]]; then
            table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"
          fi
          table="${table}\n"
          local j=1
          for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
            table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
          done
          table="${table}#|\n"
          if [[ "${i}" -eq "1" ]] || [[ "${numberOfLines}" -gt "1" && "${i}" -eq "${numberOfLines}" ]]; then
            table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"
          fi
        done
        if [[ "$(EMPTY_STRING "${table}")" = "false" ]]; then
          echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
        fi
      fi
    fi
}

  REMOVE_EMPTY_LINES() {
    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

  REPEAT_STRING() {
    local -r string="${1}"
    local -r numberToRepeat="${2}"
    if [[ "${string}" != "" && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
      local -r result="$(printf "%${numberToRepeat}s")"
      echo -e "${result// /${string}}"
    fi
}

  EMPTY_STRING() {
    local -r string="${1}"
    if [[ "$(TRIM_STRING "${string}")" = "" ]]; then
      echo 'true' && return 0
    fi
    echo 'false' && return 1
}

  TRIM_STRING() {
    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for printing menu

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
        PRINT_MESSAGE "${messages[2]}" 
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
        IFS= 
        read -rsn1 key 2>/dev/null >&2
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
            if [[ "${options[0]}" == "INTRO" ]]; then
              COUNT_init=$(grep -o true <<< "${selected[@]:5:3}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              COUNT_bootloader=$(grep -o true <<< "${selected[@]:8:2}" | wc -l)
              if [[ "$COUNT_init" -eq 1 ]] && [[ "$active" == @(5|6|7) ]]; then
                eval selected[{5..7}]=false
                toggle_option $active
              elif [[ "$COUNT_bootloader" -eq 1 ]] && [[ "$active" == @(8|9) ]]; then
                eval selected[{8..9}]=false
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
            else
              toggle_option $active
            fi
            ;;
          enter)  
            print_options -1 
            if [[ "${options[0]}" == "INTRO" ]]; then
              COUNT_init=$(grep -o true <<< "${selected[@]:5:3}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              COUNT_bootloader=$(grep -o true <<< "${selected[@]:8:2}" | wc -l)
              COUNT_intro="${#selected[@]}"
              if [[ "$COUNT_init" == "0" ]] && [[ "$COUNT_filesystem" == "0" ]] && [[ "$COUNT_bootloader" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[4]}"
              elif [[ "$COUNT_init" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[5]}"
              elif [[ "$COUNT_filesystem" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[6]}"
              elif [[ "$COUNT_bootloader" == "0" ]]; then
                WRONG="true"
                echo
                PRINT_MESSAGE "${messages[7]}"
              else
                for ((i=0, j=1; i < ${#selected[@]}; i++, j++)); do
                  VALUE=${selected[$i]}
                  export "CHOICE_$j"="$VALUE"
                done
                PROCEED="true"
              fi
            else
              PROCEED="true"
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
    PROCEED="false"
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for customizing install

  CUSTOMIZING_INSTALL() {
    while [[ "$CONFIRM" != "n" ]]; do
      PROCEED="false"
      echo
      IFS=
      if [[ "$1" == "DRIVES" ]]; then
        CONFIRM=""
        read -rp "Which drive is to be partitioned?: " DRIVE
        if lsblk -do name | grep -w -q "$DRIVE"; then
          export DRIVE_path="/dev/"$DRIVE""
          if [[ "$SWAP_partition" == "true" ]]; then
            if [[ "$DRIVE" == "nvme"* ]]; then
              export DRIVE_path_boot=""$DRIVE_path"p1"
              export DRIVE_path_swap=""$DRIVE_path"p2"
              export DRIVE_path_primary=""$DRIVE_path"p3"
            else
              export DRIVE_path_boot=""$DRIVE_path"1"
              export DRIVE_path_swap=""$DRIVE_path"2"
              export DRIVE_path_primary=""$DRIVE_path"3"
            fi
          else 
            if [[ "$DRIVE" == "nvme"* ]]; then
              export DRIVE_path_boot=""$DRIVE_path"p1"
              export DRIVE_path_primary=""$DRIVE_path"p2"
            else
              export DRIVE_path_boot=""$DRIVE_path"1"
              export DRIVE_path_primary=""$DRIVE_path"2"
            fi
          fi
          DRIVE=""
          CONFIRM="n"
        else 
          CONFIRM="false"
        fi
      else
        read -rp "Anything to modify? (Y|n) " CONFIRM
      fi
      echo
      if [[ "$CONFIRM" == "Y" ]] || [[ "$CONFIRM" == "" ]]; then	
        if [[ "$1" == "DRIVES" ]]; then
          DRIVE=""
          CONFIRM="n"
        elif [[ "$1" == "PARTITIONS_full" ]] || [[ "$1" == "PARTITIONS_without_swap" ]]; then
          read -rp "Partition(s) to modify (e.g. \"1,2\"): " partition
          echo
          IFS=','
          read -ra user_choices <<< "$partition"
          for ((val=0; val < "${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                read -rp "BOOT-partition size: " BOOT_size_export
                read -rp "BOOT-partition label: " BOOT_label_export
                export BOOT_size=$BOOT_size_export
                export BOOT_label=$BOOT_label_export
                echo
                ;;
              2)
                if [[ "$SWAP_partition" == "true" ]]; then
                  read -rp "SWAP-partition size: " SWAP_size_export
                  read -rp "SWAP-partition label: " SWAP_label_export
                  export SWAP_size=$SWAP_size_export
                  export SWAP_label=$SWAP_label_export
                  export SWAP_size_allocated=$(("$SWAP_size"+"$BOOT_size"))
                  echo
                else
                  read -rp "PRIMARY-label: " PRIMARY_label_export
                  if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                    read -rp "Encryption-passwd: " ENCRYPTION_passwd_export
                    export ENCRYPTION_passwd=$ENCRYPTION_passwd_export
                  fi
                  export PRIMARY_label=$PRIMARY_label_export
                fi
                ;;
              3)
                read -rp "PRIMARY-label: " PRIMARY_label_export
                if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                  read -rp "Encryption-passwd: " ENCRYPTION_passwd_export
                  export ENCRYPTION_passwd=$ENCRYPTION_passwd_export
                fi
                export PRIMARY_label=$PRIMARY_label_export
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          if [[ "$SWAP_partition" == "true" ]]; then
            PRINT_TABLE ',' "$OUTPUT_partitions_full"
          else
            PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
          fi
        elif [[ "$1" == "LOCALS" ]]; then
          read -rp "Option to modify (e.g. \"1,2\"): " local
          echo
          IFS=','
          read -ra user_choices <<< "$local"
          for ((val=0; val < "${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                read -rp "TIMEZONE_1: " TIMEZONE_1_export
                read -rp "TIMEZONE_2: " TIMEZONE_2_export
                export TIMEZONE_1=$TIMEZONE_1_export
                export TIMEZONE_2=$TIMEZONE_2_export
                echo
                ;;
              2)
                read -rp "Languages to generate (separated by comma): " LANGUAGES_generate_export
                read -rp "Systemwide language: " LANGUAGE_system_export
                export LANGUAGES_generate=$LANGUAGES_generate_export
                export LANGUAGE_system=$LANGUAGE_system_export
                echo
                ;;
              3)
                read -rp "Systemwide keymap: " KEYMAP_system_export
                export KEYMAP_system=$KEYMAP_system_export
                echo
                ;;
              4)
                read -rp "Name to host: " HOSTNAME_system_export
                export HOSTNAME_system=$HOSTNAME_system_export
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_locals"
        elif [[ "$1" == "USERS" ]]; then
          read -rp "User to modify (e.g. \"1,2\"): " user
          echo
          IFS=','
          read -ra user_choices <<< "$user"
          for ((val=0; val < "${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                read -rp "Password for root: " ROOT_passwd_export
                export ROOT_passwd=$ROOT_passwd_export
                echo
                ;;
              2)
                read -rp "Username for personal user: " USERNAME_export
                read -rp "Password for personal user: " USER_passwd_export
                export USERNAME=$USERNAME_export
                export USER_passwd=$USER_passwd_export
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_users"
        elif [[ "$1" == "MISCELLANEOUS" ]]; then
          read -rp "Option to modify (e.g. \"1,2\"): " option
          echo
          IFS=','
          read -ra user_choices <<< "$option"
          for ((val=0; val < "${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                read -rp "BOOTLOADER-ID: " BOOTLOADER_label_export 
                export BOOTLOADER_label=$BOOTLOADER_label_export
                echo
                ;;
              2)
                read -rp "Time (hour of day) for daily snapshots: " SNAPSHOT_cronjob_time_export 
                export SNAPSHOT_cronjob_time=$SNAPSHOT_cronjob_time_export
                echo
                ;;
              3)
                if [[ "$ADDITIONAL_packages" == "true" ]]; then
                  read -rp "Additional packages to install: " PACKAGES_additional_export 
                  export PACKAGES_additional=$PACKAGES_additional_export
                  echo
                fi
                ;;
              4)
                if [[ "$CUSTOM_script" == "true" ]]; then
                  read -rp "Link to external repo: " REPO_export 
                  export REPO=$REPO_export
                fi
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_miscellaneous"
        fi
      elif [[ "$CONFIRM" != "n" ]]; then
        echo "WRONG CHOICE!"
      fi
    done
    CONFIRM=""
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions that installs the system

  SCRIPT_01_REQUIRED_PACKAGES() {
    if [[ -z "$(pacman -Qs lolcat)" ]]; then
      printf "%s" "Installing dependencies "
      local command="pacman -S --noconfirm --needed lolcat figlet parted"
      $command > /dev/null 2>&1 &
      while [[ ! $(pacman -Qs lolcat) ]]; do
        PRINT_PROGRESS_BAR 
        sleep 1
      done
      printf " [%s]\n" "Success!"
    fi
}

  SCRIPT_02_CHOICES() {
    eval "${messages[0]}"
    MULTISELECT_MENU "${intro[@]}"
    for ((i=1, j=1, option=1; i < "$COUNT_intro"; i++, j++, option++)); do 
      VALUE=$(eval echo \$CHOICE_$j)
      CHOICE=${options[i]}
      SORTED=${CHOICE%%:*}
      export $SORTED=$VALUE	
    done
    if [[ "$INIT_choice_runit" == "true" ]]; then
      export INIT_choice="runit"
    elif [[ "$INIT_choice_openrc" == "true" ]]; then
      export INIT_choice="openrc"
    elif [[ "$INIT_choice_dinit" == "true" ]]; then
      export INIT_choice="dinit"
    fi
    if [[ "$BOOTLOADER_choice_grub" == "true" ]]; then
      export BOOTLOADER_choice="grub"
      export BOOTLOADER_packages="grub grub-btrfs"
    elif [[ "$BOOTLOADER_choice_refind" == "true" ]]; then
      export BOOTLOADER_choice="refind"
      export BOOTLOADER_packages="refind"
    fi
}

  SCRIPT_03_CUSTOMIZING() {
    UPDATE_CHOICES
    PRINT_TABLE '@' "$OUTPUT_drives"
    CUSTOMIZING_INSTALL DRIVES
    if [[ "$ENCRYPTION_partitions" == "false" ]]; then
      export ENCRYPTION_passwd="IGNORED"
    fi
    if [[ "$ADDITIONAL_packages" == "false" ]]; then
      export PACKAGES_additional="IGNORED"
    fi
    if [[ "$CUSTOM_script" == "false" ]]; then
      export REPO="IGNORED"
    fi
    UPDATE_CHOICES
    if [[ "$SWAP_partition" == "true" ]]; then
      PRINT_TABLE ',' "$OUTPUT_partitions_full"
      CUSTOMIZING_INSTALL PARTITIONS_full
    else
      PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
      CUSTOMIZING_INSTALL PARTITIONS_without_swap
    fi
    PRINT_TABLE ',' "$OUTPUT_locals"
    CUSTOMIZING_INSTALL LOCALS
    PRINT_TABLE ',' "$OUTPUT_users"
    CUSTOMIZING_INSTALL USERS
    PRINT_TABLE ',' "$OUTPUT_miscellaneous"
    CUSTOMIZING_INSTALL MISCELLANEOUS
}

  SCRIPT_04_UMOUNT_MNT() {
    if [[ "$(mountpoint /mnt)" ]]; then
      swapoff -a
      umount -A --recursive /mnt
    fi
}

  SCRIPT_05_PACMAN_REPOSITORIES() {
    if [[ -z "$(pacman -Qs artix-archlinux-support)" ]]; then
      pacman -S --noconfirm --needed artix-archlinux-support
      pacman-key --init
      pacman-key --populate archlinux artix
      if [[ "$(find /install_script -name pacman.conf)" ]]; then
        cp /install_script/pacman.conf /etc/pacman.conf
      else
        cp pacman.conf /etc/pacman.conf
      fi
      pacman -Syy 
    fi
}

  SCRIPT_06_CREATE_PARTITIONS() {
    if [[ "$SWAP_partition" == "true" ]]; then
      parted --script -a optimal "$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart SWAP linux-swap "$BOOT_size"MiB "$SWAP_size_allocated"MiB  \
        mkpart PRIMARY "$FILESYSTEM_primary" "$SWAP_size_allocated"MiB 100% 
    else
      parted --script -a optimal "$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart PRIMARY "$FILESYSTEM_primary" "$BOOT_size"MiB 100% 
    fi
}

  SCRIPT_07_FORMAT_AND_ENCRYPT_PARTITIONS() {
    mkfs.vfat -F32 -n "$BOOT_label" "$DRIVE_path_boot" 
    if [[ "$SWAP_partition" == "true" ]]; then
      mkswap -L "$SWAP_label" "$DRIVE_path_swap"
      swapon "$DRIVE_path_swap"
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      if [[ "$BOOTLOADER_choice" == "grub" ]]; then
        echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf=pbkdf2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
        echo "$ENCRYPTION_passwd" | cryptsetup open "$DRIVE_path_primary" cryptroot
      elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
        echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
        echo "$ENCRYPTION_passwd" | cryptsetup open "$DRIVE_path_primary" cryptroot
      fi
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

  SCRIPT_08_CREATE_SUBVOLUMES_AND_MOUNT_PARTITIONS() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      export UUID_1=$(blkid -s UUID -o value "$DRIVE_path_primary")
      export UUID_2=$(lsblk -no TYPE,UUID "$DRIVE_path_primary" | awk '$1=="part"{print $2}' | tr -d -)
    fi
    mount -o noatime,compress=zstd "$MOUNTPOINT" /mnt
    cd /mnt || exit
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        btrfs subvolume create "${subvolumes[subvolume]}"
      elif [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        bcachefs subvolume create "${subvolumes[subvolume]}"
      fi
    done
    cd / || exit
    umount /mnt
    mount -o noatime,compress=zstd,subvol=@ "$MOUNTPOINT" /mnt
    mkdir -p /mnt/{boot/EFI,home,srv,var,opt,tmp,.snapshots,.secret}
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      subvolume_path=$(string="${subvolumes[subvolume]}"; echo "${string//@/}")
      if [[ "${subvolumes[subvolume]}" != "@" ]]; then
        mount -o noatime,compress=zstd,subvol="${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
      fi
    done
    sync
    cd "$BEGINNER_DIR" || exit
    mount "$DRIVE_path_boot" /mnt/boot/EFI
}
 
  SCRIPT_09_BASESTRAP_PACKAGES() {
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
    PACKAGES_install="$PACKAGES_separated $BOOTLOADER_packages $MICROCODE_package"
    if [[ "$SUPERUSER_replace" == "true" ]]; then
      basestrap /mnt --needed opendoas $PACKAGES_install
    else
      basestrap /mnt --needed sudo $PACKAGES_install
    fi
}

  SCRIPT_10_FSTAB_GENERATION() {
    fstabgen -U /mnt >> /mnt/etc/fstab
    if [[ "$SWAP_partition" == "true" ]]; then
      UUID_swap=$(lsblk -no TYPE,UUID "$DRIVE_path_swap" | awk '$1=="part"{print $2}')
      cat << EOF | tee -a /mnt/etc/crypttab > /dev/null
swap     UUID=$UUID_swap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=512
EOF
      cat << EOF | tee -a /mnt/etc/fstab > /dev/null
# /dev/sda2 SWAP
/dev/mapper/swap	none	swap	defaults	0	0

# Temporary filesystem
tmpfs	/tmp	tmpfs	rw,size=$RAM_size,nr_inodes=5k,noexec,nodev,nosuid,mode=1700	0	0  

EOF
  else
      cat << EOF | tee -a /mnt/etc/fstab > /dev/null
# Temporary filesystem
tmpfs	/tmp	tmpfs	rw,size=$RAM_size,nr_inodes=5k,noexec,nodev,nosuid,mode=1700	0	0  

EOF
  fi
}

  SCRIPT_11_FSTAB_CHECK() {
    if [[ "$FSTAB_check" == "true" ]]; then
      cat /mnt/etc/fstab
    fi
}

  SCRIPT_12_CHROOT() {
    mkdir /mnt/install_script
    cp -- * /mnt/install_script
    for ((function=0; function < "${#functions[@]}"; function++)); do
      if [[ "${functions[function]}" == "SCRIPT_05_PACMAN_REPOSITORIES" ]]; then
        export -f "SCRIPT_05_PACMAN_REPOSITORIES"
        artix-chroot /mnt /bin/bash -c "SCRIPT_05_PACMAN_REPOSITORIES"
      elif [[ "${functions[function]}" == *"SYSTEM"* ]]; then      
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
    echo "$ROOT_username:$ROOT_passwd" | chpasswd
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
      cp /install_script/paru.conf /etc/paru.conf # Links sudo to doas + more
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
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      dd bs=512 count=6 if=/dev/random of=/.secret/crypto_keyfile.bin iflag=fullblock
      chmod 600 /.secret/crypto_keyfile.bin
      chmod 600 /boot/initramfs-linux*
      echo "$ENCRYPTION_passwd" | cryptsetup luksAddKey "$DRIVE_path_primary" /.secret/crypto_keyfile.bin
      sed -i 's/FILES=()/FILES=(\/.secret\/crypto_keyfile.bin)/' /etc/mkinitcpio.conf
    elif [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /etc/mkinitcpio.conf
    fi
    if [[ "$BOOTLOADER_choice" == "grub" ]]; then
      sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ keymap\ keyboard\ autodetect\ modconf\ block\ encrypt\ filesystems\ fsck\ grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
    elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
      sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ keymap\ keyboard\ autodetect\ modconf\ block\ encrypt\ filesystems\ fsck)/' /etc/mkinitcpio.conf
    fi
    mkinitcpio -P
}

  SYSTEM_08_BOOTLOADER() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]] && [[ "$BOOTLOADER_choice" == "grub" ]]; then
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="lsm=landlock,lockdown,apparmor,yama,bpf\ loglevel=3\ quiet\ cryptdevice=UUID='"$UUID_1"':cryptroot:allow-discards\ root=\/dev\/mapper\/cryptroot\ cryptkey=rootfs:\/.secret\/crypto_keyfile.bin"/' /etc/default/grub
      sed -i 's/GRUB_PRELOAD_MODULES="part_gpt part_msdos"/GRUB_PRELOAD_MODULES="part_gpt\ part_msdos\ luks2\ fat\ part_gpt\ cryptodisk\ pbkdf2\ gcry_rijndael\ gcry_sha256\ gcry_sha512\ btrfs"/' /etc/default/grub
      sed -i -e "/GRUB_ENABLE_CRYPTODISK/s/^#//" /etc/default/grub
      touch /etc/grub.d/01_header
      cat << EOF | tee -a /etc/grub.d/01_header > /dev/null
#! /bin/sh

crypto_uuid=$UUID_2
echo "cryptomount -u $UUID_2"

EOF
   elif [[ "$BOOTLOADER_choice" == "grub" ]]; then
     grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id="$BOOTLOADER_label"
     grub-mkconfig -o /boot/grub/grub.cfg
   elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
     refind-install
   fi
}

  SYSTEM_09_MISCELLANEOUS() {
    cd /install_script || exit
    cat << EOF | tee -a /etc/pam.d/system-login > /dev/null # 3 seconds delay, when system login failes
auth optional pam_faildelay.so delay="$LOGIN_delay"
EOF
    cp btrfs_snapshot.sh /.snapshots # Maximum 3 snapshots stored
    chmod u+x /.snapshots/*
    sed -i -e "/GRUB_BTRFS_OVERRIDE_BOOT_PARTITION_DETECTION/s/^#//" /etc/default/grub-btrfs/config
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
      REPO_folder=$(basename "$REPO")
      git clone "$REPO"
      cd "$REPO_folder" || exit
      chmod u+x -- *.sh
      ./.sh
    fi
}

  SYSTEM_11_CLEANUP() {
    rm -rf /install_script
}

  SCRIPT_13_FAREWELL() {
    if [[ "$ENCRYPTION_partitions" == "true" ]] && [[ "$FILESYSTEM_primary" == "btrfs" ]] && [[ "$BOOTLOADER_choice" == "grub" ]]; then
      PRINT_WITH_COLOR yellow "Due to GRUB having limited support for LUKS2, which your partition has been encrypted with, you will enter grub-shell during boot."
      PRINT_WITH_COLOR yellow "Though since a keyfile has been added to the partition, you only have to unlock the partition once with the following commands: "
      echo
      PRINT_WITH_COLOR white "\"cryptomount -a\" # Unlocks the encrypted partition; the reason is that /boot is encrypted too"
      PRINT_WITH_COLOR white "\"normal\" # Your normal boot"
      echo
    fi
    exit
}

  # Must be the last command in this section to export all defined functions
  mapfile -t functions < <( compgen -A function ) 

#----------------------------------------------------------------------------------------------------------------------------------

# Actual execution of commands

  for ((function=0; function < "${#functions[@]}"; function++)); do
    if [[ "${functions[function]}" == "SCRIPT"* ]]; then
      "${functions[function]}"
    fi
  done
