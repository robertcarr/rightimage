bash "create custom initrd" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

  case "#{node.rightimage.virtual_environment}" in
    "ec2" )
      rm -f $target_mnt/boot/initrd*
      chroot $target_mnt mkinitrd --with=mptbase --with=mptscsih --with=mptspi --with=scsi_transport_spi --with=ata_piix \
         --with=ext3 -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
      mv $target_mnt/initrd-#{node[:rightimage][:kernel_id]}  $target_mnt/boot/.
      ;;

     "kvm"|"esxi" )
        # NOTE: Do we really need to build our own ramdisk since we are using vmbuilder?
      ;;
  esac

  EOH
end

