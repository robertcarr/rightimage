bash "install vmware tools" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{node.rightimage.target_mnt}
    TMP_DIR=/tmp/vmware_tools

# TODO: THIS NEEDS TO BE CLEANED UP
  case "#{node.rightimage.platform}" in 
    "centos" )
      chroot $target_mnt mkdir -p $TMP_DIR
      chroot $target_mnt curl http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub -o $TMP_DIR/dsa.pub
      chroot $target_mnt curl http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -o $TMP_DIR/rsa.pub
      chroot $target_mnt rpm --import $TMP_DIR/dsa.pub
      chroot $target_mnt rpm --import $TMP_DIR/rsa.pub
      cat > $target_mnt/etc/yum.repos.d/vmware-tools.repo <<EOF
[vmware-tools] 
name=VMware Tools 
baseurl=http://packages.vmware.com/tools/esx/latest/rhel5/x86_64
enabled=1 
gpgcheck=1
EOF
   yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all
   yum -c $target_mnt/etc/yum.conf --installroot=$target_mnt -y install vmware-tools-nox
    ;;

  "ubuntu" )
    # https://help.ubuntu.com/community/VMware/Tools#Installing VMware tools on an Ubuntu guest
    chroot $target_mnt apt-get install -y --no-install-recommends open-vm-dkms
    chroot $target_mnt apt-get install -y --no-install-recommends open-vm-tools 
    ;;

 esac


  EOH
end

