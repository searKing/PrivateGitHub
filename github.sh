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
		$g_git_wrap_shell_name - 将任意数量的git仓库加密到托管在Github.com上的root git仓库中 
	SYNOPSIS  
		$g_git_wrap_shell_name [命令列表] [文件名]...   
	DESCRIPTION  
		$g_git_wrap_shell_name --将git仓库加密到托管在Github.com上的root git仓库中 
			-h 
				get help log_info
			-f 
				force mode to override exist file of the same name
			-m 	comment_content
				comment with the comment content
			req	
				Create git.private.pem and git.public.pem under ~/g_key_root_dir. Then create leaf directory under this direcotry and git-clone root from Github.		
			create
				create local public repo and workspace		
				NOTE: A Github repo called root should be created on github.com beforehand.
				surrpot serializable repo_names seperated by space
			push repo_name
				Make directory repo_name under g_public_root_dir/ to an compressed archived file into g_private_root_dir/ with the same name.
				Then add this archived file to git and push it to remote.
				if repo_name is null , then push all dirs under the g_public_root_dir/
				surrpot serializable repo_names seperated by space
			pull repo_name
				Pull the update files from github to root. Decompress file repo_name under g_private_root_dir/ to g_public_root_dir/.
				if repo_name is null , then pull all dirs on the GitHub Server
				surrpot serializable repo_names seperated by space
	AUTHOR 作者
    		由 searKing Chan 完成。
			
       	DATE   日期
		2015-11-06

	REPORTING BUGS 报告缺陷
    		向 searKingChan@gmail.com 报告缺陷。	
	REFERENCE	参见
			https://github.com/searKing/GithubHub.git
USAGEEOF
}
#循环嵌套调用程序,每次输入一个参数
#本shell中定义的其他函数都认为不支持空格字符串的序列化处理（pull其实也支持）
#@param func_in 	函数名 "func" 只支持单个函数
#@param param_in	以空格分隔的字符串"a b c",可以为空
function call_func_serializable
{
	func_in=$1
	param_in=$2
	case $# in
		0)
			log_error "${LINENO}:$0 expercts 1 param in at least, but receive only $#. EXIT"
			return 1
			;;
		1)	#无参数函数调用
			if ( [ "$func_in" != "req" ] && [ "$func_in" != "pull" ] && [ "$func_in" != "push" ] ); then
				log_error "${LINENO}:Invalid serializable cmd without params: $func_in"
				return 1
			fi
			$func_in 
			if [ $? -ne 0 ]; then
				error_num+=0
			fi
			return $error_num
			;;
		*)	#有参数函数调用
			error_num=0
			for curr_param in $param_in
			do	
				case $func_in in
					"create" | "push" | "pull" | "encrypt" | "decrypt" | "compress" | "extract" | "create_workspace" | "git add")
						repo_name=$curr_param
						$func_in "$repo_name"
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

#设置默认配置参数
function set_default_cfg_param(){
	#覆盖前永不提示-f
	g_cfg_force_mode=0	
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#g_key_root_dir
#          	|- git.private.pem			#g_git_private_key_name
#          	|- git.public.pem			#g_git_public_key_name
#          |- publicRoot/					#g_public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#g_private_root_dir
#					|-repo_name
#设置默认变量参数
function set_default_var_param(){	
	g_git_wrap_shell_name="$(basename $0)" #获取当前脚本名称
	#切换并获取当前脚本所在路径
	g_git_wrap_repositories_abs_dir="$(cd `dirname $0`; pwd)"
	
	#私有库所在公有库的根目录，之后的私有库repo全部以加密文件的形式存放在该公有目录下
	g_private_root_dir="privateRoot"	
	g_private_root_urn="https://github.com/searKing/$g_private_root_dir.git"
	g_public_root_dir="publicRoot" #私有库repo解密后存放的本地根目录
	g_tmp_dot_suffix=".tmp" #加密缓存变量名的带点后缀
	g_tmp_root_dir="tmp" #加解密库公私钥所在目录
	g_key_root_dir="keyRoot" #加解密库公私钥所在目录
	g_git_private_key_name="git.private.pem" #解密库私钥名称
	g_git_public_key_name="git.public.pem" #加密库公钥名称
	g_workspace_root_dir="workspace" #工作目录
	
	g_commit_content="commit on $(date):Push private "$repo_name""
	
	g_git_wrap_action="" #当前动作
	g_repo_names="" #当前动作参数--私有库名称
}
#解析输入参数
function parse_params_in() {
	if [ "$#" -lt 1 ]; then   
		cat << HELPEOF
		use option -h to get more log_information .  
HELPEOF
		return 1  
	fi   	
	set_default_cfg_param #设置默认配置参数	
	set_default_var_param #设置默认变量参数
	while getopts "fm:h" opt  
	do  
		case $opt in
		f)
			#覆盖前永不提示
			g_cfg_force_mode=1
			;;  
		m)
			#commit注释
			g_commit_content=$OPTARG
			;;  
		h)  
			usage
			return 1  
			;;  	
		?)
			log_error "${LINENO}:$opt is Invalid"
			;;
		*)    
			;;  
		esac  
	done  
	#去除options参数
	shift $(($OPTIND - 1))
	
	if [ "$#" -lt 1 ]; then   
		cat << HELPEOF
		use option -h to get more log_information .  
HELPEOF
		return 0  
	fi   
	#获取当前动作
	g_git_wrap_action="$1"
	
	#去除options参数
	#shift n表示把第n+1个参数移到第1个参数, 即命令结束后$1的值等于$n+1的值
	shift 1
	#获取当前动作参数--私有库名称
	g_repo_names="$@"	    
    
	case $g_git_wrap_action in
	create) #必须要输入一个参数
		#若未指定私有仓库repo，则
		if [ -z "$g_repo_names" ]; then
			log_error "${LINENO}:Need a repository name."
			return 1
    	fi
		;;  
	*)    
		;;  
	esac     
}
function do_work(){
	if [ "$g_repo_names"x == ""x ]; then	
		call_func_serializable "$g_git_wrap_action"
		ret=$?
	else		
		call_func_serializable "$g_git_wrap_action" "$g_repo_names"	
		ret=$?
	fi
	if [ $? -ne 0 ]; then
		return 1
	fi 
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#g_key_root_dir
#          	|- git.private.pem			#g_git_private_key_name
#          	|- git.public.pem			#g_git_public_key_name
#          |- publicRoot/					#g_public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#g_private_root_dir
#					|-repo_name
#创建私有库非加密本地目录
#创建非对称密钥对
function req() {
	expected_params_in_num=0
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
    log_info "${LINENO}:Create pem files $g_git_private_key_name and $g_git_public_key_name under $g_key_root_dir"
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
	
    #创建非对称密钥
    if [ ! -d "$g_key_root_dir" ]; then
		mkdir -p "$g_key_root_dir"
    fi 
	    
	#加解密库公私钥名称
    if [ -e "$g_key_root_dir/$g_git_private_key_name" ] || [ -e "$g_key_root_dir/$g_git_public_key_name" ];	then 
    	if [ $g_cfg_force_mode -eq 0 ]; then
			log_error "${LINENO}:Pem files returns with the same name as $g_git_private_key_name and/or $g_git_public_key_name. Exit."
			return 1
		else
			log_info "${LINENO}:force overwrite exist Pem files"
    	fi
    fi
    #调用openssl创建加解密用的密钥对，并设置证书请求
	#-x509：本选项将产生自签名的证书。一般用来做测试用，或者自己做个Root CA。证书的扩展项在 config文件里面指定。
	#-nodes：如果该选项被指定，如果私钥文件已经被创建则不用加密。
	#-days n：指定自签名证书的有效期限。默认为30天
	#-newkey rsa:bits：用于生成新的rsa密钥以及证书请求。如果用户不知道生成的私钥文件名称，默认采用privkey.pem，生成的证书请求。如果用户不指定输出文件(-out)，则将证书请求文件打印在屏幕上。生成的私钥文件可以用-keyout来指定。生成过程中需要用户输入私钥的保护口令以及证书申请中的一些信息。
	#-newkey dsa:file：用file中的dsa密钥参数来产生一个DSA密钥。
	#-newkey ec:file：用file中的密钥参数来产生一个EC密钥。
	#-keyout filename：指明创建的新的私有密钥文件的文件名。如果该选项没有被设置,，将使用config文件里面指定的文件名。
	#-out filename：输出证书请求文件，默认为标准输出。--公钥
	#-subj arg：用于指定生成的证书请求的用户信息，或者处理证书请求时用指定参数替换。
	#						生成证书请求时，如果不指定此选项，程序会提示用户来输入各个用户信息，包括国名、组织等信息，
	#						如果采用此选择，则不需要用户输入了。比如：-subj /CN=china/OU=test/O=abc/CN=forxy，注意这里等属性必须大写。
    openssl req -x509 -nodes -days 100000 -newkey rsa:2048 -keyout "$g_key_root_dir/$g_git_private_key_name" -out "$g_key_root_dir/$g_git_public_key_name" -subj '/'
    ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}:openssl smime req failed : $ret"
		return 1
	fi 
    log_info "${LINENO}:Pem files created. Please clone $g_private_root_dir from your Github to be under $g_git_wrap_repositories_abs_dir."
}

#从GitHub 克隆私有库所在公有库的根目录
function clone_privateRoot_from_GitHub()
{
	expected_params_in_num=0
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
    log_info "${LINENO}:clone $g_private_root_dir from GitHub"
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
    
	git clone $g_private_root_urn
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}:git clone $g_private_root_urn failed : $ret"
		return 1
	fi 
}
#将私有库所在公有库的根目录上传到GitHub仓库
#@param repo_name 	私有仓库名
function push_privateRoot_to_GitHub()
{
	expected_params_in_num=0
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
    log_info "${LINENO}:push $g_private_root_dir to GitHub"
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
	
	#切换到私有仓库所在公有库的根目录
    cd "$g_private_root_dir"
    log_info "${LINENO}:Commit $g_private_root_dir to Github automatically"
    git commit -m "$g_commit_content"
    ret=$?
    if [ $ret -ne 0 ]; then
		log_error "${LINENO}:git commit $g_private_root_dir failed : $ret.EXIT"
		return 1
	fi
	#提交本地版本作为origin主机的maste分支
	#之后如果不重置-u的参数，则默认就是最后设置的主机和分支
    git push -u origin master
    ret=$?
    if [ $ret -ne 0 ]; then
		log_error "${LINENO}:git push $g_private_root_dir failed : $ret.EXIT"
		return 1
	fi
}

#创建工作空间并从本地未加密私有仓库clone最新副本
#@param repo_name 	私有仓库名
function create_workspace
{	
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	repo_name=$1
	log_info "create&clone workspace "$repo_name" to $g_workspace_root_dir/" 
	#切换并获取当前脚本所在路径
	cd "$g_git_wrap_repositories_abs_dir"
	if [ -d $g_workspace_root_dir/"$repo_name" ]; then
		rm $g_workspace_root_dir/"$repo_name" -Rf
	fi    
	mkdir -p $g_workspace_root_dir/"$repo_name"
	
	#切换到未加密的repo工作目录
	cd $g_workspace_root_dir/
	git clone $g_git_wrap_repositories_abs_dir/$g_public_root_dir/"$repo_name"
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}:git clone $g_public_root_dir/"$repo_name": $ret"
		return 1
	fi
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#g_key_root_dir
#          	|- git.private.pem			#g_git_private_key_name
#          	|- git.public.pem			#g_git_public_key_name
#          |- publicRoot/					#g_public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#g_private_root_dir
#					|-repo_name
#创建本地的未加密的私有仓库
#@param repo_name 	私有仓库名
function create()
{	
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	repo_name=$1
	log_info "create "$repo_name" under $g_public_root_dir"
	#切换并获取当前脚本所在路径
	cd "$g_git_wrap_repositories_abs_dir"
		
	#创建私有库解密后存放的本地目录
	if [ ! -d "$g_public_root_dir" ]; then
		mkdir -p "$g_public_root_dir"
	fi 
		    
	#切换到私有仓库所在公有库的根目录
	cd "$g_public_root_dir"
		
	if [ -d "$repo_name" ]; then
		if [ $g_cfg_force_mode -eq 0 ]; then
			log_error "${LINENO}:"$repo_name" files is already exist. Exit."
			return 1
		else
			log_info "force delete exist "$repo_name" files"			
		fi
	fi    
		
	mkdir -p "$repo_name"	
	#切换到未加密的repo版本库目录
	cd "$repo_name"
	#将 "$repo_name" 目录初始化为空的Git版本库
	#此时，当前git仓库就可以看成是远端仓库。					
	#使用命令"git init --bare"初始化的版本库(暂且称为bare repository)只会生成一类文件:用于记录版本库历史记录的.git目录下面的文件;而不会包含实际项目源文件的拷贝;所以该版本库不能称为工作目录(working tree);	
	#之所以叫裸仓库是因为这个仓库只保存git历史提交的版本信息，而不允许用户在上面进行各种git操作，如果你硬要操作的话，只会得到下面的错误（”This operation must be run in a work tree”）。		
	#这个就是最好把远端仓库初始化成bare仓库的原因。		
	git init --bare
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error " git init $g_public_root_dir/"$repo_name": $ret"
		return 1
	fi 
	
	log_info ""$repo_name" created. Please clone "$repo_name" from your Local Bare Git Repository"
	log_info "use cmd in your workspace:"
	log_info "git clone $g_git_wrap_repositories_abs_dir/$g_public_root_dir/"$repo_name""
	#创建工作空间并从本地未加密私有仓库clone最新副本
	create_workspace "$repo_name"
	if [ $? -ne 0 ]; then
		return 1
	fi 
}
#压缩本地的未加密的私有仓库，或广义的私有文件
#@param repo_name 	私有仓库名
function compress()
{
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	repo_name=$1
	tmp_name=""$repo_name"$g_tmp_dot_suffix"
	log_info "${LINENO}:Compress "$repo_name" from $tmp_name"    
	#切换并获取当前脚本所在路径
	cd "$g_git_wrap_repositories_abs_dir"
	#检查本地的未加密的私有仓库是否存在
	#这边，不限定为文件夹，文件也可以压缩
	if [ ! -e "$g_public_root_dir/"$repo_name"" ]; then
		log_error "${LINENO}: "$repo_name" to be compressed is NOT exist.EXIT"
		return 1    	
	fi
	#删除临时操作目录中的老版本已压缩私有仓库
	if [ -f "$g_tmp_root_dir/$tmp_name" ]; then
		#删除老版本的压缩私有仓库
		log_info "${LINENO}:Remove old $tmp_name under $g_tmp_root_dir/"
		rm -f "$g_tmp_root_dir/$tmp_name"    	
	fi
	if [ ! -d "$g_tmp_root_dir" ]; then 
		mkdir -p $g_tmp_root_dir
	fi
	#将本地未加密的git仓库压缩打包到临时操作目录中去
	tar -czf "$g_tmp_root_dir/$tmp_name" "$g_public_root_dir/"$repo_name""
	ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}:tar "$repo_name" : $ret"
		return 1
	fi 
}
#解压本地的未加密的私有仓库，或广义的私有文件
#@param repo_name 	私有仓库名
function extract()
{
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	repo_name=$1
	tmp_name=""$repo_name"$g_tmp_dot_suffix"
    log_info "Extract $tmp_name  to "$repo_name""    
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
	#检查本地的未加密的私有仓库是否存在
    #这边，不限定为文件夹，文件也可以压缩
    if [ ! -e "$g_tmp_root_dir/$tmp_name" ]; then
		log_error "${LINENO}: "$tmp_name" to be extracted is NOT exist.EXIT"
		return 1    	
    fi
	#删除本地未加密库所在根目录中老版本的已解压私有仓库
    if [ -d "$g_public_root_dir/"$repo_name"" ]; then 
		#删除老版本的未加密私有仓库
		log_info "${LINENO}:Remove old "$repo_name" under $g_public_root_dir/"
		rm -Rf $g_public_root_dir/"$repo_name"
    fi
     #将从远程下载的已加密的git仓库临时压缩包解压缩到本地未加密库所在根目录中去
    tar -xzf "$g_tmp_root_dir/$tmp_name" "$g_public_root_dir/"$repo_name"" 
    ret=$?
    if [ $ret -ne 0 ]; then
		log_error "${LINENO}: untar $g_tmp_root_dir/$tmp_name: $ret.EXIT"
		return 1
	fi 
    rm -r $g_tmp_root_dir/$tmp_name
}
#加密本地的未加密的私有仓库
#@param repo_name 	私有仓库名
function encrypt()
{
    
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	repo_name=$1
	tmp_name=""$repo_name"$g_tmp_dot_suffix"
    log_info "Encrypting $g_tmp_root_dir/$tmp_name to $g_private_root_dir/"$repo_name" "
    
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
    
    if [ ! -e "$g_tmp_root_dir/$tmp_name" ]; then
		log_error "${LINENO}: "$repo_name" to be encrypted is NOT exist.EXIT"
		return 1    	
    fi
	if [ ! -f "$g_key_root_dir/$g_git_public_key_name" ]; then
		log_error "${LINENO}: $g_key_root_dir/$g_git_public_key_name is NOT exist.EXIT"
		return 1
	fi
	#删除root公开git仓库中的老版本已加密私有仓库
	if [ -f $g_private_root_dir/"$repo_name" ]; then
		#删除老版本的加密私有仓库
		log_info "${LINENO}:Remove old "$repo_name" under $g_private_root_dir/"
    	rm -f $g_private_root_dir/"$repo_name"    	
	fi

    #使用证书加密文件
	#-encrypt：用给定的接受者的证书加密邮件信息。输入文件是一个消息值，用于加密。输出文件是一个已经被加密了的MIME格式的邮件信息。
	#-des, -des3, -seed, -rc2-40, -rc2-64, -rc2-128, -aes128, -aes192, -aes256，-camellia128, -camellia192, -camellia256：指定的私钥保护加密算法。默认的算法是rc2-40。
	#-binary：不转换二进制消息到文本消息值
	#-outform SMIME|PEM|DER：输出格式。一般为SMIME、PEM、DER三种。默认的格式是SMIME
	#-in file：输入消息值，它一般为加密了的以及签名了的MINME类型的消息值。
	#-out file：已经被解密或验证通过的数据的保存位置。
	#
    openssl smime -encrypt -aes256 -binary -outform DEM -in "$g_tmp_root_dir/$tmp_name" -out "$g_private_root_dir/"$repo_name"" "$g_key_root_dir/$g_git_public_key_name" 
    ret=$?
    if [ $ret -ne 0 ]; then
		log_error "${LINENO}: openssl smimee  -encrypt failed : $ret.EXIT"
		return 1
	fi
	if [ -f $g_tmp_root_dir/$tmp_name ]; then
    	 rm -f "$g_tmp_root_dir/$tmp_name"
	fi	
}

#解密本地的已加密的私有仓库
#@param repo_name 	私有仓库名
function decrypt()
{    
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$0 expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	repo_name=$1
	tmp_name=""$repo_name"$g_tmp_dot_suffix"
    log_info "${LINENO}:Decrypting $g_private_root_dir/"$repo_name" to $g_tmp_root_dir/$tmp_name"
    
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
    
    if [ ! -e "$g_private_root_dir/"$repo_name"" ]; then
		log_error "${LINENO}: "$repo_name" to be decrypted is NOT exist.EXIT"
		return 1    	
    fi
    #检查私有密钥
	if [ ! -f "$g_key_root_dir/$g_git_private_key_name" ]; then
		log_error "${LINENO}:private key : $g_key_root_dir/$g_git_private_key_name is NOT exist.EXIT"
		return 1		
	fi
	#删除root公开git仓库中的老版本已解密未解压的私有仓库
	if [ -f $g_tmp_root_dir/$tmp_name ]; then
		#删除老版本的加密私有仓库
		log_info "${LINENO}:Remove old $tmp_name under $g_tmp_root_dir/"
    	rm -f $g_tmp_root_dir/$tmp_name    	
	fi

	#检查本地的已解密的私有仓库是否存在
	if [ ! -d "$g_public_root_dir" ]; then 
		mkdir -p $g_public_root_dir
	fi
	
	
	if [ ! -d "$g_tmp_root_dir" ]; then 
		mkdir -p $g_tmp_root_dir
	fi
	
    #使用证书解密文件
	#-decrypt：用提供的证书和私钥值来解密邮件信息值。从输入文件中获取到已经加密了的MIME格式的邮件信息值。解密的邮件信息值被保存到输出文件中。
	#-binary：不转换二进制消息到文本消息值
	#-log_inform SMIME|PEM|DER：输入消息的格式。一般为SMIME|PEM|DER三种。默认的是SMIME。
	#-inkey file：私钥存放地址，主要用于签名或解密数据。这个私钥值必须匹配相应的证书信息。如果这个选项没有被指定，私钥必须包含到证书路径中（-recip、-signer）。
	#-in file：输入消息值，它一般为加密了的以及签名了的MINME类型的消息值。
	#-out file：已经被解密或验证通过的数据的保存位置。
	#
	openssl smime -decrypt -binary -inform DEM -inkey "$g_key_root_dir/$g_git_private_key_name" -in "$g_private_root_dir/"$repo_name"" -out "$g_tmp_root_dir/$tmp_name"
    ret=$?
    if [ $ret -ne 0 ]; then
		log_error "${LINENO}: openssl smimee  -decrypt failed : $ret.EXIT"
		return 1
	fi
}

#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#g_key_root_dir
#          	|- git.private.pem			#g_git_private_key_name
#          	|- git.public.pem			#g_git_public_key_name
#          |- publicRoot/					#g_public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#g_private_root_dir
#					|-repo_name
#将本地的未加密的私有仓库进行压缩、加密、上传至Github服务器中去
#使用openssl进行加密工作
#@param repo_name 	私有仓库名
function push() {	
    log_info "${LINENO}:Push $g_public_root_dir to Github"
    
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
    #从GitHub 克隆私有库所在公有库的根目录
    if [ ! -d $g_private_root_dir ]; then
    	clone_privateRoot_from_GitHub
		if [ $? -ne 0 ]; then
			return 1
		fi 
    	
    fi
    if [ $# -eq 0 ]; then
    	cd "$g_public_root_dir"
		#获得全部私有仓库名称
		repo_name=$(find . -mindepth 1 -maxdepth 1 -type d)
		repo_name=${repo_name//.\//}
		cd -
	else
		repo_name=$1
	fi	
	if [ "$repo_name"x == x ]; then
		log_error "${LINENO}: Push source public repo is NOT exist.EXIT"
		return 1
	fi
	log_info "${LINENO}:compress "$repo_name""
	#压缩本地的未加密的私有仓库，或广义的私有文件
	call_func_serializable "compress" "$repo_name" 
    if [ $? -ne 0 ]; then
		return 1
	fi 
	log_info "${LINENO}:encrypt "$repo_name""
    #使用证书加密文件
	call_func_serializable "encrypt" "$repo_name" 
    if [ $? -ne 0 ]; then
		return 1
	fi 
	
	#切换到私有仓库所在公有库的根目录
    cd "$g_private_root_dir"
    if [ ! -z "$repo_name" ]; then
		log_info "${LINENO}:Add "$repo_name" to Github"
		call_func_serializable "git add" "$repo_name"
		ret=$?
		if [ $ret -ne 0 ]; then
			log_error "${LINENO}: git add "$repo_name" failed : $ret.EXIT"
			return 1
		fi
	fi
    
	#将私有库所在公有库的根目录上传到GitHub仓库
	push_privateRoot_to_GitHub
    if [ $? -ne 0 ]; then
		return 1
	fi
    log_info "${LINENO}:Finish push "$repo_name""
}    

#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#g_key_root_dir
#          	|- git.private.pem			#g_git_private_key_name
#          	|- git.public.pem			#g_git_public_key_name
#          |- publicRoot/					#g_public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#g_private_root_dir
#					|-repo_name
#从Github服务器中下载已加密的私有仓库，进行解压缩、解密
#使用openssl进行解密工作
#@param repo_name 	私有仓库名--支持空格分割的字符串序列化
function pull() {
    log_info "${LINENO}:Pull $g_private_root_dir from Github"
    
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
    #从GitHub 克隆私有库所在公有库的根目录
    if [ ! -d $g_private_root_dir ]; then
    	clone_privateRoot_from_GitHub
		if [ $? -ne 0 ]; then
			return 1
		fi 
    else    
		#切换并获取当前脚本所在路径
		cd "$g_git_wrap_repositories_abs_dir"
				
		#切换到私有仓库所在公有库的根目录
		cd "$g_private_root_dir"
		#git pull的默认行为是git fetch + git merge
		# git pull --rebase则是git fetch + git rebase.
		git pull --rebase 
		ret=$?
		if [ $ret -ne 0 ]; then
			log_error "${LINENO}: git pull failed : $ret"
			return 1
		fi
    fi
	#切换并获取当前脚本所在路径
    cd "$g_git_wrap_repositories_abs_dir"
    	
    if [ $# -eq 0 ]; then
    	cd "$g_private_root_dir"
		#获得全部私有仓库名称
		repo_name=$(find . -mindepth 1 -maxdepth 1 -type f)
		repo_name=${repo_name//.\//}
		repo_name=${repo_name//.git/}
		repo_name=${repo_name//LICENSE/}
		repo_name=${repo_name//README.md/}
		cd -
	else
		repo_name=$1
	fi	
	if [ "$repo_name"x == x ]; then
		log_error "${LINENO}: Pull source private repo is NOT exist.EXIT"
		return 1
	fi
	
	#解密本地的已加密的私有仓库
	call_func_serializable "decrypt" "$repo_name"    
    if [ $? -ne 0 ]; then
		return 1
	fi 
    #解压本地的未加密的私有仓库，或广义的私有文件
	call_func_serializable "extract" "$repo_name" 
    if [ $? -ne 0 ]; then
		return 1
	fi 
	
    #创建工作空间并从本地未加密私有仓库clone最新副本
	call_func_serializable "create_workspace" "$repo_name" 
	if [ $? -ne 0 ]; then
		return 1
	fi 
    log_info "${LINENO}:Finish pull "$repo_name""
}


################################################################################
#脚本开始
################################################################################
#含空格的字符串若想作为一个整体传递，则需加*
#"$*" is equivalent to "$1c$2c...", where c is the first character of the value of the IFS variable.
#"$@" is equivalent to "$1" "$2" ... 
#$*、$@不加"",则无区别，
parse_params_in "$@"
if [ $? -ne 0 ]; then
	exit 1
fi

do_work
if [ $? -ne 0 ]; then
	exit 1
fi
log_info "$0 $@ running success"
read -n1 -p "Press any key to continue..."
exit 0 
