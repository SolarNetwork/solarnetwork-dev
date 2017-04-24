# SolarNetwork Development VM

This project contains a Vagrant setup for a complete SolarNetwork development
environment using a Linux virtual machine. Once you have Vagrant and VirtualBox
installed, you can run

```sh
vagrant up
```

from this directory to start up and provision the virtual machine. Log in as
the **solardev** user with password **solardev** once the machine is up.

**Note** that you may need to switch to the `tty2` virtual console to log
in successfully (press <kbd>Alt</kbd>+<kbd>F2</kbd> to switch to `tty2`),
and then type

```sh
startx
```

to launch the display environment and Eclipse.

For more information, see the [Developer Virtual Machine Guide][vm-guide] on
the SolarNetwork wiki.

## Non GUI environment

You can provision a headless VM without any GUI, which can be useful as a
database host for an existing Eclipse environment. To do this, create a
`Vagrantfile.local` file with the following content:

```ruby
# Disable installing X, Eclipse, etc.
vm_gui=false
```

  [vm-guide]: https://github.com/SolarNetwork/solarnetwork/wiki/Developer-VM
