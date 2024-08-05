# Overview

Embark is a CLI tool to launch and manage the runtime of QEMU based 
virtual machines. It allows the user to specify multiple profiles in a .embark
config file and then launch the qemu image using that profile name. This is 
convenient for users who need to frequently modify the system hardware 
specifications or devices. 

# Dependencies 

Embark requires the use of arrays in bash. Arrays are supported in versions of 
bash after 4.0. On some OSX systems, the included bash binary is too old (3.x) 
to support bash arrays so the user must install a newer version of bash. This 
can be accomplished using homebrew. 

To install homebrew on OSX: 

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install bash:

```bash
brew install bash 
```

# Installation 

Install the embark bash script to your /usr/local/bin/ directory using: 

```bash
make install
```

# Uninstallation 

Remove the embark bash script from /usr/local/bin/ directory using: 

```bash
make uninstall
```

# Usage

Create a folder to store the virtual machine and related configuration files: 

```bash
mkdir ~/testvm
cd testvm 
```

Create a new .embark configuration file from default template:

```bash
embark config 
```

	All the following commands must be run in the directory where the .embark 
	config file is located. 

Create a new virtual machine iso image. This example creates a 12G sized qcow2 
image

```bash
embark create 12G 
```

Or you can clone an existing qcow2 image. The Embark script will use the 
current directory name for the qcow2 image file 

```bash
embark clone <path/to/base.qcow2>
```

At this point the user can customize the .embark config file in the current 
directory with additional system profiles. 

To list all profiles in the .embark config file:

```bash
embark list 
```

To install an operating system on the vm from an iso image use:

```bash
embark install <profile> </path/to/iso>
```

Once the operating system has been installed and then shutdown, the guest 
can be started with the following command:

```bash
embark start <profile>
```

The .embark default profiles define a forwarded ssh port and VNC port to allow 
the user to login to the virtual machine. The .embark config file knows the 
forwarded port so it can be used to ssh into the guest machine with the 
following command: 

```bash
embark ssh 
```

To get the status of the running guest, type: 

```bash
embark status 
```

To stop the virtual machine (ssh into and run sudo shutdown -h now): 
 
```bash
embark stop  
```

To kill the virtual machine if unresponsive to ssh:

```bash
embark kill
```

