class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

#  - bundle and upload
bash "bundle_upload_ebs" do 
    only_if { node[:rightimage][:cloud] == "ec2" }
    code <<-EOH
#!/bin/bash -ex
    set -e
    set -x

    . /etc/profile
    
    export JAVA_HOME=/usr
    export PATH=$PATH:/usr/local/bin:/home/ec2/bin
    export EC2_HOME=/home/ec2

    umount "#{node[:rightimage][:mount_dir]}/proc" || true
    
    kernel_opt=""
    if [ -n "#{node[:rightimage][:kernel_id]}" ]; then
      kernel_opt="--kernel #{node[:rightimage][:kernel_id]}"
    fi 

    ramdisk_opt=""
    if [ -n "#{node[:rightimage][:ramdisk_id]}" ]; then
      ramdisk_opt="--ramdisk #{node[:rightimage][:ramdisk_id]}"
    fi

    #create keyfiles for bundle
    echo "#{node[:rightimage][:aws_509_key]}" > /tmp/AWS_X509_KEY.pem
    echo "#{node[:rightimage][:aws_509_cert]}" > /tmp/AWS_X509_CERT.pem


    echo "Doing EBS"

# switch to a random directory for the build
    random_dir="/mnt/$RANDOM"
    mkdir $random_dir
    cd $random_dir
    ebs_mount=${random_dir}/ebs_mount
    mkdir -p $ebs_mount
# This /mnt/image is where the image creator creates the image
    image_mount=/mnt/image

## calculate ec2 region
    length=`echo -n #{node[:ec2][:placement_availability_zone]} | wc -c`
    length_minus_one=$((length -1))
    region=`echo  #{node[:ec2][:placement_availability_zone]} | cut -c -$length_minus_one`

## create EBS volume
    vol_out=`ec2-create-volume \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --size 10 \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --availability-zone #{node[:ec2][:placement_availability_zone]} `

# parse out volume id
    vol_id=`echo -n $vol_out | awk '{ print $2 }'`

## attach an EBS volume here
    ec2-attach-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --device /dev/sdj \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --instance #{node[:ec2][:instance_id]} 

    sleep 10

## loop and wait for volume to become available
    while [ 1 ]; do 
      vol_status=`ec2-describe-volumes $vol_id  --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --url #{node[:rightimage][:ec2_endpoint]}`
      if `echo $vol_status | grep -q "attached"` ; then break; fi
      sleep 1
    done 

    sleep 10
## format and mount volume
    mkfs.ext3 -F /dev/sdj
    mount /dev/sdj $ebs_mount

## mount EBS volume, rsync, and unmount ebs volume
    rsync -a $image_mount/ $ebs_mount/
    umount $ebs_mount

## snapshot the ebs volume and save the snapshot id
    snap_out=`ec2-create-snapshot $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --description "This snapshot will be used to create #{image_name}"`
      
# parse out snapshot id
    snap_id=`echo -n $snap_out | awk '{ print $2 }'`

    sleep 10

## loop and wait for snapshot to become available
    while [ 1 ]; do 
      snap_status=`ec2-describe-snapshots $snap_id --private-key /tmp/AWS_X509_KEY.pem --cert /tmp/AWS_X509_CERT.pem --url #{node[:rightimage][:ec2_endpoint]} `
      if `echo $snap_status | grep -q "completed"` ; then break; fi
      sleep 5
    done 

    image_out_ebs=`ec2-register \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --region $region \
      --url #{node[:rightimage][:ec2_endpoint]}\
      --architecture #{node[:rightimage][:arch]} \
      -b "sdb=ephemeral0" \
      --description "#{image_name}_EBS" \
      --name "#{image_name}_EBS" \
      --snapshot $snap_id \
      $kernel_opt \
      $ramdisk_opt \
      --root-device-name /dev/sda1 `

## parse out image id
    image_id_ebs=`echo -n $image_out_ebs | awk '{ print $2 }'`
    echo "$image_id_ebs" > /var/tmp/ebs_image_id

## detach volume
    ec2-detach-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --region $region \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --force

    sleep 10

## delete volume
    ec2-delete-volume $vol_id \
      --private-key /tmp/AWS_X509_KEY.pem \
      --cert /tmp/AWS_X509_CERT.pem \
      --url #{node[:rightimage][:ec2_endpoint]} \
      --region $region 
   
    #remove keys
    rm -f /tmp/AWS_X509_KEY.pem
    rm -f  /tmp/AWS_X509_CERT.pem
    
    EOH
end 

