execute "umount -lf  #{node[:rightimage][:build_dir]}/proc || true"
execute "umount -lf  #{node[:rightimage][:mount_dir]}/proc || true"

directory node[:rightimage][:build_dir] do 
  action :delete
  recursive true
end

directory node[:rightimage][:mount_dir] do 
  action :delete
  recursive true
end

ruby_block "delete image id list" do
  block do
    # add to global id store for use by other recipes
    id_list = RightImage::IdList.new(Chef::Log)
    id_list.clear
  end
end

bash "Remove stale devices" do
  code <<-EOH
    set +e
#    [ -e "/dev/mapper/loop0p1" ] && kpartx -d /dev/loop0
#    losetup -a | grep loop0
#    [ "$?" == "0" ] && losetup -d /dev/loop0
  EOH
end
