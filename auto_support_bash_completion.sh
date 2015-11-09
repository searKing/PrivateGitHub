#!/bin/bash

function info() {
	echo "[INFO]${LINENO}:$@"
}

function warn() {
	echo "[WARN]${LINENO}:$@"
}

function error() {
	echo "[ERROR]${LINENO}:$@"
}

#自动补全脚本环境搭建
function auto_support_bash_completion()
{	
	if [ ! -f "github.bash" ]; then
		error "github.bash does NOT exist.EXIT"
	fi 
	sudo cp github.bash /etc/bash_completion.d/	
	ret=$?
	if [ $ret -ne 0 ]; then
		error " cp github.bash to /etc/bash_completion.d/ failed : $ret"
		exit 1
	fi 
	source /etc/bash_completion.d/github.bash
	ret=$?
	if [ $ret -ne 0 ]; then
		error " source /etc/bash_completion.d/ failed : $ret"
		exit 1
	fi 
	info "$0 is finnished successfully"
}
auto_support_bash_completion
