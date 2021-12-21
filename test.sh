#!/bin/bash

# Static variables / configurable during install

  # Static
  COLUMNS=$(tput cols) 
  BEGINNER_DIR=$(pwd)
  RAM_size="$(($(free -g | grep Mem: | awk '{print $2}') + 1))"
  WRONG=""
  PROCEED=""
  CONFIRM=""
  
  # Choices during install; either true or nothing (interpreted as false)
  FILESYSTEM_primary="" # Future support for bcachefs once mainlined
  ENCRYPTION_partitions=""
  SWAP_partition=""
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
  export BOOT_label="BOOT"
  export SWAP_size="$(($RAM_size * 1000))"
  export SWAP_size_allocated=$(("$SWAP_size"+"$BOOT_size"))
  export SWAP_label="RAM_co"
  export PRIMARY_size="∞"
  export PRIMARY_label="PRIMARY"
  export ENCRYPTION_passwd="insecure"
  MOUNTPOINT=""

  # Locals
  export TIMEZONE="Europe/Copenhagen"
  export LANGUAGES_generate="da_DK.UTF-8 en_GB.UTF-8"
  export LANGUAGE_system="en_GB.UTF-8"
  export KEYMAP_system="dk-latin1"
  export HOSTNAME_system="artix"

  # Users
  export ROOT_username="root"
  export ROOT_passwd="not chosen"
  export USERNAME="not chosen"
  export USER_passwd="not chosen"

  # Miscellaneous
  export BOOTLOADER_label="ARTIX_BOOT"
  export PACKAGES_additional="empty"
  export REPO="not chosen"
  export SCRIPT="not chosen"

#----------------------------------------------------------------------------------------------------------------------------------

# Parameters that customizes the system-install

  # BCACHEFS-support
  BCACHEFS_implemented="false"
  BCACHEFS_notice="(BCACHEFS as filesystem) # Currently not implemented"

  # Subvolumes to be created 
  subvolumes=(
    \@
    "home"
    "var/cache"
    "var/log"
    "var/spool"
    "var/tmp"
    "opt"
    "tmp"
    "srv"
    ".snapshots"
    "root"
    "grub"
    "snapshot"
  )

  # Size of tmpfs (/tmp) 
  RAM_size_G_half="$(($RAM_size / 2))G" # tmpfs will fill half the RAM-size

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
    printf "%*s\n" $((("${#OUTPUT}"+"$COLUMNS")/2)) "$OUTPUT" | lolcat
    printf '%0.s-' $(seq 1 "$COLUMNS")
    echo
}

  PRINT_PROGRESS_BAR() {
    local progress_bar="."
    printf "%s" "${progress_bar}"
}

#----------------------------------------------------------------------------------------------------------------------------------

# Choices to present in text-menu

  intro=(
    "INTRO"
    "FILESYSTEM_primary_btrfs:BTRFS as filesystem"
    "FILESYSTEM_primary_bcachefs:$BCACHEFS_notice"
    "ENCRYPTION_partitions:Encryption" 
    "SWAP_partition:Swap-partition" 
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
  MISCELLANEOUS=",BOOTLOADER-ID (1),ADDITIONAL PACKAGES (2),EXTERNAL SCRIPT (3)"

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
SYSTEMWIDE:,$TIMEZONE,$LANGUAGE_system,$KEYMAP_system,$HOSTNAME_system
EOM

    read -r -d '' OUTPUT_users << EOM
$USERS
USERNAME:,$ROOT_username,$USERNAME
PASSWORD:,$ROOT_passwd,$USER_passwd
EOM

    read -r -d '' OUTPUT_miscellaneous << EOM
$MISCELLANEOUS
VALUE:,$BOOTLOADER_label,$PACKAGES_additional,Link: $REPO 
,,,Executable: $SCRIPT	
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
    "TIME TO LOCALIZE YOUR SYSTEM!" # While configuring locals
    "WE CAN ALL BENEFIT FROM MORE USERS!" # While configuring the users
    "TIME TO PACK UP!" # When configuring miscellaneous options
    "AND VOILA - YOU NOW HAVE A FULLY FUNCTIONAL ARTIX INSTALL!" # When... done
    "THIS SCRIPT MUST BE RUN AS ROOT!" # When user is not root and an argument isn't passed
)

#----------------------------------------------------------------------------------------------------------------------------------

# Insure that the script is run as root-user

  if [[ -z "$1" ]] && ! [[ "$USER" == 'root' ]]; then
    echo
    PRINT_LINES
    printf "%*s\n" $((("${#messages[13]}"+"$COLUMNS")/2)) "${messages[13]}"
    PRINT_LINES
    exit 1
  fi

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for printing tables

  PRINT_TABLE() {
    local -r delimiter="${1}"
    local -r data="$(REMOVE_EMPTY_LINES "${2}")"
    if ! [[ "${delimiter}" == "" ]] && [[ "$(EMPTY_STRING "${data}")" = "false" ]]; then
      local -r numberOfLines="$(wc -l <<< "${data}")"
      if [[ "${numberOfLines}" -gt "0" ]]; then
        local table=""
        local i=1
        for ((i=1; i<="${numberOfLines}"; i++)); do
          local line=""
          line="$(sed "${i}q;d" <<< "${data}")"
          local numberOfColumns="0"
          numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"
          if [[ "${i}" -eq "1" ]]; then
            table="${table}$(printf '%s#+' "$(REPEAT_STRING '#+' "${numberOfColumns}")")"
          fi
          table="${table}\n"
          local j=1
          for ((j=1; j<="${numberOfColumns}"; j++)); do
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
    if ! [[ "${string}" == "" ]] && [[ "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
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
        if [[ "${options[0]}" == "INTRO" ]]; then
          PRINT_MESSAGE "${messages[2]}" 
        fi
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
        IFS=""
        read -rsn1 key 2> /dev/null >&2
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
          selected[option]="false"
        else
          selected[option]="true"
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
              COUNT_init=$(grep -o true <<< "${selected[@]:4:3}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              COUNT_bootloader=$(grep -o true <<< "${selected[@]:7:2}" | wc -l)
              if [[ "$COUNT_init" -eq "1" ]] && [[ "$active" == @(4|5|6) ]]; then
                eval selected[{4..6}]=false
                toggle_option $active
              elif [[ "$COUNT_bootloader" -eq "1" ]] && [[ "$active" == @(7|8) ]]; then
                eval selected[{7..8}]=false
                toggle_option $active
              elif [[ "$BCACHEFS_implemented" == "true" ]] && [[ "$COUNT_filesystem" -eq 1 ]] && [[ "$active" == @(0|1) ]]; then
                eval selected[{0..1}]=false
                toggle_option $active
              elif [[ "$BCACHEFS_implemented" == "false" ]] && [[ "$active" == @(0|1)	 ]]; then
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
              COUNT_init=$(grep -o true <<< "${selected[@]:4:3}" | wc -l)
              COUNT_filesystem=$(grep -o true <<< "${selected[@]:0:2}" | wc -l)
              COUNT_bootloader=$(grep -o true <<< "${selected[@]:7:2}" | wc -l)
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
                for ((i=0, j=1; i<${#selected[@]}; i++, j++)); do
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
              active=$((${#options[@]}-1)) 
            fi
            ;;
          down)   
            ((active++)); 
            if [[ "$active" -ge "$((${#options[@]}-1))" ]]; then 
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

# Functions for checking user-input

  SIZE_check() {
    if ! [[ "$DRIVE_size" == "" ]]; then
      if ! [[ "$DRIVE_size" =~ ^[0-9]+$ ]]; then
        echo
        PRINT_MESSAGE "Only numbers please!"
        PROCEED="false"
      elif [[ "${user_choices[$val]}" == "1" ]]; then
        if [[ "$DRIVE_size" -le "300" ]]; then
          echo
          PRINT_MESSAGE "Minimum 300 MB is required for the boot-partition!"
          echo
          PROCEED="false"
        else
          export BOOT_size=$DRIVE_size
          PROCEED="true"
        fi
      else
        export SWAP_size=$DRIVE_size
        export SWAP_size_allocated=$(("$SWAP_size"+"$BOOT_size"))
        PROCEED="true"
      fi
    else
      PROCEED="true"
    fi
}

  LABEL_check() {
    if ! [[ "$DRIVE_label" == "" ]]; then
      if [[ "${user_choices[$val]}" == "1" ]] && [[ "${#DRIVE_label}" -ge "11" ]]; then
        echo
        PRINT_MESSAGE "Maximum 11 characters is allowed for FAT32!"
        PROCEED="false"
      else
        if [[ "${user_choices[$val]}" == "1" ]]; then
          export BOOT_label=$DRIVE_label
        elif [[ "${user_choices[$val]}" == "2" ]]; then
          if [[ "$SWAP_partition" == "true" ]]; then
            export SWAP_label=$DRIVE_label
          else
            export PRIMARY_label=$DRIVE_label
          fi
        elif [[ "${user_choices[$val]}" == "3" ]]; then
          export PRIMARY_label=$DRIVE_label
        fi
        PROCEED="true"
      fi
    else
      PROCEED="true"
    fi
}

  ENCRYPTION_check() {
    if [[ "$ENCRYPTION_passwd_export" == "" ]]; then
      echo
      PRINT_MESSAGE "An empty encryption-password is... not so strong!"
      PROCEED="false"
    else
      export ENCRYPTION_passwd=$ENCRYPTION_passwd_export
      PROCEED="true"
    fi
}

  TIMEZONE_check() {
   if ! [[ -f "/usr/share/zoneinfo/"$TIMEZONE_export"" ]] && ! [[ "$TIMEZONE_export" == "" ]]; then
     PRINT_MESSAGE "Illegal timezone!"  
     PROCEED="false"   
   elif [[ "$TIMEZONE_export" == "" ]]; then
     PROCEED="true"
   else
     export TIMEZONE=$TIMEZONE_export
     PROCEED="true"
   fi
}

  LANGUAGE_check() {
    if [[ "$1" == "generate" ]]; then
      IFS=','
      read -ra languages <<< "$LANGUAGES_generate_export"
      if ! [[ "$LANGUAGES_generate_export" == "" ]]; then
        for ((val=0; val < "${#languages[@]}"; val++)); do 
          if grep -Eq "#${languages[$val]} UTF-8" /etc/locale.gen; then
            correct="true"
          else
            PRINT_MESSAGE "Illegal language: \""${languages[$val]}\"""   
            correct="false"  
          fi
        done
        if [[ "$correct" == "true" ]]; then
          export LANGUAGES_generate=$LANGUAGES_generate_export
          PROCEED="true"
        else 
          PRINT_MESSAGE "Illegal language: \""${languages[$val]}\"""   
          PROCEED="false"
        fi
      else
        PROCEED="true"
      fi
    elif [[ "$1" == "system" ]]; then
      if [[ $(grep -Eq "#$LANGUAGE_system_export UTF-8" /etc/locale.gen) ]] && ! [[ "$LANGUAGES_generate_export" == "" ]]; then 
        PROCEED="true"
        export LANGUAGE_system=$LANGUAGE_system_export
      elif [[ "$LANGUAGE_system_export" == "" ]]; then
        PROCEED="true"
      else
        PRINT_MESSAGE "Illegal language!"     
      fi
    fi
}

  KEYMAP_check() {
    if ! [[ $(loadkeys "$KEYMAP_system_export") ]] && ! [[ "$KEYMAP_system_export" == "" ]]; then
      PRINT_MESSAGE "Illegal keymap!" 
    elif [[ "$KEYMAP_system_export" == "" ]]; then
      PROCEED="true"
    else
      export KEYMAP_system=$KEYMAP_system_export 
      PROCEED="true"
    fi
}

  USER_check() {
    if [[ "$1" == "password" ]]; then
      if [[ "$ROOT_passwd_export" == "" ]]; then
        PRINT_MESSAGE "Empty password!"   
      elif [[ "$USER_passwd_export" == "" ]] && ! [[ "$USERNAME_export" == "" ]]; then
        PRINT_MESSAGE "Empty password!"  
      else 
        PROCEED="true"
      fi
    elif [[ "$1" == "username" ]]; then
      if [[ "$USERNAME_export" == "" ]]; then
        PRINT_MESSAGE "Empty username!"  
      else  
        export USERNAME=$USERNAME_export
        PROCEED="true"
      fi    
    fi   
}

  PACKAGES_check() {
    unavailable_packages="0"
    IFS=','
    read -ra packages_to_install <<< "$PACKAGES_additional_export"
    for ((val=0; val<"${#packages_to_install[@]}"; val++)); do 
      if ! [[ $(pacman -Si "${packages_to_install[$val]}") ]] ; then
        echo "${packages_to_install[$val]} is not found in repos!"
        unavailable_packages+=1
      fi
    done
    if ! [[ "$unavailable_packages" == "0" ]]; then
      PRINT_MESSAGE "Illegal packages!"
    elif [[ "$PACKAGES_additional_export" == "" ]]; then
      PRINT_MESSAGE "No packages was entered!"
    else
      export PACKAGES_additional=$PACKAGES_additional_export
      PROCEED="true"
    fi
}

  REPO_check() {
    VALID_url=$(curl --head --silent "$REPO_export" | head -n 1)
    if echo "$VALID_url" | grep -q 404; then
      PRINT_MESSAGE "Illegal repo!"
    else
      REPO_folder=$(basename "$REPO_export")
      git clone --quiet "$REPO_export"
      cd "$REPO_folder" || exit
      contents=( * )
      echo
      echo "Which file is to be executed?"
      echo 
      select opt in "${contents[@]}"; do 
        export SCRIPT="$opt"
        chmod u+x "$opt"
        cd "$BEGINNER_DIR" || exit
        rm -rf "$REPO_folder"      
        break 
      done
      export REPO=$REPO_export
      PROCEED="true"
    fi
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions for customizing install

  CUSTOMIZING_INSTALL() {
    while ! [[ "$CONFIRM_proceed" == "true" ]]; do
      PROCEED="false"
      echo
      IFS=
      if [[ "$1" == "DRIVES" ]]; then
        CONFIRM="false"
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
      if [[ "$CONFIRM" == "Y" ]] || [[ "$CONFIRM" == "y" ]] || [[ "$CONFIRM" == "" ]]; then	
        if [[ "$1" == "DRIVES" ]]; then
          DRIVE=""
          CONFIRM="n"
        elif [[ "$1" == "PARTITIONS_full" ]] || [[ "$1" == "PARTITIONS_without_swap" ]]; then
          read -rp "Partition(s) to modify (e.g. \"1,2\"): " partition
          echo
          IFS=','
          read -ra user_choices <<< "$partition"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "BOOT-partition size (leave empty for default): " DRIVE_size
                  SIZE_check
                done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "BOOT-partition label (leave empty for default): " DRIVE_label
                  LABEL_check
                done
                PROCEED="false"
                echo
                ;;
              2)
                if [[ "$SWAP_partition" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "SWAP-partition size (leave empty for default): " DRIVE_size
                    SIZE_check
                  done
                  PROCEED="false"
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "SWAP-partition label (leave empty for default): " DRIVE_label
                    LABEL_check
                  done
                  PROCEED="false"
                  echo
                else
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "PRIMARY-label (leave empty for default): " DRIVE_label
                    LABEL_check
                  done
                  PROCEED="false"
                  if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                    until [[ "$PROCEED" == "true" ]]; do
                      read -rp "Encryption-passwd: " ENCRYPTION_passwd_export
                      ENCRYPTION_check
                    done
                    PROCEED="false"
                  fi
                fi
                ;;
              3)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "PRIMARY-label (leave empty for default): " DRIVE_label
                  LABEL_check
                done
                PROCEED="false"
                if [[ "$ENCRYPTION_partitions" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "Encryption-passwd: " ENCRYPTION_passwd_export
                    ENCRYPTION_check
                  done
                  PROCEED="false"
                fi
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
          read -rp "Locals to modify (e.g. \"1,2\"): " local
          echo
          IFS=','
          read -ra user_choices <<< "$local"
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "TIMEZONE (leave empty for default): " TIMEZONE_export
                  TIMEZONE_check
                done          
                PROCEED="false"
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Comma-separated languages to generate (leave empty for default): " LANGUAGES_generate_export
                  LANGUAGE_check generate
                done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Systemwide language (leave empty for default): " LANGUAGE_system_export
                  LANGUAGE_check system
                done
                PROCEED="false"
                echo
                ;;
              3)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Systemwide keymap (leave empty for default): " KEYMAP_system_export
                  KEYMAP_check
                done   
                PROCEED="false"
                echo
                ;;
              4)
                read -rp "Name to host (leave empty for default): " HOSTNAME_system_export
                PROCEED="false"
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
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)       
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Password for root: " ROOT_passwd_export
                  USER_check password
                done     
                PROCEED="false"
                export ROOT_passwd=$ROOT_passwd_export
                echo
                ;;
              2)
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Username for personal user: " USERNAME_export
                  USER_check username
                done
                PROCEED="false"
                until [[ "$PROCEED" == "true" ]]; do
                  read -rp "Password for personal user: " USER_passwd_export
                  USER_check password
                done     
                PROCEED="false"
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
          for ((val=0; val<"${#user_choices[@]}"; val++)); do 
            case ${user_choices[$val]} in
              1)           
                read -rp "BOOTLOADER-ID (leave empty for default): " BOOTLOADER_label_export 
                if ! [[ "$BOOTLOADER_label_export" == "" ]]; then
                  export BOOTLOADER_label=$BOOTLOADER_label_export
                fi
                echo
                ;;
              2)
                if [[ "$ADDITIONAL_packages" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "Additional packages to install (separated by comma): " PACKAGES_additional_export 
                    PACKAGES_check
                  done   
                  PROCEED="false"
                  echo
                fi
                ;;
              3)
                if [[ "$CUSTOM_script" == "true" ]]; then
                  until [[ "$PROCEED" == "true" ]]; do
                    read -rp "Link to external repo: " REPO_export 
                    REPO_check
                  done   
                  PROCEED="false"
                fi
                ;;
            esac
          done
          echo
          UPDATE_CHOICES
          PRINT_TABLE ',' "$OUTPUT_miscellaneous"
        fi
      elif [[ "$CONFIRM" == "n" ]]; then
        if [[ "$1" =~ ^(PARTITIONS_full|PARTITIONS_without_swap)$ ]] && [[ "$ENCRYPTION_partitions" == "true" ]] && [[ "$ENCRYPTION_passwd_export" == "" ]]; then
          PRINT_MESSAGE "YOU HAVEN'T SET AN ENCRYPTION-PASSWORD!"
          if [[ "$SWAP_partition" == "true" ]]; then
            PRINT_TABLE ',' "$OUTPUT_partitions_full"
          else
            PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
          fi
        elif [[ "$1" == "USERS" ]] && [[ "$ROOT_passwd_export" == "" || "$USERNAME_export" == "" ]]; then
          PRINT_MESSAGE "YOU HAVEN'T CONFIGURED YOUR USERS!"
          PRINT_TABLE ',' "$OUTPUT_users"
        elif [[ "$1" == "MISCELLANEOUS" ]] && [[ "$ADDITIONAL_packages" == "true" || "$CUSTOM_script" == "true" ]] && [[ "$PACKAGES_additional_export" == "" || "$REPO_export" == "" ]]; then
          PRINT_MESSAGE "YOU HAVEN'T SET EITHER ADDITIONAL PACKAGES OR AN REPO!"
          PRINT_TABLE ',' "$OUTPUT_miscellaneous"
        else
          CONFIRM_proceed="true"
        fi
      elif ! [[ "$CONFIRM" == "n" ]]; then
        echo "WRONG CHOICE!"
      fi
    done
    CONFIRM_proceed="false"
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions that installs the system

  SCRIPT_01_REQUIRED_PACKAGES() {
    if [[ -z "$(pacman -Qs lolcat)" ]]; then
      printf "%s" "Installing dependencies "
      local command="pacman -S --noconfirm --needed lolcat figlet parted"
      $command > /dev/null 2>&1 &
      while ! [[ $(pacman -Qs lolcat) ]]; do
        PRINT_PROGRESS_BAR 
        sleep 1
      done
      printf " [%s]\n" "Success!"
    fi
}

  SCRIPT_02_CHOICES() {
    eval "${messages[0]}"
    MULTISELECT_MENU "${intro[@]}"
    for ((i=1, j=1, option=1; i<"$COUNT_intro"; i++, j++, option++)); do 
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
    elif [[ "$BOOTLOADER_choice_refind" == "true" ]]; then
      export BOOTLOADER_choice="refind"
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
      export SCRIPT="IGNORED"
    fi
    UPDATE_CHOICES
    PRINT_MESSAGE "${messages[8]}" 
    echo
    if [[ "$SWAP_partition" == "true" ]]; then
      PRINT_TABLE ',' "$OUTPUT_partitions_full"
      CUSTOMIZING_INSTALL PARTITIONS_full
    else
      PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
      CUSTOMIZING_INSTALL PARTITIONS_without_swap
    fi
    PRINT_MESSAGE "${messages[9]}" 
    PRINT_TABLE ',' "$OUTPUT_locals"
    CUSTOMIZING_INSTALL LOCALS
    PRINT_MESSAGE "${messages[10]}" 
    PRINT_TABLE ',' "$OUTPUT_users"
    CUSTOMIZING_INSTALL USERS
    PRINT_MESSAGE "${messages[11]}" 
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
        echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf pbkdf2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
        echo "$ENCRYPTION_passwd" | cryptsetup open "$DRIVE_path_primary" cryptroot
      elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
        echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
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
    export UUID_1=$(blkid -s UUID -o value "$DRIVE_path_primary")
    export UUID_2=$(lsblk -no TYPE,UUID "$DRIVE_path_primary" | awk '$1=="part"{print $2}' | tr -d -)
    mount -o noatime,compress=zstd "$MOUNTPOINT" /mnt
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        if ! [[ "${subvolumes[subvolume]}" == "@" ]]; then
          if [[ "${subvolumes[subvolume]}" == "var/*" ]]; then
            btrfs subvolume create "/mnt/@/${subvolumes[subvolume]}"
            chattr +C "${subvolumes[subvolume]}"
          elif [[ "${subvolumes[subvolume]}" == ".snapshots" ]]; then
            btrfs subvolume create "/mnt/@/.snapshots"
            mkdir -p /mnt/@/.snapshots/1
          elif [[ "${subvolumes[subvolume]}" == "snapshot" ]]; then
            btrfs subvolume create "/mnt/@/.snapshots/1/snapshot"
          elif [[ "${subvolumes[subvolume]}" == "grub" ]]; then
            if [[ "$BOOTLOADER_choice" == "grub" ]]; then
              btrfs subvolume create "/mnt/@/boot/grub"
            fi
          else
            btrfs subvolume create "/mnt/@/${subvolumes[subvolume]}"
          fi
        else
          btrfs subvolume create "/mnt/${subvolumes[subvolume]}"
          mkdir -p /mnt/@/{var,boot}
        fi
      elif [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        bcachefs subvolume create "${subvolumes[subvolume]}"
      fi
    done
    touch /mnt/@/.snapshots/1/info.xml
    date=$(date +"%Y-%m-%d %H:%M:%S")
    cat << EOF | tee -a /mnt/@/.snapshots/1/info.xml > /dev/null
<?xml version="1.0"?>
<snapshot>
<type>single</type>
	<num>1</num>
	<date>$date</date>
	<description>First snapshot created at installation</description>
</snapshot>
EOF
    btrfs subvolume set-default $(btrfs subvolume list /mnt | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+') /mnt
    btrfs quota enable /mnt
    umount /mnt
    mount "$MOUNTPOINT" -o noatime,compress=zstd /mnt
    if [[ "$ENCRYPTION_partitions" == "true" ]]; then
      mkdir -p /mnt/.secret 
    fi
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      subvolume_path=$(string="${subvolumes[subvolume]}"; echo "${string//@/}")
      if ! [[ "${subvolumes[subvolume]}" == "@" || "${subvolumes[subvolume]}" == "snapshot" ]]; then
        if ! [[ "${subvolumes[subvolume]}" == "grub" ]]; then
          mkdir -p /mnt/"${subvolumes[subvolume]}"
          if [[ "${subvolumes[subvolume]}" == "var/*" ]]; then
            mount -o noatime,compress=zstd,subvol="@/${subvolumes[subvolume]}",nodatacow "$MOUNTPOINT" /mnt/"$subvolume_path"
          else
            mount -o noatime,compress=zstd,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
          fi  
        elif [[ "${subvolumes[subvolume]}" == "grub" ]]; then
          if [[ "$BOOTLOADER_choice" == "grub" ]]; then
            mkdir -p /mnt/boot/{efi,grub}
            mount -o noatime,compress=zstd,subvol="@/boot/grub" "$MOUNTPOINT" /mnt/boot/grub
          else
            mkdir -p /mnt/boot/efi
          fi
        fi
      fi
    done
    sync
    cd "$BEGINNER_DIR" || exit
    mount "$DRIVE_path_boot" /mnt/boot/efi
}
 
  SCRIPT_09_BASESTRAP_PACKAGES() {
    basestrap /mnt $INIT_choice fcron-$INIT_choice dhcpcd-$INIT_choice chrony-$INIT_choice \
                   networkmanager-$INIT_choice seatd-$INIT_choice cryptsetup-$INIT_choice \
		   pam_rundir lolcat figlet bat cryptsetup libressl vim neovim nano git \
                   realtime-privileges bc lz4 zstd mkinitcpio rsync efibootmgr base \
                   base-devel linux-zen linux-zen-headers snapper snap-pac
    if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
      basestrap /mnt intel-ucode
    elif grep -q AMD "/proc/cpuinfo"; then
      basestrap /mnt amd-ucode
    fi
    if [[ "$SUPERUSER_replace" == "true" ]]; then
      basestrap /mnt opendoas
    else
      basestrap /mnt sudo
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      if [[ "$BOOTLOADER_choice" == "grub" ]]; then
        basestrap /mnt grub grub-btrfs btrfs-progs os-prober
      elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
        basestrap /mnt refind btrfs-progs
        REFIND_btrfs="$(ls -- *refind-btrfs*)"
        basestrap -U /mnt $REFIND_btrfs
      fi
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      if [[ "$BOOTLOADER_choice" == "grub" ]]; then
        basestrap /mnt grub bcachefs-tools os-prober
      elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
        basestrap /mnt refind bcachefs-tools
      fi
    fi
}

  SCRIPT_10_FSTAB_GENERATION() {
    fstabgen -U /mnt >> /mnt/etc/fstab
    sed -i 's/,subvolid=.*,subvol=\/@\/.snapshots\/1\/snapshot//' /mnt/etc/fstab
    if [[ "$SWAP_partition" == "true" ]]; then
      UUID_swap=$(lsblk -no TYPE,UUID "$DRIVE_path_swap" | awk '$1=="part"{print $2}')
      cat << EOF | tee -a /mnt/etc/crypttab > /dev/null
swap     UUID=$UUID_swap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=512
EOF
      cat << EOF | tee -a /mnt/etc/fstab > /dev/null
# /dev/sda2 SWAP
/dev/mapper/swap	none	swap	defaults	0	0

# Temporary filesystem
tmpfs	/tmp	tmpfs	rw,size=$RAM_size_G_half,nr_inodes=5k,noexec,nodev,nosuid,mode=1700	0	0  

EOF
  else
      cat << EOF | tee -a /mnt/etc/fstab > /dev/null
# Temporary filesystem
tmpfs	/tmp	tmpfs	rw,size=$RAM_size_G_half,nr_inodes=5k,noexec,nodev,nosuid,mode=1700	0	0  

EOF
  fi
}

  SCRIPT_11_CHROOT() {
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
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
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
      dinitctl enable NetworkManager
      dinitctl enable fcron
      dinitctl enable chrony
      dinitctl enable dhcpcd
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
      sed -i 's/BINARIES=()/BINARIES=(btrfs)/' /etc/mkinitcpio.conf
    fi
    if [[ "$BOOTLOADER_choice" == "grub" ]]; then
      sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ keymap\ keyboard\ autodetect\ modconf\ block\ encrypt\ filesystems\ fsck\ grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
    elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
      sed -i 's/HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ keymap\ keyboard\ autodetect\ modconf\ block\ encrypt\ filesystems\ fsck)/' /etc/mkinitcpio.conf
    fi
    mkinitcpio -P
}

  SYSTEM_08_SNAPPER() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      cd /install_script || exit
      umount /.snapshots
      rm -r /.snapshots
      snapper --no-dbus -c root create-config /
      mv snapper_root /etc/snapper/configs/root
      btrfs subvolume delete /.snapshots
      mkdir /.snapshots
      mount -a
      chmod 750 /.snapshots
    fi
}

  SYSTEM_09_BOOTLOADER() {
    if [[ "$BOOTLOADER_choice" == "grub" ]]; then
      sed -i 's/GRUB_GFXMODE="1024x768,800x600"/GRUB_GFXMODE="auto"/' /etc/default/grub
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        sed -i 's/rootflags=subvol=${rootsubvol}//' /etc/grub.d/10_linux 
        sed -i 's/rootflags=subvol=${rootsubvol}//' /etc/grub.d/20_linux_xen  
        if [[ "$ENCRYPTION_partitions" == "true" ]]; then
          sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3\ quiet\ cryptdevice=UUID='"$UUID_1"':cryptroot:allow-discards\ root=\/dev\/mapper\/cryptroot\ cryptkey=rootfs:\/.secret\/crypto_keyfile.bin"/' /etc/default/grub
          sed -i 's/GRUB_PRELOAD_MODULES="part_gpt part_msdos"/GRUB_PRELOAD_MODULES="part_gpt\ part_msdos\ luks2"/' /etc/default/grub
          sed -i -e "/GRUB_ENABLE_CRYPTODISK/s/^#//" /etc/default/grub
          grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
          touch grub-pre.cfg
          cat << EOF | tee -a grub-pre.cfg > /dev/null

cryptomount -u $UUID_2 
set root=crypto0
set prefix=(crypto0)/@/boot/grub
insmod normal
normal

EOF
          grub-mkimage -p '/boot/grub' -O x86_64-efi -c grub-pre.cfg -o /tmp/image luks2 btrfs part_gpt cryptodisk gcry_rijndael pbkdf2 gcry_sha512
          cp /tmp/image /boot/efi/EFI/"$BOOTLOADER_label"/grubx64.efi
          grub-mkconfig -o /boot/grub/grub.cfg
          rm -rf {/tmp/image,grub-pre.cfg}
        fi
      elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
        :
      fi
      if ! [[ "$ENCRYPTION_partitions" == "true" ]]; then
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
        grub-mkconfig -o /boot/grub/grub.cfg
      fi
    elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
      refind-install --usedefault "$DRIVE_path_boot"
      sed -i 's/#extra_kernel_version_strings linux-lts,linux/extra_kernel_version_strings linux-lts,linux-zen,linux-hardened,linux/' /boot/efi/EFI/BOOT/refind.conf	
      sed -i 's/#also_scan_dirs boot,ESP2:EFI\/linux\/kernels/also_scan_dirs + @\/boot/' /boot/efi/EFI/BOOT/refind.conf	
      sed -i 's/#use_graphics_for osx,linux/use_graphics_for linux/' /boot/efi/EFI/BOOT/refind.conf
      sed -i 's/#scanfor internal,external,optical,manual/scanfor manual,external/' /boot/efi/EFI/BOOT/refind.conf
      mkdir -p /boot/efi/EFI/BOOT/themes
      cd /boot/efi/EFI/BOOT/themes || exit
      git clone https://github.com/kgoettler/ursamajor-rEFInd.git
        cat << EOF >> /boot/efi/EFI/BOOT/refind.conf

include themes/ursamajor-rEFInd/theme.conf
EOF
      if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
        export microcode="intel-ucode.img"
      elif grep -q AMD "/proc/cpuinfo"; then
        export microcode="amd-ucode.img"
      fi
      rm /boot/refind_linux.conf
      touch /boot/refind_linux.conf
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
        cat << EOF >> /boot/refind_linux.conf
"Boot using default options"     "rd.luks.name=$UUID_1=cryptroot rw root=/dev/mapper/cryptroot add_efi_memmap initrd=/boot/$microcode initrd=/boot/initramfs-%v.img"
"Boot using fallback initramfs"  "rd.luks.name=$UUID_1=cryptroot rw root=/dev/mapper/cryptroot add_efi_memmap initrd=/boot/$microcode initrd=/boot/initramfs-%v-fallback.img"
EOF
      else	
        cat << EOF >> /boot/refind_linux.conf
"Boot using default options"     "root=UUID=$UUID_1 rw rootflags=subvol=@ add_efi_memmap initrd=/boot/$microcode initrd=/boot/initramfs-%v.img"
"Boot using fallback initramfs"  "root=UUID=$UUID_1 rw rootflags=subvol=@ add_efi_memmap initrd=/boot/$microcode initrd=/boot/initramfs-%v-fallback.img"
EOF
      fi
      mkdir -p /etc/pacman.d/hooks
      touch /etc/pacman.d/hooks/refind.hook
      cat << EOF | tee -a /etc/pacman.d/hooks/refind.hook > /dev/null

[Trigger]
Operation=Upgrade
Type=Package
Target=refind

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install

EOF
    fi
}

  SYSTEM_10_MISCELLANEOUS() {
    cat << EOF | tee -a /etc/pam.d/system-login > /dev/null
auth optional pam_faildelay.so delay="$LOGIN_delay"
EOF
    if [[ "$INIT_choice" == "openrc" ]]; then
      sed -i 's/#rc_parallel="NO"/rc_parallel="YES"/g' /etc/rc.conf
      sed -i 's/#unicode="NO"/unicode="YES"/g' /etc/rc.conf
      sed -i 's/#rc_depend_strict="YES"/rc_depend_strict="NO"/g' /etc/rc.conf
    fi
    echo 'PRUNENAMES = ".snapshots"' >> /etc/updatedb.conf ## Prevent snapshots from being indexed
}

  SYSTEM_11_EXTERNAL_SCRIPT() {
    if [[ "$CUSTOM_script" == "true" ]]; then
      cd /install_script || exit
      REPO_folder=$(basename "$REPO")
      git clone --quiet "$REPO"
      cd "$REPO_folder" || exit
      chmod u+x -- "$SCRIPT"
      ./"$SCRIPT"
    fi
}

  SYSTEM_12_CLEANUP() {
    rm -rf /install_script
    pacman -Rns --noconfirm lolcat figlet
}

  SCRIPT_12_FAREWELL() {
    echo
    PRINT_MESSAGE "${messages[12]}" 
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
