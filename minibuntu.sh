#! /bin/dash


#  minibuntu.sh version 20200113.

#  minibuntu.sh installs Ubuntu.

#  Configure minibuntu.sh by adjusting these variables:

dev_disk=/dev/sda
dev_boot=/dev/sda2                 #  ext2              /boot
dev_luks=/dev/sda3                 #  luks encrypted    for /
dev_root=/dev/mapper/sda3_crypt    #  btrfs or ext4     /
fs_root=btrfs                      #  btrfs or ext4

debootstrap_suite=eoan    #  eoan is Ubuntu 19.10

hostname=minibuntu
xkbvariant=''

user_1000=mini
user_1000_groups=adm,cdrom,sudo,dip,plugdev
user_1000_shell=/bin/dash

ip_link_name=''


#  Below are the four varibales I typically need to adjust:
#  hostname=
#  xkbvariant=
#  user_1000=
#  ip_link_name=


#  todo:  fix:  initramfs ignores xkbvariant


#  ---------------------------------------------------------------------------


set  -o errexit


usage  ()  (    #  ----------------------------------------------------  usage
  echo  ''
  echo  'Usage:  sudo dash minibuntu.sh <command>'
  echo  ''
  echo  'Recommended usage is to run the commands in the following order:'
  echo  '  partition     create gpt partitions for / and /boot'
  echo  '  format        format the partitions'
  echo  '  mount_root    mount the partitions inside /mnt'
  echo  '  bootstrap     run debootstrap on /mnt'
  echo  '  mount_dev     mount /dev, /proc, /run, and /sys inside /mnt'
  echo  '  packages      install additional packages inside /mnt'
  echo  '  configure     configure various settings inside /mnt'
  echo  '  kernel        install a kernel and grub inside /mnt'
  echo  ''
  echo  'After running the above commands in order, you should be able to'
  echo  'boot into the new installation of Ubuntu.'
  echo  ''
  echo  '(Note: If you use an Ubuntu Desktop live .iso, you may need to'
  echo  ' remove the installation media as the "Boot from first hard disk"'
  echo  ' option seems to fail on some (all?) systems.)'
  echo  ''  )


trace  ()  (    #  ----------------------------------------------------  trace
  echo  ;  set  -o xtrace  ;  "$@"  )


partition  ()  (    #  --------------------------------------------  partition

  echo  ;  echo  'minibuntu  partition'

  for  partition  in  $dev_disk?*  ;  do
    if  [ -e "$partition" ];  then
      echo
      echo  'Found existing partition(s): ' $dev_disk?*
      echo  'Please delete any existing partitions and try again.'
      return  ;  fi  ;  done

  #  ef02 is BIOS boot partition
  trace  sgdisk  $dev_disk  --clear	\
    --new=2:2048:+500M			\
    --new=1:34:2047  --typecode=1:ef02	\
    --new=3

  trace  gdisk  -l  $dev_disk
  echo  ;  echo  'minibuntu  partition  done'  ;  echo  )


luksFormat  ()  (    #  ------------------------------------------  luksFormat
  if  [ ! -e $dev_root ];  then
    trace  cryptsetup  luksFormat  $dev_luks  ;  fi  )


luksOpen  ()  (    #  ----------------------------------------------  luksOpen
  if  [ ! -e $dev_root ];  then
    trace  cryptsetup  luksOpen  $dev_luks  ${dev_root##*/}  ;  fi  )


format  ()  (    #  --------------------------------------------------  format
  echo  ;  echo  'minibuntu  format'
  trace  mkfs.ext2  $dev_boot
  luksFormat
  luksOpen
  case  "$fs_root"  in
    (btrfs)  trace  mkfs.btrfs  $dev_root
             trace  mount   $dev_root  /mnt
             trace  btrfs   subvolume  create  /mnt/@
             trace  btrfs   subvolume  create  /mnt/@home
             trace  umount  /mnt  ;;
    (ext4)   trace  mkfs.ext4   $dev_root  ;;
    (*)  echo  "format  bad fs_root  $fs_root"  ;  exit 1  ;;  esac
  sync  ;  sleep 0.5
  echo  ;  echo  'minibuntu  format  done'  ;  echo  )


mount_root  ()  (    #  ------------------------------------------  mount_root
  echo  ;  echo  'minibuntu  mount_root'
  if  [ ! -d /mnt/boot ];  then
    luksOpen
    case  "$fs_root"  in
      (btrfs)
        trace  mount  -o rw,relatime,subvol=@      $dev_root  /mnt
        mkdir  -p  /mnt/home
        trace  mount  -o rw,relatime,subvol=@home  $dev_root  /mnt/home  ;;
      (ext4)   trace  mount  -o rw,relatime               $dev_root  /mnt  ;;
      (*)  echo  "mount  bad fs_root  $fs_root"  ;  exit 1  ;;  esac
    mkdir  -p  /mnt/boot
    trace  mount  $dev_boot  /mnt/boot  ;  fi
  echo  ;  mount  |  grep /mnt
  echo  ;  echo  'ubuntustrap  mount_root  done'  ;  echo  )


umount_root  ()  (    #  ----------------------------------------  umount_root
  echo  ;  echo  'ubuntustrap  umount_root'
  echo  '  not implemented'  )


bootstrap  ()  (    #  --------------------------------------------  bootstrap
  echo  ;  echo  'minibuntu  bootstrap'
  if  ! which debootstrap > /dev/null;  then
    trace  apt-get  install  debootstrap  ;  fi
  debootstrap  $debootstrap_suite  /mnt
  echo  ;  echo  'minibuntu  bootstrap  done'  ;  echo  )


mount_dev  ()  (    #  --------------------------------------------  mount_dev
  echo  ;  echo  'ubuntustrap  mount_dev'
  rm  -rf  /mnt/dev  /mnt/run
  mkdir    /mnt/dev  /mnt/run
  trace  mount  --rbind  /dev   /mnt/dev
  trace  mount  --rbind  /run   /mnt/run
  trace  mount  --rbind  /sys   /mnt/sys
  trace  mount  -t proc  /proc  /mnt/proc
  echo  ;  mount  |  grep /mnt
  echo  ;  echo  'ubuntustrap  mount_dev  done'  ;  echo  )


sources_list  ()  (    #  --------------------------------------  sources_list

  server='http://us.archive.ubuntu.com/ubuntu/'
  suite="$debootstrap_suite"

trace  dd  of=/mnt/etc/apt/sources.list  <<EOF
#  deb  cdrom:[Ubuntu 19.10 _Eoan Ermine_ - Release amd64 (20191017)]/  $suite  main  restricted

# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb      $server  $suite  main  restricted
deb-src  $server  $suite  main  restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb      $server  $suite-updates  main  restricted
deb-src  $server  $suite-updates  main  restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb      $server  $suite          universe
deb-src  $server  $suite          universe
deb      $server  $suite-updates  universe
deb-src  $server  $suite-updates  universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb      $server  $suite          multiverse
deb-src  $server  $suite          multiverse
deb      $server  $suite-updates  multiverse
deb-src  $server  $suite-updates  multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
#  deb      $server  $suite-backports  main  restricted  universe  multiverse
#  deb-src  $server  $suite-backports  main  restricted  universe  multiverse

## Uncomment the following two lines to add software from Canonical's
## 'partner' repository.
## This software is not part of Ubuntu, but is offered by Canonical and the
## respective vendors as a service to Ubuntu users.
#  deb      http://archive.canonical.com/ubuntu  $suite  partner
#  deb-src  http://archive.canonical.com/ubuntu  $suite  partner

##  N.B. below are the Ubuntu security repositories.
deb      http://security.ubuntu.com/ubuntu  $suite-security  main  restricted
deb-src  http://security.ubuntu.com/ubuntu  $suite-security  main  restricted
deb      http://security.ubuntu.com/ubuntu  $suite-security  universe
deb-src  http://security.ubuntu.com/ubuntu  $suite-security  universe
deb      http://security.ubuntu.com/ubuntu  $suite-security  multiverse
deb-src  http://security.ubuntu.com/ubuntu  $suite-security  multiverse

# This system was installed using small removable media
# (e.g. netinst, live or single CD). The matching "deb cdrom"
# entries were disabled at the end of the installation process.
# For information about how to configure apt package sources,
# see the sources.list(5) manual.
EOF

  return  )


packages  ()  (    #  ----------------------------------------------  packages
  echo  ;  echo  'minibuntu  packages'
  sources_list
  trace  chroot  /mnt  apt-get  update
  trace  chroot  /mnt  apt-get  install  btrfs-progs
  trace  chroot  /mnt  apt-get  install  cryptsetup-initramfs
  trace  chroot  /mnt  apt-get  install  man-db  manpages  manpages-dev
  trace  chroot  /mnt  apt-get  install  htop  jed  jed-extra  rsync
  echo  ;  echo  'minibuntu  packages  done'  ;  echo  )


crypttab  ()  (    #  ----------------------------------------------  crypttab

  uuid_luks=`  blkid  $dev_luks  --match-tag UUID  --output value  `
  target="${dev_root##*/}"

  echo  "$target UUID=$uuid_luks none luks,discard"  >  /mnt/etc/crypttab

  trace  cat  /mnt/etc/crypttab  )


fstab_line  ()  (    #  ------------------------------------------  fstab_line
  if  [ "$2" ];  then
    printf  '%-46s  %-14s  %-6s  %-30s  %-6s  %-6s\n'  "$@"  \
      >>  /mnt/etc/fstab
  else  echo  "$1"  >>  /mnt/etc/fstab  ;  fi  )


fstab  ()  (    #  ----------------------------------------------------  fstab

  boot_uuid=`  blkid  $dev_boot  --match-tag UUID  --output value  `

  trace  dd  of=/mnt/etc/fstab  <<EOF
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
EOF

  fstab_line  '# <device>'  '<mount point>'  '<type>'  '<options>'  \
    '<dump>'  '<pass>'

  case  "$fs_root"  in
    (btrfs)
      fstab_line  "$dev_root"  /      btrfs  rw,relatime,subvol=@      0  1
      fstab_line  "$dev_root"  /home  btrfs  rw,relatime,subvol=@home  0  2  ;;
    (ext4)
      fstab_line  "$dev_root"  /      ext4   rw,relatime               0  1  ;;
    esac

  fstab_line  "# /boot was on $dev_boot during installation"
  fstab_line  "UUID=$boot_uuid"  '/boot'  ext2  rw,relatime  0  2

  trace  cat  /mnt/etc/fstab  )


keyboard  ()  (    #  ----------------------------------------------  keyboard
  trace  dd  of=/mnt/etc/default/keyboard  <<EOF
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="$xkbvariant"
XKBOPTIONS=""

BACKSPACE="guess"
EOF

  trace  cat  /mnt/etc/default/keyboard  )


hostname  ()  (    #  ----------------------------------------------  hostname
  trace  echo  "$hostname"  |  dd  of=/mnt/etc/hostname  )



netplan  ()  (    #  ------------------------------------------------  netplan

  trace  dd  of=/mnt/etc/netplan/01-netcfg.yaml  <<EOF
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    $ip_link_name:
      dhcp4: yes
EOF

  trace  cat  /mnt/etc/netplan/01-netcfg.yaml  )


useradd  ()  (    #  ------------------------------------------------  useradd
  trace  chroot  /mnt  groupadd  --gid 1000  $user_1000  ||  true
  trace  chroot  /mnt  useradd  \
    --uid 1000				\
    --gid 1000				\
    --groups $user_1000_groups		\
    --home-dir	/home/$user_1000	\
    --create-home			\
    --shell $user_1000_shell		\
    $user_1000  ||  true
  echo  ;  echo  "Set new password for user '$user_1000' (user 1000):"
  chroot  /mnt  passwd  $user_1000  )


configure  ()  (    #  --------------------------------------------  configure
  echo  ;  echo  'minibuntu  configure'
  crypttab
  fstab
  hostname
  keyboard
  netplan
  useradd
  echo  ;  echo  'minibuntu  configure  done'  ;  echo  )


kernel  ()  (    #  --------------------------------------------------  kernel
  echo  ;  echo  'minibuntu  kernel'
  trace  chroot  /mnt  apt-get  update
  trace  chroot  /mnt  apt-get  install  linux-image-generic
  trace  ls  -lh  /mnt/boot
  echo  ;  echo  'minibuntu  kernel  done'  ;  echo  )


main  ()  (    #  ------------------------------------------------------  main
  case  "$1"  in

    ( partition  )    "$1"  ;;
    ( format     )    "$1"  ;;
    ( mount_root )    "$1"  ;;
    ( bootstrap  )    "$1"  ;;
    ( mount_dev  )    "$1"  ;;
    ( packages   )    "$1"  ;;
    ( configure  )    "$1"  ;;
    ( kernel     )    "$1"  ;;
    ( umount     )    "$1"  ;;    #  not implemented yet
    ( *          )    "usage"  ;;  esac  )


main  "$@"
