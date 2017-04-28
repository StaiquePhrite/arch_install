#!/bin/bash
trap '[[ $BASH_COMMAND != echo* ]] && echo "
--- $BASH_COMMAND ---"' DEBUG

case $1 in
  kbd)
    # keyboard layout
    loadkeys fr-pc
    ;;
  disks)
    # partition mgmt (use fdisk to create partition is not done already)
    echo ' ex:
    /dev/sda1 -> /boot ~500Mo
    /dev/sda2 -> Encrypted LVM'
    read -s
    cfdisk /dev/sda
    cfdisk /dev/sdb
    ;;
  encrypt)
    modprobe dm_crypt
    cryptsetup -c aes-xts-plain64 -s 512 -h sha512 -i 5000 -y luksFormat /dev/sdb1
    cryptsetup luksDump /dev/sdb1
    cryptsetup luksOpen /dev/sdb1 crypt
    ;;
  LVM)
    pvcreate /dev/mapper/crypt
    vgcreate lvmpool /dev/mapper/crypt
    lvcreate -L 25GB -n groundzero lvmpool
    lvcreate -l 100%FREE -n home lvmpool
    ;;
  format)
    mkfs.ext4 -O ^64bit /dev/sda1
    mkfs.ext4 -O ^64bit /dev/mapper/lvmpool-groundzero
    mkfs.ext4 -O ^64bit /dev/mapper/lvmpool-home
    mount /dev/mapper/lvmpool-groundzero /mnt
    mkdir /mnt/{boot,home}
    mount /dev/sda1 /mnt/boot
    mount /dev/mapper/lvmpool-home /mnt/home
    ;;
  strap)
    # system install
    pacstrap /mnt base base-devel syslinux zsh vim git
    genfstab -U -p /mnt >> /mnt/etc/fstab
    cat /mnt/etc/fstab

    echo ' next steps are to be performed in chroot, run:
    arch-chroot /mnt'
    ;;
  locale)
    # locales & stuff
    vim /etc/hostname

    vim /etc/locale.gen # UNCOMMENT WANTED LOCALE
    locale-gen

    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    export LANG=en_US.UTF-8
    cat /etc/locale.conf

    echo "KEYMAP=fr-pc" >> /etc/vconsole.conf
    cat /etc/vconsole.conf

    ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
    ;;
  ramdisk)
    echo ' add ... keymap encrypt lvm2 ... to HOOKS before filesystems'
    read -s
    vim /etc/mkinitcpio.conf
    mkinitcpio -p linux
    ;;
  bootloader)
    echo ' entries for Arch should use the following APPEND:'
    echo 'APPEND root=/dev/mapper/lvmpool-groundzero cryptdevice=/dev/sdb1:crypt ro'
    read -s
    vim /boot/syslinux/syslinux.cfg
    syslinux-install_update -iam
    ;;
  users)
    echo ' change root passwd:'
    passwd

    echo ' create new user (lolo):'
    useradd -g users -m -s /bin/zsh lolo
    passwd lolo

    echo ' add "lolo  ALL=(ALL) ALL" to sudoers file'
    read -s
    visudo
    ;;
  video)
    pacman -Syu xorg-server xorg-xinit xorg-server-utils xf86-video-nouveau mesa
    ;;
  xorg)
    # xorgconfig for keyboard
    echo 'Section "InputClass"
    Identifier         "Keyboard Layout"
    MatchIsKeyboard    "yes"
    Option             "XkbLayout"  "fr"
    Option             "XkbVariant" "latin9"
EndSection' > /etc/X11/xorg.conf.d/10-keyboard-layout.conf
    cat /etc/X11/xorg.conf.d/10-keyboard-layout.conf

    echo 'Section "InputClass"
    Identifier         "Keyboard Terminate"
    MatchIsKeyboard    "yes"
    Option             "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection' > /etc/X11/xorg.conf.d/10-keyboard-terminate.conf
    cat /etc/X11/xorg.conf.d/10-keyboard-terminate.conf
    ;;
  fonts)
    pacman -S xorg-fonts-type1 ttf-dejavu artwiz-fonts font-bh-ttf \
      font-bitstream-speedo gsfonts sdl_ttf ttf-bitstream-vera \
      ttf-cheapskate ttf-liberation \
      ttf-freefont ttf-arphic-uming ttf-baekmuk
    ;;
  yaourt)
    git clone https://aur.archlinux.org/package-query.git
    cd package-query
    makepkg -si
    cd ..
    rm -rf package-query

    git clone https://aur.archlinux.org/yaourt.git
    cd yaourt
    makepkg -si
    cd ..
    rm -rf yaourt
    ;;
  wm)
    yaourt -Syu awesome compton
    echo '[[ -t 0 && $(tty) =~ /dev/tty ]] && ! pgrep -u $USER startx &> /dev/null && startx' > ~/.zprofile
    cat ~/.zprofile
    echo '#!/bin/sh
[[ -f $HOME/.Xresources ]] && xrdb -merge $HOME/.Xresources

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi

# xdg-open is fucked up w/o $DE
export DE=gnome

setxkbmap fr
compton -b

exec awesome' > ~/.xinitrc
    cat ~/.xinitrc
    ;;
  misc)
    yaourt -Syua mupdf slock \
      terminator tig udiskie xautolock zsh-completions \
      zsh-syntax-highlighting chromium gimp meld mercurial \
      screen tree unrar weechat wget htop \
      imagemagick openssh python-dbus python-keyring python-keyrings-alt \
      python-pip python2-dbus python2-pip rsync w3m aspell ruby tcl cmake
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    sudo pip2 install notify2
    ;;
  ssh)
    echo ' run:
    ssh-keygen -t rsa -b 4096 -C "user@domain.com"'
    ;;
  *)
    echo 'installation steps:
    - live cd:
      - kbd
      - disks
      - encrypt
      - LVM
      - format
      - strap

    arch-chroot /mnt

    - chrooted:
      - locale
      - ramdisk
      - bootloader
      - users
      - video
      - xorg
      - fonts

    exit
    umount -R /mnt
    reboot

    - logged user:
      - yaourt
      - wm
      - misc
      - ssh

    reboot'
    ;;
esac
