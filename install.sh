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
country=$(curl -4 ifconfig.co/country-iso)
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector -a 48 -c $country -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

timedatectl set-ntp true
pacman -Syyy --noconfirm

# Prepare partitions
sgdisk --zap-all ${disk}
sgdisk -n 1:0:+512M ${disk} # partition 1 (BOOT), default start block, 512MB
sgdisk -n 2:0:0 ${disk} # partition 3 (Root), default start, remaining

# Setting partition types
sgdisk -t 1:ef00 ${disk}
sgdisk -t 2:8300 ${disk}

# Setting up root partition
yes | mkfs.ext4 ${disk}2
mount ${disk}2 /mnt

# Setting up boot partition
mkfs.fat -F32 ${disk}1
mkdir /mnt/boot
mount ${disk}1 /mnt/boot

# Installing Arch Linux
pacstrap /mnt base base-devel linux linux-firmware $cpu_microcode
genfstab -U /mnt >> /mnt/etc/fstab

# Allocate SWAP if RAM is below 8GB
ram=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $ram -lt 8000000 ]]; then
    mkdir /mnt/opt/swap 
    dd if=/dev/zero of=/mnt/opt/swap/swapfile bs=1M count=4096 status=progress
    chmod 600 /mnt/opt/swap/swapfile #set permissions.
    chown root /mnt/opt/swap/swapfile
    mkswap /mnt/opt/swap/swapfile
    swapon /mnt/opt/swap/swapfile
    echo "/opt/swap/swapfile	none	swap	sw	0	0" >> /mnt/etc/fstab #Add swap to fstab.
fi

echo "Configuring new system"
arch-chroot /mnt /bin/bash << EOF
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
locale-gen
echo "KEYMAP=us" > /etc/vconsole.conf
echo $hostname >> /etc/hostname
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     $hostname.localdomain   $hostname" >> /etc/hosts
echo -en "$password\n$password" | passwd

# Installing packages
pacman -Sy --noconfirm grub efibootmgr dhcpcd networkmanager vim linux-headers wget git

# Configuring grub
grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=ArchLinux
grub-mkconfig -o /boot/grub/grub.cfg

# Creating new user
useradd -m -G wheel,video,audio $username
echo -en "$password\n$password" | passwd $username
echo '%wheel ALL=(ALL) ALL' | EDITOR='tee -a' visudo

# Enabling services
systemctl enable fstrim.timer
systemctl enable NetworkManager dhcpcd

EOF

umount -R /mnt

echo "Arch Linux is ready. You can reboot now!"
