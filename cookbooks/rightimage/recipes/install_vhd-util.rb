case node[:rightimage][:platform]
  when "centos" 
    vhd_util_deps=%w{mercurial git ncurses-devel dev86 iasl SDL python-devel libgcrypt-devel uuid-devel openssl-devel} 
  when "ubuntu"
    vhd_util_deps=%w{mercurial libncurses5-dev bin86 bcc iasl libsdl1.2debian-all python-dev libgcrypt11-dev uuid-dev libssl-dev}
  else
    raise "ERROR: plaform #{node[:rightimage][:platform]} not supported. Please feel free to add support ;) "
end

vhd_util_deps.each do |p| package p end

remote_file "/tmp/vhd-util-patch" do 
  source "vhd-util-patch"
end

bash "install_vhd-util" do 
  not_if "which vhd-util"
  code <<-EOF
#!/bin/bash -ex
    set -e
    set -x

    rm -rf /mnt/vhd && mkdir /mnt/vhd && cd /mnt/vhd
    hg clone http://xenbits.xensource.com/xen-4.0-testing.hg
    cd xen-4.0-testing.hg/tools
    patch -p0 < /tmp/vhd-util-patch
    cd ..
    make install-tools
    cd tools/blktap2/
    make 
    make install
  EOF
end
