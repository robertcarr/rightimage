bash "unmount proc & dev" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{node.rightimage.target_mnt}
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
    target_mnt=#{node.rightimage.target_mnt}

    umount -lf #{node.rightimage.loop_map}
    kpartx -d  #{node.rightimage.loop_dev}
    losetup -d #{node.rightimage.loop_dev}
  EOH
end
