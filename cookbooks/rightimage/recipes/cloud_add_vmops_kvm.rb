class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to kvm!"  if node[:rightimage][:virtual_environment] != "kvm"

source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

bundled_image = "#{image_name}.qcow2"
bundled_image_path = "/mnt/#{bundled_image}"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"

include_recipe rightimage::helper_create_image_and_rsync
include_recipe rightimage::helper_proc_grub_fstab


bash "install kvm kernel" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}


  case "#{node.rightimage.platform}" in 
    "centos" )
      # The following should be needed when using ubuntu vmbuilder
      yum -c /tmp/yum.conf --installroot=$target_mnt -y install kmod-kvm
      rm -f $target_mnt/boot/initrd*
      chroot $target_mnt mkinitrd --with=ata_piix --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
      mv $target_mnt/initrd-#{node[:rightimage][:kernel_id]}  $target_mnt/boot/.
      ;;
    "ubuntu" )
      # Anything need to be done?
      ;;
  esac
      
  EOH
end

include_recipe rightimage::helper_helper_cloudstack_standard
include_recipe rightimage::helper_unmount_proc_and_filesystem


bash "backup raw image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    cp -v $raw_image $raw_image.bak 
  EOH
end

bash "upload image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    qemu-img convert -O qcow2 #{target_raw_path} #{bundled_image_path}

    # upload image
    # export AWS_ACCESS_KEY_ID=#{node.rightimage.aws_access_key_id_for_upload}
    # export AWS_SECRET_ACCESS_KEY=#{node.rightimage.aws_secret_access_key_for_upload}
    # export AWS_CALLING_FORMAT=SUBDOMAIN 
    # /usr/local/bin/s3cmd -v put #{node.rightimage.image_upload_bucket}:#{image_name}.vhd.bz2 /mnt/#{image_name}.vhd.bz2 x-amz-acl:public-read --progress
    # /usr/bin/s3cmd -P put #{bundled_image_path} s3://rightscale-cloudstack-dev/#{bundled_image}
  EOH
end


