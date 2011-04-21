# 
# Creates a disk image, formats it and rsync's the $source_image to $target_mnt
#

bash "Create disk image and copy filesystem contents" do
  code <<-EOH
    set -e 
    set -x

    DISK_SIZE_GB=#{image_size_gb}
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

    umount -lf #{loop_map} || true
    kpartx -d  #{loop_dev} || true
    losetup -d #{loop_dev} || true

    losetup #{loop_dev} $target_raw_path

    sfdisk #{loop_dev} << EOF
0,1304,L
EOF
   
    kpartx -a #{loop_dev}
    mke2fs -F -j #{loop_map}
    
    # setup uuid for our root partition
    tune2fs -U #{node[:rightimage][:root_mount][:uuid]} #{loop_map}
    
    mkdir $target_mnt
    mount #{loop_map} $target_mnt

    rsync -a $source_image/ $target_mnt/

  EOH
end

