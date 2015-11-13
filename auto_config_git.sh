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
#设置默认配置参数
function set_default_cfg_param(){
	#开发者名字
	g_user_name="searKing"	
	#开发者邮箱
	g_user_email="searKingChan@gmail.com"
}
#自动补全脚本环境搭建
function auto_config_git()
{	
	git config --global user.name "$g_user_name"
	git config --global user.email "$g_user_email"
	#支持稀疏检出
	git config --global core.sparseCheckout true
#	维护一个多人编辑的代码仓库常常意味着试着发现何人在改动什么，这个别名可以输出提交者和提交日期的log信息。
	git config --global alias.logpretty "log --pretty=format:'%C(yellow)%h %C(blue)� %C(red)%d %C(reset)%s %C(green) [%cn]' --decorate --date=short"
#	git config --global alias.logpretty "log --pretty=oneline --abbrev-commit --graph --decorate"
	git config --global alias.loggraph "log --graph --pretty=format:'%C(yellow)%h %C(blue)%d %C(reset)%s %C(white)%an, %ar%C(reset)'"
	git config --global alias.loglast "log -1 HEAD"
	#undo（撤销）。undo会回退到上次提交，暂存区也会回退到那次提交时的状态。你可以进行额外的改动，用新的提交信息来再次进行提交。
	git config --global alias.undo "reset --soft HEAD^"
	#这个别名用来在一天的开启时回顾你昨天做了啥，或是在早晨刷新你的记忆
	git config --global alias.standup "log --since '1 day ago' --oneline --author searKingChan@gmail.com"
	#在提交前瞧瞧你将要提交的都有什么改动是一个好习惯，这可以帮助你发现拼写错误、不小心的提交敏感信息、将代码组织成符合逻辑的组。使用git add暂存你的改动，然后使用git ds查看你将要提交的改动动。
	
	log_info "${LINENO}:$0 is finnished successfully"
}
auto_config_git
