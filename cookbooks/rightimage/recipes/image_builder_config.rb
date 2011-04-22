# An attempt to centralized all the image build settings used
# across all the various add_cloud_* recipes
#
# Eventually this could be moved in the main attribute file or somewhere similiar
#

node[:rightimage][:loop_name] = "loop0"
node[:rightimage][:loop_dev] = "/dev/#{node.rightimage.loop_name}"
node[:rightimage][:loop_map] = "/dev/mapper/#{loop_name}p1"
node[:rightimage][:bundled_path] = "/mnt"
#node[:rightimage][:bundled_image] = "#{image_name}.qcow2"
node[:rightimage][:bundled_image_path] = "#{node.rightimage.bundled_path}/#{node.rightimage.bundled_image}"
node[:rightimage][:target_raw] = "target.raw"
node[:rightimage][:target_raw_path] = "/mnt/#{node.rightimage.target_raw}"
node[:rightimage][:target_mnt] = "/mnt/target"
node[:rightimage][:source_image] = node.rightimage.mount_dir

case node.rightimage.virtual_environment
  when "esxi"
    node[:rightimage][:bundled_image] = "RightImage_#{node.rightimage.platform}_#{node.rightimage_release}_#{node.rightimage.rightlink_version}_dev.vmdk"

  when "kvm"
    node[:rightimage][:bundled_image] = "#{image_name}.qcow2"
end

