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

#使用方法说明
function usage() {
	cat<<USAGEEOF
	NAME
		$g_shell_name - 自动配置git环境
	SYNOPSIS
		source $g_shell_name [命令列表] [文件名]...
	DESCRIPTION
		$g_git_wrap_shell_name --自动配置git环境
			-h
				get help log_info
			-f
				force mode to override exist file of the same name
			-a
				force mode to append exist file of the same name,not override
			-v
				verbose display
			-o
				the path of the out files
			-p
				use the proxy from hongxin(not recommend, may can not cross the Great Fire Wall)
				http://help.honx.in/hc/kb/article/32854/
	AUTHOR 作者
    	由 searKing Chan 完成。

    DATE   日期
		2015-11-16

	REPORTING BUGS 报告缺陷
    	向 searKingChan@gmail.com 报告缺陷。

	REFERENCE	参见
		https://github.com/searKing/PrivateGitHub.git
USAGEEOF
}

#循环嵌套调用程序,每次输入一个参数
#本shell中定义的其他函数都认为不支持空格字符串的序列化处理（pull其实也支持）
#@param func_in 	函数名 "func" 只支持单个函数
#@param param_in	以空格分隔的字符串"a b c",可以为空
function call_func_serializable()
{
	func_in=$1
	param_in=$2
	case $# in
		0|1)
			log_error "${LINENO}:$0 expercts 2 param in at least, but receive only $#. EXIT"
			return 1
			;;
		*)	#有参数函数调用
			error_num=0
			for curr_param in $param_in
			do
				case $func_in in
					"append_gitignore")
						gitignore_name=$curr_param
						$func_in "$gitignore_name"
						if [ $? -ne 0 ]; then
							error_num+=0
						fi
					 	;;
					*)
						log_error "${LINENO}:Invalid serializable cmd: $func_in"
						return 1
					 	;;
				esac
			done
			return $error_num
			;;
	esac
}

#解析输入参数
function parse_params_in() {
	if [ "$#" -lt 0 ]; then
		cat << HELPEOF
use option -h to get more log_information .
HELPEOF
		return 1
	fi
	set_default_cfg_param #设置默认配置参数
	set_default_var_param #设置默认变量参数
	unset OPTIND
	while getopts "afo:vph" opt
	do
		case $opt in
		a)
			#追加模式,与fwrite -a 选项相同
			g_cfg_append_mode=1
			;;
		f)
			#覆盖前永不提示
			g_cfg_force_mode=1
			;;
		o)
			#输出文件路径
			g_cfg_output_root_dir=$OPTARG
			;;
		v)
			#是否显示详细信息
			g_cfg_visual=1
			;;
		p)
			#是否使用代理
			g_cfg_use_proxy=1
			;;
		h)
			usage
			return 1
			;;
		?)
			log_error "${LINENO}:$opt is Invalid"
			return 1
			;;
		*)
			;;
		esac
	done
	#去除options参数
	shift $((OPTIND - 1))

	if [ "$#" -lt 0 ]; then
		cat << HELPEOF
use option -h to get more log_information .
HELPEOF
		return 0
	fi
	#配置文件输出路径
	g_gitignore_output_file_abs_name="$g_cfg_output_root_dir/$g_gitignore_file_name"
	#红杏代理
	g_cfg_proxy_urn="${g_cfg_proxy_protocal_hongxin}://${g_cfg_proxy_hostname_hongxin}:${g_cfg_proxy_port_hongxin}"
	g_cfg_proxy_protocal_hongxin="http"
	g_cfg_proxy_hostname_hongxin="hx.gy"
	g_cfg_proxy_port_hongxin="1080"
}

#安装apt应用
function install_apt_app_from_ubuntu()
{
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$FUNCNAME expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	app_name=$1
	#检测是否安装成功app
	if [ $g_cfg_visual -ne 0 ]; then
		which "$app_name"
	else
		which "$app_name"	1>/dev/null
	fi

	if [ $? -ne 0 ]; then
		sudo apt-get install -y "$app_name"
		ret=$?
		if [ $ret -ne 0 ]; then
			log_error "${LINENO}: install $app_name failed<$ret>. Exit."
			return 1;
		fi
	fi
}

#设置默认配置参数
function set_default_cfg_param(){
	#开发者名字
	g_user_name="searKing"
	#开发者邮箱
	g_user_email="searKingChan@gmail.com"
	#追加模式,与fwrite -a 选项相同
	g_cfg_append_mode=0
	#覆盖前永不提示-f
	g_cfg_force_mode=0
	#是否使用代理
	g_cfg_use_proxy=0
	#红杏代理
	g_cfg_proxy_protocal_hongxin="http"
	g_cfg_proxy_hostname_hongxin="hx.gy"
	g_cfg_proxy_port_hongxin="1080"
	#是否显示详细信息
	g_cfg_visual=0
	cd ~
	#输出文件路径
	g_cfg_output_root_dir="$(cd ~; pwd)/etc/git"
	cd -
	#gitignore文件在GitHub中的URN
	g_gitignore_repo_name="gitignore"
	g_gitignored_root_urn="https://github.com/searKing/$g_gitignore_repo_name.git"
}
#设置默认变量参数
function set_default_var_param(){
	#获取当前脚本名称
	g_shell_name="$(basename "$0")"
	#切换并获取当前脚本所在路径
	g_shell_repositories_abs_dir="$(cd "$(dirname "$0")"; pwd)"
	#输出文件名称
	g_gitignore_file_name="Global.gitignore"
}
#自动补全脚本环境搭建
function auto_config_git()
{
	git config --global user.name "$g_user_name"
	git config --global user.email "$g_user_email"
	#支持稀疏检出
	git config --global core.sparseCheckout true
	#git add等乱码
	git config --global core.quotepath false
	#高亮配置
	git config --global color.ui auto
	#设置代理
	if [[ $g_cfg_use_proxy -ne 0 ]]; then
		git config --global http.proxy "${g_cfg_proxy_urn}"
	fi

	#设置git默认编辑器--git rebase -i 时需要vim
	install_apt_app_from_ubuntu "vim"
	if [ $? -ne 0 ]; then
		return 1;
	fi

	git config --global core.editor vim
	#mergetool、difftool配置
	install_apt_app_from_ubuntu "meld" #kdiff3
	if [ $? -ne 0 ]; then
		return 1;
	fi

	git config --global merge.tool meld
	git config --global mergetool.prompt false
	#显示local merged remote 窗口，其实还有一个BASE窗口
	#1) $LOCAL=the file on the branch where you are merging; untouched by the merge process when shown to you
	#2) $REMOTE=the file on the branch from where you are merging; untouched by the merge process when shown to you
	#3) $BASE=the common ancestor of $LOCAL and $REMOTE, ie. the point where the two branches started diverting the considered file; untouched by the merge process when shown to you
	#4) $MERGED=the partially merged file, with conflicts; this is the only file touched by the merge process and, actually, never shown to you in meld
	git config --global  mergetool.meld.cmd "meld \$LOCAL \$MERGED \$REMOTE"

	git config --global diff.tool meld
	git config --global difftool.prompt false
	git config --global difftool.meld.cmd "meld \$LOCAL \$REMOTE"

	#安装图形界面gitk,分支、版本信息用这个清晰明了
	install_apt_app_from_ubuntu "gitk"
	if [ $? -ne 0 ]; then
		return 1;
	fi

	which meld #kdiff3
	if [ $? -ne 0 ]; then
		sudo apt-get install meld
		ret=$?
		if [ $ret -ne 0 ]; then
			log_error "${LINENO}: install meld failed($ret). Exit."
			return 1;
		fi
	fi

#	维护一个多人编辑的代码仓库常常意味着试着发现何人在改动什么，这个别名可以输出提交者和提交日期的log信息。--all 同时显示远程log
	git config --global alias.logpretty "log --pretty=format:'%C(yellow)%h %C(blue)� %C(red)%d %C(reset)%s %C(green) [%cn]' --decorate --date=short"
	git config --global alias.logprettyall "log --pretty=format:'%C(yellow)%h %C(blue)� %C(red)%d %C(reset)%s %C(green) [%cn]' --decorate --date=short --all"
#	git config --global alias.logpretty "log --pretty=oneline --abbrev-commit --graph --decorate"
	git config --global alias.loggraph "log --graph --pretty=format:'%C(yellow)%h %C(blue)%d %C(reset)%s %C(white)%an, %ar%C(reset)' --abbrev-commit"
	git config --global alias.loggraphall "log --graph --pretty=format:'%C(yellow)%h %C(blue)%d %C(reset)%s %C(white)%an, %ar%C(reset)' --abbrev-commit --all"
	git config --global alias.loggraphstat "log --graph --pretty=format:'%C(yellow)%h %C(blue)%d %C(reset)%s %C(white)%an, %ar%C(reset)' --stat"
	git config --global alias.loggraphstatall "log --graph --pretty=format:'%C(yellow)%h %C(blue)%d %C(reset)%s %C(white)%an, %ar%C(reset)' --all --stat"
	git config --global alias.loglast "log -1 HEAD"
	#undo（撤销）。undo会回退到上次提交，暂存区也会回退到那次提交时的状态。你可以进行额外的改动，用新的提交信息来再次进行提交。
	git config --global alias.undo "reset --soft HEAD^"
	#这个别名用来在一天的开启时回顾你昨天做了啥，或是在早晨刷新你的记忆
	git config --global alias.standup "log --since '1 day ago' --oneline --author searKingChan@gmail.com"
	#在提交前瞧瞧你将要提交的都有什么改动是一个好习惯，这可以帮助你发现拼写错误、不小心的提交敏感信息、将代码组织成符合逻辑的组。使用git add暂存你的改动，然后使用git ds查看你将要提交的改动动。

}

#从GitHub 克隆私有库所在公有库的根目录
function clone_gitignores_from_GitHub()
{
	expected_params_in_num=0
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
    log_info "${LINENO}:clone $g_gitignore_repo_name from GitHub"
	#切换并获取当前脚本所在路径
    cd "$g_shell_repositories_abs_dir"
    if [ -d $g_gitignore_repo_name ]; then
    	if [ $g_cfg_force_mode -eq 0 ]; then
			log_error "${LINENO}:$g_gitignore_repo_name files is already exist. use -f to override? Exit."
			return 1
		else
    		rm "$g_gitignore_repo_name" -Rf
    	fi
    fi
	git clone $g_gitignored_root_urn
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}:git clone $g_gitignored_root_urn failed : $ret"
		return 1
	fi
}
#将所有的.gitignore文件拼接为一个文件
function append_gitignore()
{
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	gitignore_name=$1
	#切换并获取当前脚本所在路径
	cd "$g_shell_repositories_abs_dir"
	cd $g_gitignore_repo_name
	echo "#$gitignore_name" >> "$g_gitignore_output_file_abs_name"
	cat "$gitignore_name" >> "$g_gitignore_output_file_abs_name"

	#切换并获取当前脚本所在路径--恢复路径现场
	cd "$g_shell_repositories_abs_dir"
}

#自动组合.gitignore
function auto_combile_gitignores()
{
	expected_params_in_num=0
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	#切换并获取当前脚本所在路径
	cd "$g_shell_repositories_abs_dir"
	#获取文件绝对路径

	gitignore_dir=${g_gitignore_output_file_abs_name%/*}
	if [ -e "$g_gitignore_output_file_abs_name" ]; then
		if ([ $g_cfg_append_mode -eq 0 ]|| ([ -d "$g_gitignore_output_file_abs_name" ]	&& [ $g_cfg_force_mode -ne 0 ])); then
			rm "$g_gitignore_output_file_abs_name" -Rf
			mkdir -p "$gitignore_dir"
			touch "$g_gitignore_output_file_abs_name"
		else
			log_error "${LINENO}:$g_gitignore_output_file_abs_name files is already exist. use -f to override? Exit."
			return 1
		fi

	else
		mkdir -p "$gitignore_dir"
		touch "$g_gitignore_output_file_abs_name"
	fi
    clone_gitignores_from_GitHub
    ret=$?
	if [ $ret -ne 0 ]; then
		return 1
	fi
	cd $g_gitignore_repo_name
    gitignore_names=$(find . -type f -name '*.gitignore')
	#去除./
	gitignore_names=${gitignore_names//.\//}
	if [ "$gitignore_names"x == x ]; then
		log_error "${LINENO}: gitignore files is NOT exist.EXIT"
		return 1
	fi
	call_func_serializable "append_gitignore" "$gitignore_names"
	ret=$?
	if [ $? -ne 0 ]; then
		return 1
	fi
	git config --global --replace-all core.excludesfile "$g_gitignore_output_file_abs_name"
}

function do_work(){
	auto_config_git
    ret=$?
	if [ $ret -ne 0 ]; then
		return 1
	fi

	auto_combile_gitignores
    ret=$?
	if [ $ret -ne 0 ]; then
		return 1
	fi
}
################################################################################
#脚本开始
################################################################################
function shell_wrap()
{
	#含空格的字符串若想作为一个整体传递，则需加*
	#"$*" is equivalent to "$1c$2c...", where c is the first character of the value of the IFS variable.
	#"$@" is equivalent to "$1" "$2" ...
	#$*、$@不加"",则无区别，
	parse_params_in "$@"
	if [ $? -ne 0 ]; then
		return 1
	fi
	do_work
	if [ $? -ne 0 ]; then
		return 1
	fi
	log_info "$0 $@ is running successfully"
	read -n1 -p "Press any key to continue..."
	return 0
}
shell_wrap "$@"
