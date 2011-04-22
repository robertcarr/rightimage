#
# additional CloudStack specific configuration changes here
#
bash "configure for cloudstack" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{node.rightimage.target_mnt}

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

