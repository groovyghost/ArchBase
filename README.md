# Arch-Base Install
As a Newbie Linux-User setting up an Arch system from scratch is usually a time-intensive process.So i set out in developing scripts which transforms a blank hard drive to a fully functional Arch system with all my files, applications, and preferences set, as efficiently and with the least inputs from the user as possible.
Typically a complete install takes me between two and three hours.About and hour for the base install, and a couple hours for all the packages to download.This is why installing Arch Linux is a challenge in itself but at the same time, it is a learning opportunity for intermediate Linux users.

If you are curious as to why I use Arch you can read [Why Arch Linux](https://github.com/ghostr72/archgnome/blob/main/why-arch.md)

Note: Some of the package choices and tweaks are specific to my setup.

So...

### Don't just run these scripts. Examine them. Customize them.

## Installation guide

1. Download and boot into the latest [Arch Linux iso](https://www.archlinux.org/download/)
2. Connect to the internet.
3. To install directly with default variables `bash <(curl -Ls https://raw.githubusercontent.com/ghostr72/ArchBase/main/install.sh)`

OR

4. Sync repos and install wget `pacman -Sy wget`
5. `wget https://raw.githubusercontent.com/ghostr72/ArchBase/main/install.sh`
6. Change the variables at the top of the file (lines 3 through 9)
   - continent_country must have the following format: Zone/SubZone . e.g. Europe/Berlin
   - run `timedatectl list-timezones` to see full list of zones and subzones
7. Make the script executable: `chmod +x install.sh`
8. Run the script: `./install.sh`
9. Reboot into Arch Linux


## Post-Scripts 

For Awesome WM :
https://github.com/ghostr72/dots
