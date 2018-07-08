# SolarNetwork Development

Development support for SolarNetwork:

* natively on OSX
* using a VM on Linux, OSX or Windows

Folder structure:

* `./bin` - common installation scripts
* `./eclipse` - Eclipse IDE configuration files
* `./vagrant` - Vagrant VM configurations

For full documentation refer to the [Developer Guide]( https://github.com/SolarNetwork/solarnetwork/wiki/Developer-Guide).

Once you've installed the development environment either locally or using vagrant, in Eclipse import the `SolarNetworkTeamProjectSet.psf` that has been generated in the workspace.

## Local installation

### OSX

Requirements:

* [Eclipse](http://www.eclipse.org/downloads/)
* [PostgreSQL](https://www.postgresql.org/download/macosx/)

From the command line go into `bin` directory and run the `./setup.sh` script to:

* checkout the git repositories
* setup the eclipse workspace
* set up the PostgreSQL database

e.g.

	cd ~/solarnet-dev/bin
	./setup.sh ~/solarnet-workspace

## Vagrant VM

This process will work on Windows, Linux or OSX operating systems.

Requirements:

* [Vagrant](https://www.vagrantup.com/downloads.html)
* [Vagrant disksize plugin](https://github.com/sprotheroe/vagrant-disksize) - install via `vagrant plugin install vagrant-disksize`
* [Virtual Box](https://www.virtualbox.org/wiki/Downloads)

From the command line go into the `vagrant/solarnet-dev` directory and run the command: `vagrant up`.

	cd ~/solarnet-dev/vagrant/solarnet-dev
	vagrant up

The default installation uses a minimal fluxbox desktop environment and limited system resources. These can be overridden using by creating a file named `Vagrantfile.local` along side the default `Vagrantfile` which allows the following setting to be overridden:

| Name | Default | Description |
|------|---------|-------------|
|vm_define|solarnet|the unique ID that identifies the VM that is generated|
|vm_name|SolarNet Dev|the user friendly name of the VM|
|basebox_name|ubuntu/artful64|the name/id of the vagrant base box to create the VM from|
|no_of_cpus|1|the number of virtual CPUs|
|memory_size|2048|the memory to assign to the VM|
|postgres_version|9.6|the version of PostgreSQL to install|
|java_version|8|the version of java to install|
|git_branch|develop|the git branch to checkout|
|git_repos|build external common central node|the SolarNetwork repos to checkout|
|desktop_packages|xorg xserver-xorg-legacy fluxbox virtualbox-guest-dkms pgadmin3|can be used to override fluxbox as the desktop|

You can change `git_repos` to include SolarDRAS by adding ` dras` to the default value.

Examples for the desktop_packages variable include:
* virtualbox-guest-dkms virtualbox-guest-additions-iso virtualbox-guest-utils ubuntu-desktop --no-install-recommends
* virtualbox-guest-dkms virtualbox-guest-additions-iso virtualbox-guest-utils xubuntu-desktop --no-install-recommends
* virtualbox-guest-dkms virtualbox-guest-additions-iso lubuntu-desktop

An example `Vagrantfile.local` file looks like this:

```
vm_define = "solarnet-bionic"
vm_name = "SolarNet Bionic"
basebox_name = "ubuntu/bionic64"
postgres_version = 10
```

### OS customization

You can create a `local-root` folder next to the `Vagrantfile` and place any files you'd
like to copy into the VM. They will be copied as the `root` user and folders will be preserved.

For example, you can adjust the screen size of the VM by creating a
`local-root/etc/X11/xorg.conf.d/10-monitor.conf` file as outlined in the [screen resolution
section of the setup guide][screen-res].

 [screen-res]: https://github.com/SolarNetwork/solarnetwork/wiki/Developer-VM#prepare-screen-resolution
