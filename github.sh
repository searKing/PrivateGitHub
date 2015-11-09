#!/bin/bash

function info() {
	echo "[INFO]$@"
}

function warn() {
	echo "[WARN]$@"
}

function error() {
	echo "[ERROR]$@"
}
#设置默认配置参数
function set_default_cfg_param(){
	#覆盖前永不提示
	cfg_force_mode=0	
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#key_root_dir
#          	|- git.private.pem			#git_private_key_name
#          	|- git.public.pem			#git_public_key_name
#          |- publicRoot/					#public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#private_root_dir
#					|-repo_name
#设置默认变量参数
function set_default_var_param(){	
	git_wrap_shell_name="$(basename $0)" #获取当前脚本名称
	#切换并获取当前脚本所在路径
	git_wrap_repositories_abs_dir="$(cd `dirname $0`; pwd)"
	
	#私有库所在公有库的根目录，之后的私有库repo全部以加密文件的形式存放在该公有目录下
	private_root_dir="privateRoot"	
	private_root_urn="https://github.com/searKing/$private_root_dir.git"
	public_root_dir="publicRoot" #私有库repo解密后存放的本地根目录
	tmp_name="$repo_name.ttl1" #加密缓存变量名
	key_root_dir="keyRoot" #加解密库公私钥所在目录
	git_private_key_name="git.private.pem" #解密库私钥名称
	git_public_key_name="git.public.pem" #加密库公钥名称
	workspace_root_dir="workspace" #工作目录
	
	commit_content="commit on $(date):Push private $repo_name"
}
#解析输入参数
function parse_params_in() {
	if [ "$#" -lt 1 ]; then   
		cat << HELPEOF
		use option -h to get more information .  
HELPEOF
		exit 1  
	fi   	
	set_default_cfg_param #设置默认配置参数	
	set_default_var_param #设置默认变量参数
	while getopts "fm:h" opt  
	do  
		case $opt in
		f)
			#覆盖前永不提示
			cfg_force_mode=1
			;;  
		m)
			#commit注释
			commit_content=$OPTARG
			;;  
		h)  
			usage
			exit 1  
			;;  	
		?)
			error "${LINENO}:$opt is Invalid"
			;;
		*)    
			;;  
		esac  
	done  
	#去除options参数
	shift $(($OPTIND - 1))
	
	if [ "$#" -lt 1 ]; then   
		cat << HELPEOF
		use option -h to get more information .  
HELPEOF
		exit 0  
	fi   
	#获取当前动作
	git_wrap_action="$1"
	#获取当前动作参数--私有库名称
	repo_name="$2"	
	
	if ( [ "$git_wrap_action" == "push" ] || [ "$git_wrap_action" == "pull" ] ) && [ -z "$repo_name" ];
	then 
		error "${LINENO}:Need a repository name."
		exit 1
	fi
	
	tmp_name="$repo_name.tmp" #加密缓存变量名
}
#使用方法说明
function usage() {
	cat<<USAGEEOF	
	NAME  
		$git_wrap_shell_name - 将任意数量的git仓库加密到托管在Github.com上的root git仓库中 
	SYNOPSIS  
		apkhack.sh [命令列表] [文件名]...   
	DESCRIPTION  
		$git_wrap_shell_name --将git仓库加密到托管在Github.com上的root git仓库中 
			-h 
				get help info
			req	
				Create git.private.pem and git.public.pem under ~/keys. Then create leaf directory under this direcotry and git-clone root from Github.		
			create
				create local public repo and workspace		
				NOTE: A Github repo called root should be created on github.com beforehand.
			push repo_name
				Make directory repo_name under leaf/ to an compressed archived file into root/ with the same name.
				Then add this archived file to git and push it to remote.
			pull repo_name
				Pull the update files from github to root. Decompress file repo_name under root/ to leaf/.
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
function do_work(){
	ret=0
	case $git_wrap_action in
	"req")
		req
		;;
	"create")
		create
	 	;;
	"push") 
		push "$repo_name" 
		;;
	"pull") 
		pull "$repo_name" 
		;;
	*) 
		error "${LINENO}:Invalid cmd: $git_wrap_action"
		exit 1
	 	;;
	esac
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#key_root_dir
#          	|- git.private.pem			#git_private_key_name
#          	|- git.public.pem			#git_public_key_name
#          |- publicRoot/					#public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#private_root_dir
#					|-repo_name
#创建私有库非加密本地目录
#创建非对称密钥对
function req() {
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	
    #创建非对称密钥
    if [ ! -d "$key_root_dir" ]; then
		mkdir -p "$key_root_dir"
    fi 
	    
	#加解密库公私钥名称
    if [ -e "$key_root_dir/$git_private_key_name" ] || [ -e "$key_root_dir/$git_public_key_name" ];	then 
    	if [ $cfg_force_mode -eq 0 ]; then
			error "${LINENO}:Pem files exits with the same name as $git_private_key_name and/or $git_public_key_name. Exit."
			exit 1
		else
			info "${LINENO}:force overwrite exist Pem files"
    	fi
    fi
    info "${LINENO}:Create pem files $git_private_key_name and $git_public_key_name under $key_root_dir"
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
    openssl req -x509 -nodes -days 100000 -newkey rsa:2048 -keyout "$key_root_dir/$git_private_key_name" -out "$key_root_dir/$git_public_key_name" -subj '/'
    ret=$?
	if [ $ret -ne 0 ]; then
		error "${LINENO}:openssl smime req failed : $ret"
		exit 1
	fi 
    info "${LINENO}:Pem files created. Please clone $private_root_dir from your Github to be under $git_wrap_repositories_abs_dir."
}

#从GitHub 克隆私有库所在公有库的根目录
function clone_privateRoot_from_GitHub()
{
    info "${LINENO}:create $repo_name under $private_root_dir"
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
	git clone $private_root_urn
	ret=$?
	if [ $ret -ne 0 ]; then
		error "${LINENO}:git clone $private_root_urn failed : $ret"
		exit 1
	fi 
}
#将私有库所在公有库的根目录上传到GitHub仓库
function push_privateRoot_to_GitHub()
{
    info "${LINENO}:create $repo_name under $private_root_dir"
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	
	#切换到私有仓库所在公有库的根目录
    cd "$private_root_dir"
    info "${LINENO}:Commit $private_root_dir to Github automatically"
    git commit -m "$commit_content"
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}:git commit $private_root_dir failed : $ret.EXIT"
		exit 1
	fi
	#提交本地版本作为origin主机的maste分支
	#之后如果不重置-u的参数，则默认就是最后设置的主机和分支
    git push -u origin master
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}:git push $private_root_dir failed : $ret.EXIT"
		exit 1
	fi
    info "Finish push $repo_name"
	
}

#创建工作空间并从本地未加密私有仓库clone最新副本
function create_workspace
{	
	info "create&clone workspace $repo_name to $workspace_root_dir/" 
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	if [ -d $workspace_root_dir/$repo_name ]; then
		rm $workspace_root_dir/$repo_name -Rf
	fi    
	mkdir -p $workspace_root_dir/$repo_name
	
	#切换到未加密的repo工作目录
    cd $workspace_root_dir/
    git clone $git_wrap_repositories_abs_dir/$public_root_dir/$repo_name
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}:git clone $public_root_dir/$repo_name: $ret"
		exit 1
	fi	
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#key_root_dir
#          	|- git.private.pem			#git_private_key_name
#          	|- git.public.pem			#git_public_key_name
#          |- publicRoot/					#public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#private_root_dir
#					|-repo_name
#创建本地的未加密的私有仓库
function create() {	
    info "create $repo_name under $public_root_dir"
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
    #创建私有库解密后存放的本地目录
    if [ ! -d "$public_root_dir" ]; then
		mkdir -p "$public_root_dir"
    fi 
        
	#切换到私有仓库所在公有库的根目录
    cd "$public_root_dir"
    
    if [ -d $repo_name ]; then
    	if [ $cfg_force_mode -eq 0 ]; then
			error "${LINENO}:$repo_name files is already exist. Exit."
			exit 1
		else
			info "force delete exist $repo_name files"			
    	fi
    fi    
    
    mkdir -p $repo_name    	
	#切换到未加密的repo版本库目录
    cd "$repo_name"
    #将 $repo_name 目录初始化为空的Git版本库
    #此时，当前git仓库就可以看成是远端仓库。					
	#使用命令"git init --bare"初始化的版本库(暂且称为bare repository)只会生成一类文件:用于记录版本库历史记录的.git目录下面的文件;而不会包含实际项目源文件的拷贝;所以该版本库不能称为工作目录(working tree);	
	#之所以叫裸仓库是因为这个仓库只保存git历史提交的版本信息，而不允许用户在上面进行各种git操作，如果你硬要操作的话，只会得到下面的错误（”This operation must be run in a work tree”）。		
	#这个就是最好把远端仓库初始化成bare仓库的原因。		
    git init --bare
    ret=$?
    if [ $ret -ne 0 ]; then
		error " git init $public_root_dir/$repo_name: $ret"
		exit 1
	fi 
	
    info "$repo_name created. Please clone $repo_name from your Local Bare Git Repository"
    info "use cmd in your workspace:"
    info "git clone $git_wrap_repositories_abs_dir/$public_root_dir/$repo_name"
	#创建工作空间并从本地未加密私有仓库clone最新副本
	create_workspace
	if [ $? -ne 0 ]; then
		exit 1
	fi 
}
#压缩本地的未加密的私有仓库，或广义的私有文件
function compress()
{
    info "${LINENO}:Compress $repo_name from $tmp_name"    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	#检查本地的未加密的私有仓库是否存在
    #这边，不限定为文件夹，文件也可以压缩
    if [ ! -e "$public_root_dir/$repo_name" ]; then
		error "${LINENO}: "$repo_name" to be compressed is NOT exist.EXIT"
		exit 1    	
    fi
	#删除临时操作目录中的老版本已压缩私有仓库
	if [ -f "$public_root_dir/$tmp_name" ]; then
		#删除老版本的压缩私有仓库
		info "${LINENO}:Remove old $tmp_name under $$public_root_dir/"
    	rm -f "$public_root_dir/$tmp_name"    	
	fi
    #将本地未加密的git仓库压缩打包到临时操作目录中去
    tar -czf "$public_root_dir/$tmp_name" "$public_root_dir/$repo_name"
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}:tar $repo_name : $ret"
		exit 1
	fi 
}
#解压本地的未加密的私有仓库，或广义的私有文件
function extract()
{
    info "Extract $tmp_name  to $repo_name"    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	#检查本地的未加密的私有仓库是否存在
    #这边，不限定为文件夹，文件也可以压缩
    if [ ! -e "$public_root_dir/$tmp_name" ]; then
		error "${LINENO}: "$tmp_name" to be extracted is NOT exist.EXIT"
		exit 1    	
    fi
	#删除本地未加密库所在根目录中老版本的已解压私有仓库
    if [ -d "$public_root_dir/$repo_name" ]; then 
		#删除老版本的未加密私有仓库
		info "${LINENO}:Remove old $repo_name under $public_root_dir/"
		rm -Rf $public_root_dir/$repo_name
    fi
     #将从远程下载的已加密的git仓库临时压缩包解压缩到本地未加密库所在根目录中去
    tar -xzf "$public_root_dir/$tmp_name" "$public_root_dir/$repo_name" 
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}: untar $public_root_dir/$tmp_name: $ret.EXIT"
		exit 1
	fi 
    rm -r $public_root_dir/$tmp_name
}
#加密本地的未加密的私有仓库
function encrypt()
{
    
    info "Encrypting $public_root_dir/$tmp_name to $private_root_dir/$repo_name "
    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
    if [ ! -e "$public_root_dir/$tmp_name" ]; then
		error "${LINENO}: "$repo_name" to be encrypted is NOT exist.EXIT"
		exit 1    	
    fi
	if [ ! -f "$key_root_dir/$git_public_key_name" ]; then
		error "${LINENO}: $key_root_dir/$git_public_key_name is NOT exist.EXIT"
		exit 1
	fi
	#删除root公开git仓库中的老版本已加密私有仓库
	if [ -f $private_root_dir/$repo_name ]; then
		#删除老版本的加密私有仓库
		info "${LINENO}:Remove old $repo_name under $private_root_dir/"
    	rm -f $private_root_dir/$repo_name    	
	fi

    #使用证书加密文件
	#-encrypt：用给定的接受者的证书加密邮件信息。输入文件是一个消息值，用于加密。输出文件是一个已经被加密了的MIME格式的邮件信息。
	#-des, -des3, -seed, -rc2-40, -rc2-64, -rc2-128, -aes128, -aes192, -aes256，-camellia128, -camellia192, -camellia256：指定的私钥保护加密算法。默认的算法是rc2-40。
	#-binary：不转换二进制消息到文本消息值
	#-outform SMIME|PEM|DER：输出格式。一般为SMIME、PEM、DER三种。默认的格式是SMIME
	#-in file：输入消息值，它一般为加密了的以及签名了的MINME类型的消息值。
	#-out file：已经被解密或验证通过的数据的保存位置。
	#
    openssl smime -encrypt -aes256 -binary -outform DEM -in "$public_root_dir/$tmp_name" -out "$private_root_dir/$repo_name" "$key_root_dir/$git_public_key_name" 
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}: openssl smimee  -encrypt failed : $ret.EXIT"
		exit 1
	fi
	if [ -d $public_root_dir/$tmp_name ]; then
    	 rm -f "$public_root_dir/$tmp_name"
	fi	
}

#解密本地的已加密的私有仓库
function decrypt()
{
    
    info "${LINENO}:Decrypting $private_root_dir/$repo_name to $public_root_dir/$tmp_name"
    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
    if [ ! -e "$private_root_dir/$repo_name" ]; then
		error "${LINENO}: "$repo_name" to be decrypted is NOT exist.EXIT"
		exit 1    	
    fi
    #检查私有密钥
	if [ ! -f "$key_root_dir/$git_private_key_name" ]; then
		error "${LINENO}:private key : $key_root_dir/$git_private_key_name is NOT exist.EXIT"
		exit 1		
	fi
	#删除root公开git仓库中的老版本已解密未解压的私有仓库
	if [ -f $public_root_dir/$tmp_name ]; then
		#删除老版本的加密私有仓库
		info "${LINENO}:Remove old $tmp_name under $public_root_dir/"
    	rm -f $public_root_dir/$tmp_name    	
	fi

	#检查本地的已解密的私有仓库是否存在
	if [ ! -d "$public_root_dir" ]; then 
		mkdir -p $public_root_dir
	fi
	
	
    #使用证书解密文件
	#-decrypt：用提供的证书和私钥值来解密邮件信息值。从输入文件中获取到已经加密了的MIME格式的邮件信息值。解密的邮件信息值被保存到输出文件中。
	#-binary：不转换二进制消息到文本消息值
	#-inform SMIME|PEM|DER：输入消息的格式。一般为SMIME|PEM|DER三种。默认的是SMIME。
	#-inkey file：私钥存放地址，主要用于签名或解密数据。这个私钥值必须匹配相应的证书信息。如果这个选项没有被指定，私钥必须包含到证书路径中（-recip、-signer）。
	#-in file：输入消息值，它一般为加密了的以及签名了的MINME类型的消息值。
	#-out file：已经被解密或验证通过的数据的保存位置。
	#
    openssl smime -decrypt -binary -inform DEM -inkey "$key_root_dir/$git_private_key_name" -in "$private_root_dir/$repo_name" -out "$public_root_dir/$tmp_name"
    ret=$?
    if [ $ret -ne 0 ]; then
		error "${LINENO}: openssl smimee  -decrypt failed : $ret.EXIT"
		exit 1
	fi
}
#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#key_root_dir
#          	|- git.private.pem			#git_private_key_name
#          	|- git.public.pem			#git_public_key_name
#          |- publicRoot/					#public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#private_root_dir
#					|-repo_name
#将本地的未加密的私有仓库进行压缩、加密、上传至Github服务器中去
#使用openssl进行加密工作
function push() {
	
    info "${LINENO}:Push $repo_name to Github"
    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
    #从GitHub 克隆私有库所在公有库的根目录
    if [ ! -d $private_root_dir ]; then
    	clone_privateRoot_from_GitHub
		if [ $? -ne 0 ]; then
			exit 1
		fi 
    	
    fi
    
	#压缩本地的未加密的私有仓库，或广义的私有文件
	compress
    if [ $? -ne 0 ]; then
		exit 1
	fi 
    #使用证书加密文件
	encrypt
    if [ $? -ne 0 ]; then
		exit 1
	fi 
	
	#切换到私有仓库所在公有库的根目录
    cd "$private_root_dir"
    if [ ! -z $repo_name ]; then
		info "${LINENO}:Add to Github"
		git add "$repo_name"
		ret=$?
		if [ $ret -ne 0 ]; then
			error "${LINENO}: git add $repo_name failed : $ret.EXIT"
			exit 1
		fi
	fi
    
	#将私有库所在公有库的根目录上传到GitHub仓库
	push_privateRoot_to_GitHub
    if [ $? -ne 0 ]; then
		exit 1
	fi
    info "${LINENO}:Finish push $repo_name"
}    

#git_repositories_dir --
#          |- github.sh
#			 |-keyRoot/							#key_root_dir
#          	|- git.private.pem			#git_private_key_name
#          	|- git.public.pem			#git_public_key_name
#          |- publicRoot/					#public_root_dir
#					|-repo_name
#					|-tmp_name
#          |- privateRoot/					#private_root_dir
#					|-repo_name
#从Github服务器中下载已加密的私有仓库，进行解压缩、解密
#使用openssl进行解密工作
function pull() {
    info "${LINENO}:Pull $repo_name from Github"
    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    #从GitHub 克隆私有库所在公有库的根目录
    if [ ! -d $private_root_dir ]; then
    	clone_privateRoot_from_GitHub
		if [ $? -ne 0 ]; then
			exit 1
		fi 
    else    
		#切换并获取当前脚本所在路径
		cd "$git_wrap_repositories_abs_dir"
				
		#切换到私有仓库所在公有库的根目录
		cd "$private_root_dir"
		#git pull的默认行为是git fetch + git merge
		# git pull --rebase则是git fetch + git rebase.
		git pull --rebase 
		ret=$?
		if [ $ret -ne 0 ]; then
			error "${LINENO}: git pull failed : $ret"
			exit 1
		fi
    fi
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
	#解密本地的已加密的私有仓库
	decrypt    
    if [ $? -ne 0 ]; then
		exit 1
	fi 
    #解压本地的未加密的私有仓库，或广义的私有文件
	extract
    if [ $? -ne 0 ]; then
		exit 1
	fi 
	
    #创建工作空间并从本地未加密私有仓库clone最新副本
	create_workspace
	if [ $? -ne 0 ]; then
		exit 1
	fi 
    info "${LINENO}:Finish pull $repo_name"
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
info "$0 $@ running success"
read -n1 -p "Press any key to continue..."
exit 0 
