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
    /dev/sda2 -> / ~65Go
    /dev/sda3 -> /home ~the rest'
    read -s
    cfdisk /dev/sda
    ;;
  format)
    mkfs.ext4 -O ^64bit /dev/sda1
    mkfs.ext4 -O ^64bit /dev/sda2
    mkfs.ext4 -O ^64bit /dev/sda3
    mount /dev/sda2 /mnt
    mkdir /mnt/{boot,home}
    mount /dev/sda1 /mnt/boot
    mount /dev/sda3 /mnt/home
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
    echo "lolo-desktop" >> /etc/hostname
    #vim /etc/hostname

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
    echo ' add ... keymap ... to HOOKS before filesystems'
    read -s
    vim /etc/mkinitcpio.conf
    mkinitcpio -p linux
    ;;
  bootloader)
    echo ' entries for Arch should use the following APPEND:'
    echo 'APPEND root=/dev/sda2 rw'
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
    pacman -Syu xorg-server xorg-xinit xorg-server-utils nvidia-340xx nvidia-340xx-settings
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
  yay)
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay
    ;;
  wm)
    yay -Syu awesome
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

exec awesome' > ~/.xinitrc
    cat ~/.xinitrc
    ;;
  misc)
    yay -Syua mupdf slock \
      xterm udiskie xautolock zsh-completions scrot \
      zsh-syntax-highlighting chromium meld mercurial \
      screen tree unrar weechat wget htop screenfetch ttf-hack \
      imagemagick openssh python-dbus python-keyring python-keyrings-alt \
      python-pip python2-dbus python2-pip rsync ruby tcl cmake
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
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
      - yay
      - wm
      - misc
      - ssh

    reboot'
    ;;
esac
