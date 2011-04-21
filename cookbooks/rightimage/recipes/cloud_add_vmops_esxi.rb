class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to esxi!"  if node[:rightimage][:virtual_environment] != "esxi"


source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

bundled_image = "cloudstack_esxi_dev40.vmdk"
bundled_image_path = "/mnt/#{bundled_image}"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"

bash "create cloudstack-esxi loopback fs" do 
  code <<-EOH
    set -e 
    set -x

    DISK_SIZE_GB=10  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    source_image="#{node.rightimage.mount_dir}" 
    target_raw_path="#{target_raw_path}"
    target_mnt="#{target_mnt}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{target_mnt}/proc || true 
    umount -lf #{target_mnt} || true
    rm -rf $target_raw_path $target_mnt

    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    

    loopdev=#{loop_dev}
    loopmap=#{loop_map}
    umount -lf $loopmap || true
    kpartx -d $loopdev || true
    losetup -d $loopdev || true

    losetup $loopdev $target_raw_path

    sfdisk $loopdev << EOF
0,1304,L
EOF
   
    kpartx -a $loopdev
    mke2fs -F -j $loopmap
    
    # setup uuid for our root partition
    tune2fs -U #{node[:rightimage][:root_mount][:uuid]} $loopmap
    
    mkdir $target_mnt
    mount $loopmap $target_mnt

    rsync -a $source_image/ $target_mnt/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    mount -t proc none $target_mnt/proc
    mount --bind /dev $target_mnt/dev
  EOH
end

# add fstab
template "#{target_mnt}/etc/fstab" do
  source "fstab.erb"
  backup false
end

# insert grub conf
template "#{target_mnt}/boot/grub/grub.conf" do 
  source "grub.conf"
  backup false 
end

bash "setup grub" do 
  code <<-EOH
    set -e 
    set -x

    target_raw_path="#{target_raw_path}"
    target_mnt="#{target_mnt}"

    chroot $target_mnt mkdir -p /boot/grub

    case "#{node.rightimage.platform}" in
      "ubuntu" )
        grub_command="/usr/sbin/grub"
        ;;

      "ec2"|* )
        chroot $target_mnt cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
        grub_command="/sbin/grub"
        ;;
    esac

    chroot $target_mnt ln -sf /boot/grub/grub.conf /boot/grub/menu.lst

    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $target_mnt/boot/grub/device.map
    echo "" >> $target_mnt/boot/grub/device.map

    cat > device.map <<EOF
(hd0) #{target_raw_path}
EOF
    ${grub_command} --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF 

  EOH
end

bash "create custom initrd" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

  case "#{node.rightimage.virtual_environment}" in
    "ec2" )
      rm -f $target_mnt/boot/initrd*
      chroot $target_mnt mkinitrd --with=mptbase --with=mptscsih --with=mptspi --with=scsi_transport_spi --with=ata_piix --with=ext3 -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
      mv $target_mnt/initrd-#{node[:rightimage][:kernel_id]}  $target_mnt/boot/.
      ;;
     "kvm"|"esxi" )
        # NOTE: Do we really need to build our own ramdisk since we are using vmbuilder
      ;;
  esac

  EOH
end

bash "install vmware tools" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
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
    ;;

 esac


  EOH
end

bash "configure for cloudstack" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

  case "#{node.rightimage.platform}" in
    "ec2" )
      # clean out packages
      yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all

      # configure dns timeout 
      echo 'timeout 300;' > $target_mnt/etc/dhclient.conf

      rm ${target_mnt}/var/lib/rpm/__*
      chroot $target_mnt rpm --rebuilddb
      ;;

    "ubuntu" )
      echo 'timeout 300;' > $target_mnt/etc/dhcp3/dhclient.conf
      ;;
     
  esac 

    mkdir -p $target_mnt/etc/rightscale.d
    echo "vmops" > $target_mnt/etc/rightscale.d/cloud


  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    umount -lf $target_mnt/proc
    umount -lf $target_mnt/dev
  EOH
end

# Clean up guest image
rightimage target_mnt do
  action :sanitize
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    loopdev=#{loop_dev}
    loopmap=#{loop_map}
    
    umount -lf $loopmap
    kpartx -d $loopdev
    losetup -d $loopdev
  EOH
end

bash "convert image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    qemu-img convert -O vmdk #{target_raw_path} #{bundled_image_path}
  EOH
end

remote_file "/tmp/ovftool.sh" do
  source "VMware-ovftool-2.0.1-260188-lin.x86_64.sh"
end

bash "Install ovftools" do
  cwd "/tmp"
  code <<-EOH
    set -e
    set -x
    mkdir -p /tmp/ovftool
    ovftool.sh --silent /tmp/ovftool AGREE_TO_EULA
  EOH
end

directory "#{bundled_image_path}/ova" do
  action :create
end

node[:rightimage][:ovf][:filename] = `ls -1 #{bundled_image_path}/*.vmdk`
node[:rightimage][:ovf][:image_name] = bundled_image
node[:rightimage][:ovf][:vmdk_size] = `ls -l1 #{bundled_image_path}/*.vmdk | awk '{ print $5; }'`
node[:rightimage][:ovf][:capacity] = "10"
node[:rightimage][:ovf][:ostype] = "linux26other"

template "#{bundled_image_path}/temp.ovf" do
  source "ovf.erb"
end

bash "Create create vmdk and create ovf/ova files" do
  code <<-EOH
  ovftool #{bundled_image_path}/temp.ovf #{bundled_image_path}/ova/temp_name.ovf
  tar -cvf #{bundled_image_path}/ova/temp_name.ova *
 EOH
end
