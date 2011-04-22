# cloud_add_vmops_esx.rb
#
# Converts a previously generated and mounted disk image and converts it to a stream optimized vmdk in an OVA package
# 
# 1. Create loopback filesystem for new disk image.
# 2. rsync base OS from $source_image -> $target
# 3. Update grub, fstab and modify kernels & modules if needed.
# 4. Install vmware tools
# 5. Add any special CloudStack tweeks
# 6. Convert raw image to flat vmdk
# 7. Covert to archived OVF format using ovftool
#

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to esxi!"  if node[:rightimage][:virtual_environment] != "esxi"

package "qemu"

include_recipe "rightimage::image_builder_config.rb"
include_recipe "rightimage::helper_create_image_and_rsync"
include_recipe "rightimage::helper_proc_grub_fstab"
include_recipe "rightimage::helper_customer_initrd"
include_recipe "rightimage::helper_install_vmware_tools"
include_recipe "rightimage::helper_helper_cloudstack_standard"
include_recipe "rightimage::helper_unmount_proc_and_filesystem"

bash "convert raw image to VMDK flat file" do 
  cwd File.dirname node.rightimage.target_raw_path
  code <<-EOH
    set -e
    set -x
    qemu-img convert -O vmdk #{node.rightimage.target_raw_path} #{node.rightimage.bundled_image_path}
  EOH
end

remote_file "/tmp/ovftool.sh" do
  source "VMware-ovftool-2.0.1-260188-lin.x86_64.sh"
  mode "0744"
end

bash "Install ovftools" do
  cwd "/tmp"
  code <<-EOH
    set -e
    set -x
    mkdir -p /tmp/ovftool
    ./ovftool.sh --silent /tmp/ovftool AGREE_TO_EULA 
  EOH
end

directory "#{node.rightimage.bundled_path}/ova" do
  action :create
end

ovf_filename = `ls -1 #{node.rightimage.bundled_path}/*.vmdk`
ovf_image_name = bundled_image
ovf_vmdk_size = `ls -l1 #{node.rightimage.bundled_path}/*.vmdk | awk '{ print $5; }'`
ovf_capacity = "10"
ovf_ostype = "linux26other"

template "#{node.rightimage.bundled_path}/temp.ovf" do
  source "ovf.erb"
  variables({
    :ovf_filename => ovf_filename,
    :ovf_image_name => ovf_image_name,
    :ovf_vmdk_size => ovf_vmdk_size,
    :ovf_capacity => ovf_capacity,
    :ovf_ostype => ovf_ostype
  })
end

bash "Create create vmdk and create ovf/ova files" do
  cwd "/tmp/ovftool"

  code <<-EOH
  ./ovftool #{node.rightimage.bundled_path}/temp.ovf #{bundled_path}/ova/#{bundled_image}.ovf  > /dev/null 2>&1
  tar -cf #{node.rightimage.bundled_path}/ova/{bundled_image}.ova #{bundled_path}/ova/*
 EOH
end
