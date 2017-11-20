# solarnetwork-dev
Development support for SolarNetwork:
* natively on OSX
* using a VM on Linux, OSX or Windows

Folder structure:
- ./bin - common installation scripts
- ./eclipse - eclipse configuration files
- ./vagrant - Vagrant VM configurations

For full documentation refer to the [Developer Guide]( https://github.com/SolarNetwork/solarnetwork/wiki/Developer-Guide).
___

Once you've installed the development environment either locally or using vagrant, in Eclipse import the `SolarNetworkTeamProjectSet.psf` that has been generated in the workspace.

___

## Local installation:

### OSX

Requirements:
* [Eclipse](http://www.eclipse.org/downloads/)
* [PostgreSQL](https://www.postgresql.org/download/macosx/)

From the command line go into `bin` directory and run the `./setup.sh` script to:
* checkout the git repositories
* setup the eclipse workspace
* set up the PostgreSQL database

e.g.
`cd ~/solarnet-dev/bin`
`./setup.sh ~/solarnet-workspace`

___

## Vagrant: Ubuntu VirtualBox VM
This process will work on Windows, Linux or OSX operating systems

Requirements:
* [Vagrant](https://www.vagrantup.com/downloads.html)
* [Virtual Box](https://www.virtualbox.org/wiki/Downloads)

From the command line go into the `vagrant/solarnet-dev` directory and run the command: `vagrant up`.


e.g.
`cd ~/solarnet-dev/vagrant/solarnet-dev`
`vagrant up`

The default installation uses a minimal fluxbox desktop environment and limited system resources. These can be overridden using by creating a file named `Vagrantfile.local` along side the default `Vagrantfile` which allows the following setting to be overridden:

| Name | Default | Description |
|------|---------|-------------|
|vm_define|solarnet|the unique ID that identifies the VM that is generated|
|vm_name|SolarNet Dev|the user friendly name of the VM|
|basebox_name|ubuntu/zesty64|the name/id of the vagrant base box to create the VM from|
|no_of_cpus|1|the number of virtual CPUs|
|memory_size|2048|the memory to assign to the VM|
|postgres_version|9.6|the version of PostgreSQL to install|
|java_version|8|the version of java to install|
|desktop_packages|xorg xserver-xorg-legacy fluxbox virtualbox-guest-dkms pgadmin3|can be used to override fluxbox as the desktop|

Examples for the desktop_packages variable include:
* virtualbox-guest-dkms virtualbox-guest-additions-iso virtualbox-guest-utils ubuntu-desktop --no-install-recommends
* virtualbox-guest-dkms virtualbox-guest-additions-iso virtualbox-guest-utils xubuntu-desktop --no-install-recommends
* virtualbox-guest-dkms virtualbox-guest-additions-iso lubuntu-desktop
