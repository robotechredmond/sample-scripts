# Install latest mainline kernel release on CentOS 7.x

# sudo to root
sudo -s

# Check current kernel version and distro release
cat /proc/version
uname -mrs
cat /etc/centos-release

# Download and import ELRepo public key
wget https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm --import RPM-GPG-KEY-elrepo.org

# Enable ELRepo package repository
wget http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
rpm -i -f elrepo-release-7.0-2.el7.elrepo.noarch.rpm

# List available kernel packages in ELRepo package repository
yum list available --disablerepo="*" --enablerepo=elrepo-kernel

# Install latest mainline kernel package from ELRepo package repository
yum --disablerepo="*" --enablerepo=elrepo-kernel install kernel-ml

# Get the kernel boot options
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg

# Set the default boot option to the new kernel
grub2-set-default "CentOS Linux (4.13.4-1.el7.elrepo.x86_64) 7 (Core)"

# Reboot into new kernel
reboot
shutdown -r now
shutdown -r 0

# Confirm new kernel version is installed
cat /proc/version
uname -mrs

