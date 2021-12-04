#!/bin/sh

# Set different microcode, kernel params and initramfs modules according to CPU vendor
cpu_vendor=$(cat /proc/cpuinfo | grep vendor | uniq)
cpu_microcode=""
if [[ $cpu_vendor =~ "AuthenticAMD" ]]
then
 cpu_microcode="amd-ucode"
elif [[ $cpu_vendor =~ "GenuineIntel" ]]
then
 cpu_microcode="intel-ucode"
fi

#or all the packages installed "as explicitly", change their installation reason to "as dependency":
pacman -D --asdeps $(pacman -Qqe)
#change the installation reason to "as explicitly" of only the essential packages, those you do not want to remove
pacman -D --asexplicit base base-devel linux linux-firmware $cpu_microcode

#Installing base system
pacman -Sy --noconfirm grub efibootmgr dhcpcd networkmanager vim linux-headers wget git

#Grub config
grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=ArchLinux
grub-mkconfig -o /boot/grub/grub.cfg

#Enabling services
systemctl enable fstrim.timer
systemctl enable NetworkManager dhcpcd

printf "\e[1;32mDone! Arch reset has been done.REBOOT.\e[0m"
