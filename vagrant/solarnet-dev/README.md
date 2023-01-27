# SolarNetwork Development VM

This project contains a Vagrant setup for a complete SolarNetwork development environment using a
Linux virtual machine. This process will work on Windows, Linux, or macOS operating systems.

## Requirements

* [Vagrant](https://www.vagrantup.com/downloads.html)
* [Vagrant disksize plugin](https://github.com/sprotheroe/vagrant-disksize) - install via `vagrant plugin install vagrant-disksize`
* [Virtual Box](https://www.virtualbox.org/wiki/Downloads)

## Quick start

Once you have Vagrant and VirtualBox installed, you can run

```sh
vagrant up
```

from this directory to start up and provision the virtual machine. Log in as
the **solardev** user with password **solardev** once the machine is up.

> :warning: **Note** that you may need to switch to the `tty2` virtual console to log
> in successfully (press <kbd>Alt</kbd>+<kbd>F2</kbd> to switch to `tty2`), and then type `startx`
> to launch the display environment and Eclipse.

For more information, see the [Developer Virtual Machine Guide][vm-guide] on the SolarNetwork wiki.

## Customization

The default installation uses a minimal Fluxbox desktop environment and limited system resources.
These can be overridden using by creating a file named `Vagrantfile.local` along side the default
`Vagrantfile` which allows the following setting to be overridden:

| Name | Default | Description |
|------|---------|-------------|
|vm_define|solarnet|the unique ID that identifies the VM that is generated|
|vm_name|SolarNet Dev|the user friendly name of the VM|
|basebox_name|ubuntu/jammy64|the name/id of the vagrant base box to create the VM from|
|no_of_cpus|1|the number of virtual CPUs|
|memory_size|2048|the memory to assign to the VM|
|postgres_version|12|the version of PostgreSQL to install|
|java_version|8 11 17|space-delimited list of versions of Java to install|
|git_branch|develop|the git branch to checkout|
|git_repos|build external common central node|the SolarNetwork repos to checkout|
|desktop_packages|_see below_|can be used to override fluxbox as the desktop|

The default `desktop_packages` value is:

 * xorg xserver-xorg-legacy xserver-xorg-video-vesa xserver-xorg-video-vmware xfonts-scalable 
   fluxbox eterm xfonts-terminus virtualbox-guest-utils virtualbox-guest-x11 xterm
   --no-install-recommends

Examples for the desktop_packages variable include:

* virtualbox-guest-utils virtualbox-guest-x11 ubuntu-desktop --no-install-recommends
* virtualbox-guest-utils virtualbox-guest-x11 xubuntu-desktop --no-install-recommends
* virtualbox-guest-utils virtualbox-guest-x11 lubuntu-desktop

An example `Vagrantfile.local` file looks like this:

```
no_of_cpus = 4
memory_size = 6114
```

### OS customization

You can create a `local-root` folder next to the `Vagrantfile` and place any files you'd
like to copy into the VM. They will be copied as the `root` user and folders will be preserved.

For example, you can adjust the screen size of the VM by creating a
`local-root/etc/X11/xorg.conf.d/10-monitor.conf` file as outlined in the [screen resolution
section of the setup guide][screen-res].

```
local-root
└── etc
    └── X11
        └── xorg.conf.d
            └── 10-monitor.conf
```

## Non GUI environment

You can provision a headless VM without any GUI, which can be useful as a database host for an
existing Eclipse environment. To do this, create a `Vagrantfile.local` file with the following
content:

```ruby
# Disable installing X, Eclipse, etc.
vm_gui=false
```


[screen-res]: https://github.com/SolarNetwork/solarnetwork/wiki/Developer-VM#prepare-screen-resolution
[vm-guide]: https://github.com/SolarNetwork/solarnetwork/wiki/Developer-VM
