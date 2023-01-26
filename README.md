# SolarNetwork Development Support

Development support for SolarNetwork:

* using a [Vagrant virtual machine](#vagrant-vm) (VM) on Linux, macOS, or Windows
* natively [on macOS](#macOS)

Folder structure:

* `./bin` - common installation scripts
* `./eclipse` - Eclipse IDE configuration files
* `./vagrant` - Vagrant VM configurations

For full documentation refer to the [Developer Guide][sn-dev-guide].

Once you've installed the development environment either locally or using Vagrant, in Eclipse import
the `SolarNetworkTeamProjectSet.psf` that has been generated in the workspace.

## Vagrant VM

See [vagrant/solarnet-dev/README](vagrant/solarnet-dev/) for details.

## macOS

Requirements:

* [Eclipse](http://www.eclipse.org/downloads/)
* [PostgreSQL](https://www.postgresql.org/download/macosx/)

From the command line go into `bin` directory and run the `./setup.sh` script to:

* checkout the git repositories
* setup the eclipse workspace
* set up the PostgreSQL database

e.g.

```sh
cd bin
./setup.sh ~/solarnet-workspace
```

[sn-dev-guide]: https://github.com/SolarNetwork/solarnetwork/wiki/Developer-Guide#solarnetwork-developer-guide
