# SolarNode Development VM - Debian 9 i386

This project contains a Vagrant setup for a SolarNode development environment using a Linux virtual
machine. Once you have Vagrant and VirtualBox installed, you can run

```sh
$ vagrant up
```

## Setup arguments

The setup script in `bin/setup-solarnode-debian.sh` accepts some arguments that you may wish to
provide. Do so by creating a `Vagrantfile.local` with a `setup_args` setting. For example:

```ruby
setup_args="-p http://snf-debian-repo.s3-website-us-west-2.amazonaws.com"
```

## Vagrant box setup

You can customize the Vagrant base box used for the VM by creating a `Vagrantfile.local` file with
`vm_box` and `vm_box_version` settings. For example:

```ruby
vm_box="bento/debian-9.6-i386"
vm_box_version=">= 201812.27.0"
```

## Non GUI environment

By default no VM GUI is shown. If you'd like a GUI, create a `Vagrantfile.local` file with the
following content:

```ruby
vm_gui=true
```
