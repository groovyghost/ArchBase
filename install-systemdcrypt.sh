#!/bin/bash

# Set Timezone
timezone=$(tzselect)
test -n "$timezone"
# Drive to install to.
lsblk
echo "Enter Disk to install: (example /dev/sda)"
read disk
# Hostname of the installed machine.
echo "Enter Hostname: "
read hostname
# Main username to create (by default, added to wheel group).
echo "Enter Username: "
read username
# The password for user and root
echo "Enter User Password: "
read password
# The Encryption for disk
echo "Enter Passpharse for encryption: "
read encryption_passphrase
country=$(curl -4 ifconfig.co/country-iso)

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

echo "Finding best mirrors"
timedatectl set-ntp true
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector -a 48 -c $country -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syyy --noconfirm

echo "Wiping drive"
sgdisk --zap-all /dev/sda

echo "Creating partition tables"
printf "n\n1\n4096\n+512M\nef00\nw\ny\n" | gdisk /dev/sda
printf "n\n2\n\n\n8e00\nw\ny\n" | gdisk /dev/sda

echo "Setting up cryptographic volume"
mkdir -p -m0700 /run/cryptsetup
echo "$encryption_passphrase" | cryptsetup -q --align-payload=8192 -h sha512 -s 512 --use-random --type luks2 -c aes-xts-plain64 luksFormat /dev/sda2
echo "$encryption_passphrase" | cryptsetup luksOpen /dev/sda2 cryptlvm

echo "Creating physical volume"
pvcreate /dev/mapper/cryptlvm

echo "Creating volume volume"
vgcreate vg0 /dev/mapper/cryptlvm

echo "Creating logical volumes"
lvcreate -l +100%FREE vg0 -n root

echo "Setting up / partition"
yes | mkfs.ext4 /dev/vg0/root
mount /dev/vg0/root /mnt

echo "Setting up /boot partition"
yes | mkfs.fat -F32 /dev/sda1
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

echo "Installing Arch Linux"
yes '' | pacstrap /mnt base base-devel efibootmgr linux linux-headers linux-lts linux-lts-headers linux-firmware lvm2 device-mapper dosfstools e2fsprogs $cpu_microcode cryptsetup networkmanager wget man-db man-pages nano vim diffutils lm_sensors

echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Configuring new system"
arch-chroot /mnt /bin/bash << EOF
echo "Setting system clock"
timedatectl set-ntp true
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc --localtime
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
locale-gen
echo "KEYMAP=us" > /etc/vconsole.conf
echo $hostname > /etc/hostname
echo -en "$password\n$password" | passwd

# Creating new user
useradd -m -G wheel,video -s /bin/bash $username
echo -en "$password\n$password" | passwd $username
echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo

# Generating initramfs
sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt sd-lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
sed -i 's/^MODULES.*/MODULES=(ext4 $initramfs_modules)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Setting up systemd-boot
bootctl --path=/boot install

mkdir -p /boot/loader/
tee -a /boot/loader/loader.conf << END
default arch.conf
timeout 2
console-mode max
editor no
END

mkdir -p /boot/loader/entries/
touch /boot/loader/entries/arch.conf
tee -a /boot/loader/entries/arch.conf << END
title Arch Linux
linux /vmlinuz-linux
initrd /$cpu_microcode.img
initrd /initramfs-linux.img
options rd.luks.name=$(blkid -s UUID -o value /dev/sda2)=cryptlvm root=/dev/vg0/root rd.luks.options=discard$kernel_options nmi_watchdog=0 quiet rw
END

touch /boot/loader/entries/arch-lts.conf
tee -a /boot/loader/entries/arch-lts.conf << END
title Arch Linux LTS
linux /vmlinuz-linux-lts
initrd /$cpu_microcode.img
initrd /initramfs-linux-lts.img
options rd.luks.name=$(blkid -s UUID -o value /dev/sda2)=cryptlvm root=/dev/vg0/root rd.luks.options=discard$kernel_options nmi_watchdog=0 quiet rw
END

# Setting up Pacman hook for automatic systemd-boot updates
mkdir -p /etc/pacman.d/hooks/
touch /etc/pacman.d/hooks/systemd-boot.hook
tee -a /etc/pacman.d/hooks/systemd-boot.hook << END
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
END

# Enabling Services
systemctl enable fstrim.timer
systemctl enable NetworkManager


EOF

umount -R /mnt

echo "Arch Linux is ready. You can reboot now!"
