#!/bin/bash

function log_info() {
	echo "[INFO]$@"
}

function log_warn() {
	echo "[WARN]$@"
}

function log_error() {
	echo "[ERROR]$@"
}

#自动补全脚本环境搭建
function auto_support_bash_completion()
{	
	if [ ! -f "github.bash" ]; then
		log_error "${LINENO}:github.bash does NOT exist.EXIT"
	fi 
	sudo cp github.bash /etc/bash_completion.d/	
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}: cp github.bash to /etc/bash_completion.d/ failed : $ret"
		exit 1
	fi 
	source /etc/bash_completion.d/github.bash
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}: source /etc/bash_completion.d/ failed : $ret"
		exit 1
	fi 
	log_info "${LINENO}:$0 is finnished successfully"
}
auto_support_bash_completion
