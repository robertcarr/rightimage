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

    umount -lf #{loop_map}
    kpartx -d  #{loop_dev}
    losetup -d #{loop_dev}
  EOH
end
