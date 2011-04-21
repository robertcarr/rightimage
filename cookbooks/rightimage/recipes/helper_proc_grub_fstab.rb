#
# Handles Proc, Fstab, Grub Configurations
#
 

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
                                                                                                                                                               121,1         26%
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

