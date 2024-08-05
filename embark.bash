#!/bin/bash 
# ******************************************************************************
#
# @file			embark.bash 
#
# @brief        Script to launch qemu virtual machines with varied profiles
#
# @copyright    Copyright (C) 2024 Barrett Edwards. All rights reserved.
#
# @date         May 2024
# @author       Barrett Edwards <thequakemech@gmail.com>
#
# Usage 
#  To create a new ./.embark configuration file from a template:
#    embark config 
# 
#  To clone an existing qcow2 image for this virtual machine:
#    embark clone <path/to/base.qcow2>
#
#  To create a new virtual machine iso image: 
#    embark create <size>
#
#  To list all profiles in the .embark config file:
#    embark list 
#
#  To install an operating system on the vm from an iso image:
#    embark install <profile> <iso>
#
#  To start the vm with a:
#    embark start <profile>
#
#  To ssh into the virtual machine:
#    embark ssh 
#
#  To get the running status of the virtual machine: 
#    embark status 
# 
#  To stop the virtual machine (ssh into and run sudo shutdown -h now): 
#    embark stop  
#
#  To kill the virtual machine 
#    embark kill
#
# Host configuration 
# 1. Enable qemu guest access to existing host network bridges 
#   sudo mkdir /etc/qemu 
#   echo "allow br16" | sudo tee -a /etc/qemu/bridge.conf
#   sudo chmod 644 /etc/qemu/bridge.conf 
#  
#   If using a custom build of qemu, the same bridge.conf file needs to be added to the custom build install path
#   mkdir -p /opt/<custom qemu>/etc/qemu
#   echo "allow br16" | sudo tee -a /opt/<custom qemu>/etc/qemu/bridge.conf
#   sudo chmod 644 /opt/<custom qemu>/etc/qemu/bridge.conf 
#
# Guest customizations
# 1. echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$(whoami)
# 2. sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT/s/\"$/ console=tty0 console=ttyS0,115200\"/" /etc/default/grub ; sudo update-grub 
#
# ******************************************************************************

# Application variables ########################################################
APP=embark

# OS type 
# This variable can be: Linux or Darwain 
OS=`uname`

# Declare an array to hold the profiles
# This array uses a non-numeric key and requires a bash v4+ environment
declare -A CMDS

# Location of qemu binaries
QEMU_X86=qemu-system-x86_64
QEMU_ARM=qemu-system-aarch64

# Assume VM name is current directory name 
DIR=`pwd`
NAME=`basename ${DIR}`
FILEPATH=./${NAME}.qcow2

# Networking settings 
MAC=52:25:08:BE:00:01
BR=br16
IP=
PORT=2220
VNC=0

# VM Parameter Defaults 
BIOS=QEMU_EFI.fd
CORES=2
MEM=4G
MEMSLOTS=4
MAXMEM=16G
CXLMEM=256M
IG=4K
MEMFILEDIR=.

# If user did not specify a config filepath, 
# set filepath to default config filename 
if [ -z ${CONFIG} ] ; then 
	CONFIG=.embark
fi

# Source the local config file if it exists
if [[ -f ${CONFIG} ]] ; then 
	source ${CONFIG}
fi 

# Functions ####################################################################

# Print all the profiles in the config file
function print_all_entries() {
	KEYS=`echo ${!CMDS[@]} | sed "s/ / \\n/g" | sort`
	for key in ${KEYS} ; do 
		echo "${key}: ${CMDS[$key]}"
	done 
}

# Print a single profile in the config file
# @param 1: name of the profile 
function print_entry() {
	KEYS=`echo ${!CMDS[@]} | sed "s/ / \\n/g" | sort`
	for key in ${KEYS} ; do 
		if [[ "$key" = "$1" ]] ; then 
			echo ${CMDS[$key]}
		fi 
	done 
}

# Print the help menu 
function print_help() {
	echo -e "\
$APP command line tool to launch qemu images \n\
\n\
$APP <action> <options> \n\
\n\
Actions: \n\
\n\
  help                         Print help menu\n\
  clone <existing-file-path>   Clone existing image \n\
  config                       Create ${CONFIG} config file from template \n\
  create <size>                Create new vm qcow file \n\
  install <profile> <isopath>  Start domain with cdrom iso \n\
  kill                         Kill running qemu domain \n\
  list                         List profiles \n\
  pid                          Show running qemu domain PID \n\
  run <cmd>                    Run <cmd> in domain \n\
  set <variable> <value>       Set value in local config file \n\
  show <profile>               Print a profile by name \n\
  ssh                          ssh into the image \n\
  start <profile>              Launch profile \n\
  status                       Show running status \n\
  stop                         Shutdown (gracefully) \n\
"
}

# Print the profile names in the config file
function print_list() {
	KEYS=`echo ${!CMDS[@]} | sed "s/ / \\n/g" | sort`
	for key in ${KEYS} ; do 
		echo "${key}"	
	done 
}

# Find and print the PID of the running domain 
function print_pid() {
	if [[ ${OS} = "Linux" ]] ; then 
		PID=`ps -aux | grep qemu-system | grep "name ${NAME}" | sed "s/  */ /g" | cut -f2 -d " "`
	elif [[ ${OS} = "Darwin" ]] ; then 
		PID=`ps -A | grep qemu-system | grep "name ${NAME}" | sed "s/  */ /g" | cut -f1 -d " "`
	fi
	echo "${PID}"	
}

# @param 1: Variable Name
# @param 2: Variable Value 
function set_variable() {
	VAR_NAME=$1
	VAR_VALUE=$2 

	# If NAME is empty, display all variables 
	if [[ -z $VAR_NAME ]] ; then 
		echo "QEMU_X86=$QEMU_X86"
		echo "QEMU_ARM=$QEMU_ARM"
		echo "DIR=$DIR"
		echo "NAME=$NAME"
		echo "FILEPATH=$FILEPATH"
		echo "MAC=$MAC"
		echo "BR=$BR"
		echo "IP=$IP"
		echo "PORT=$PORT"
		echo "VNC=$VNC"
		echo "BIOS=$BIOS"
		echo "CORES=$CORES"
		echo "MEM=$MEM"
		echo "MEMSLOTS=$MEMSLOTS"
		echo "MAXMEM=$MAXMEM"
		echo "CXLMEM=$CXLMEM"
		echo "IG=$IG"
		echo "MEMFILEDIR=$MEMFILEDIR"
		exit 
	fi 

	# Replace slashes / in value 
	VAR_VALUE=`echo $VAR_VALUE | sed "s_/_\\\\\\/_g"`

	# Search and replace the variable with the new value
	sed -i "/^${VAR_NAME}=/s/^.*$/${VAR_NAME}=${VAR_VALUE}/" ${CONFIG}
	sed -i "/^#${VAR_NAME}=/s/^.*$/${VAR_NAME}=${VAR_VALUE}/" ${CONFIG}
}

# Create a new qcow2 disk image file 
# @param 1: Size (e.g. 12G) 
if [[ "$1" = "create" ]] ; then 
	shift 

	SIZE=$1
	if [[ "$SIZE" = "" ]] ; then 
		echo "size not found"
		exit
	fi 

	if [[ -f $FILEPATH ]] ; then 
		echo "Filepath already exists"
		exit
	fi 

	# Create qcow image 
	qemu-img create -f qcow2 ${FILEPATH} ${SIZE}

	exit
fi 

# Create a new config file from template 
if [[ "$1" = "config" ]] ; then 
	cat << EOF > ${CONFIG}
#!/bin/bash

#QEMU_X86=
#QEMU_ARM=
#DIR=`pwd`
#NAME=`basename ${DIR}`
#FILEPATH=./\${NAME}.qcow2
#MAC=52:54:25:08:00:02
#BR=br16
#IP=
#PORT=2220
#VNC=0
#BIOS=QEMU_EFI.fd
#CORES=2
#MEM=4G
#MEMSLOTS=4
#MAXMEM=16G
#CXLMEM=256M
#IG=4K
#MEMFILEDIR=

EOF

	if [[ ${OS} = "Linux" ]] ; then 
		cat << EOF >> ${CONFIG}
################################################################################
# Basic Profiles 

# Start VM as a Daemon (i.e. no console or gui)
CMDS["vnc"]="\\
\${QEMU_X86} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-cpu host \\
-machine type=q35,accel=kvm \\
-smp \${CORES} \\
-m \${MEM} \\
-device virtio-net-pci,netdev=user0,mac=\${MAC} -netdev bridge,id=user0,br=\${BR} \\
-daemonize \\
-display vnc=:\${VNC} \\
"

# Start VM with local console output
CMDS["console"]="\\
\${QEMU_X86} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-cpu host \\
-machine type=q35,accel=kvm \\
-smp \${CORES} \\
-m \${MEM} \\
-net nic -net user,hostfwd=tcp::\${PORT}-:22 \\
-nographic \\
"

# Start VM with qemu viewer gui
CMDS["gui"]="\\
\${QEMU_X86} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-cpu host \\
-machine type=q35,accel=kvm \\
-smp \${CORES} \\
-m \${MEM} \\
-device virtio-net-pci,netdev=user0,mac=\${MAC} -netdev bridge,id=user0,br=\${BR} \\
-daemonize \\
-display gtk,gl=on \\
"

CMDS["net"]="\\
\${QEMU_X86} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-cpu host \\
-machine type=q35,accel=kvm \\
-smp \${CORES} \\
-m \${MEM},slots=\${MEMSLOTS},maxmem=\${MAXMEM} \\
-device virtio-net-pci,netdev=user0,mac=\${MAC} -netdev bridge,id=user0,br=\${BR} \\
-daemonize \\
-display gtk,gl=on \\
"

EOF

	elif [[ ${OS} = "Darwin" ]] ; then 

		cat << EOF >> ${CONFIG}
CMDS["x86-console"]="\\
\${QEMU_X86} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-machine type=q35 \\
-smp \${CORES} \\
-m \${MEM} \\
-net nic -net user,hostfwd=tcp::\${PORT}-:22 \\
-nographic \\
"

CMDS["x86-gui"]="\\
\${QEMU_X86} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-machine type=q35 \\
-smp \${CORES} \\
-m \${MEM} \\
-net nic -net user,hostfwd=tcp::\${PORT}-:22 \\
-display cocoa \\
"

CMDS["arm-console"]="\\
\${QEMU_ARM} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-machine type=virt,accel=hvf \\
-cpu host \\
-smp \${CORES} \\
-m \${MEM} \\
-net nic -net user,hostfwd=tcp::\${PORT}-:22 \\
-nographic \\
-bios \${BIOS} \\
"

CMDS["arm-gui"]="\\
\${QEMU_ARM} \\
-name \${NAME} \\
-drive file=\${FILEPATH},format=qcow2,index=0,media=disk,id=hd \\
-machine type=virt,accel=hvf \\
-cpu host \\
-smp \${CORES} \\
-m \${MEM} \\
-net nic -net user,hostfwd=tcp::\${PORT}-:22 \\
-device virtio-gpu-pci \\
-display cocoa,show-cursor=on \\
-device qemu-xhci \\
-device usb-kbd \\
-device usb-mouse \\
-device usb-tablet \\
-bios \${BIOS} \\
"
EOF
	fi
	exit
fi

# Clone existing qemu qcow2 image 
# @param 1: Filepath to existing qcow2 disk image 
if [[ "$1" = "clone" ]] ; then 
	shift
	SRC=$1
	qemu-img create -b ${SRC} -F qcow2 -f qcow2 ${FILEPATH}
	exit
fi

# Print help output
if [[ "$1" = "help" || "$1" == "" ]] ; then 
	print_help
	exit
fi

# Start domain with CDROM 
# @param 1: Profile name 
# @param 2: Path to iso image
if [[ "$1" = "install" ]] ; then 
	shift

	# Check if the domain is already running
	PID=$(print_pid)
	if [[ -n "${PID}" && "$PID" -eq "$PID" ]] ; then 
		echo "Domain already running. PID: ${PID}"
		exit
	fi

	# Execute profile if a matching profile name was found 
	KEYS=`echo ${!CMDS[@]} | sed "s/ / \\n/g" | sort`
	for KEY in $KEYS ; do 
		if [[ "$1" = "$KEY" ]] ; then 
			CMD="${CMDS[$KEY]} -no-reboot -boot order=d -cdrom $2"
			eval $CMD
			exit
		fi 
	done 
	
	# If no profile was found issue an error message and exit
	echo "Error: No matching profile found"
	exit -1
fi 

# Kill running domain 
if [[ "$1" = "kill" ]] ; then 
	PID=$(print_pid)
	
	if [[ "${PID}" = "" ]] ; then 
		echo "Not running"
		exit
	fi

	if [[ -n "${PID}" && "$PID" -eq "$PID" ]] ; then 
		kill ${PID}
	else 
		echo "Invalid PID: ${PID}"
	fi 
	exit	
fi

# Print list of profiles
if [[ "$1" = "list" ]] ; then 
	print_list
	exit	
fi

# Show PID of running domain
if [[ "$1" = "pid" ]] ; then 
	PID=$(print_pid)
	if [[ -n "${PID}" && "${PID}" -eq "${PID}" ]] 2>/dev/null ; then 
		echo "${PID}"
	fi 
	exit	
fi

# SSH into a domain and run a command
if [[ "$1" = "run" ]] ; then 
	shift 
	if [[ -n $IP ]] ; then 
		ssh ${IP} $@
	else 
		ssh -p ${PORT} localhost $@
	fi
	exit	
fi

# set local config file variable 
if [[ "$1" = "set" ]] ; then 
	shift 
	set_variable $@
	exit	
fi

# Print profile
# @param 1: Name of profile
if [[ "$1" = "show" ]] ; then 
	shift 
	if [[ -n "$1" ]] ; then 
		print_entry $@
	else 
		print_all_entries
	fi 
	exit	
fi

# SSH into the domain
if [[ "$1" = "ssh" ]] ; then 
	if [[ -n $IP ]] ; then 
		ssh ${IP} 
	else 
		ssh -p ${PORT} localhost
	fi
	exit	
fi

# Start domain 
# @param 1: Profile name 
if [[ "$1" = "start" ]] ; then 
	shift

	# Check if the domain is already running
	PID=$(print_pid)
	if [[ -n "${PID}" && "$PID" -eq "$PID" ]] ; then 
		echo "Domain already running. PID: ${PID}"
		exit
	fi

	# Execute profile if a matching profile name was found 
	KEYS=`echo ${!CMDS[@]} | sed "s/ / \\n/g" | sort`
	for KEY in $KEYS ; do 
		if [[ "$1" = "$KEY" ]] ; then 
			CMD=${CMDS[$KEY]}
			eval $CMD
			exit
		fi 
	done 
	
	# If no profile was found issue an error message and exit
	echo "Error: No matching profile found"
	exit -1
fi 

# Show running status of domain 
if [[ "$1" = "status" || "$1" = "st" ]] ; then 
	PID=$(print_pid)
	if [[ "$PID" != "" ]] ; then 
		echo "Running. PID: ${PID}"
	else 
		echo "Not Running"
	fi 
	exit	
fi

# SSH into the domain and shutdown 
if [[ "$1" = "stop" ]] ; then 
	if [[ -n $IP ]] ; then 
		ssh ${IP} "sudo shutdown -h now"
	else 
		ssh -p ${PORT} localhost "sudo shutdown -h now"
	fi
	exit
fi

