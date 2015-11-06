#!/bin/bash

function usage() {
	cat<<USAGEEOF	
	NAME  
		$git_wrap_shell_name - 将任意数量的git仓库加密到托管在Github.com上的root git仓库中 
	SYNOPSIS  
		apkhack.sh [命令列表] [文件名]...   
	DESCRIPTION  
		$git_wrap_shell_name --将git仓库加密到托管在Github.com上的root git仓库中 
			init	
				Create git.private.pem and git.public.pem under ~/keys. Then create leaf directory under this direcotry and git-clone root from Github.
				NOTE: A Github repo called root should be created on github.com beforehand.
			push repo_name
				Make directory repo_name under leaf/ to an compressed archived file into root/ with the same name.
				Then add this archived file to git and push it to remote.
			pull repo_name
				Pull the update files from github to root. Decompress file repo_name under root/ to leaf/.
			help 
				get help info
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
function info() {
	echo "[INFO]$@"
}

function warn() {
	echo "[WARN]$@"
}

function error() {
	echo "[ERROR]$@"
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
function init() {
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	
    #创建私有库解密后存放的本地目录
    if [ ! -d "$public_root_dir" ]; then
		mkdir -p "$public_root_dir"
    fi 
    #创建非对称密钥
    if [ ! -d "$key_root_dir" ]; then
		mkdir -p "$key_root_dir"
    fi 
	    
	#加解密库公私钥名称
    if [ -e "$key_root_dir/$git_private_key_name" ] || [ -e "$key_root_dir/$git_public_key_name" ];	then 
		error "Pem files exits with the same name as $git_private_key_name and/or $git_public_key_name. Exit."
		exit 1
    fi
    info "Create pem files $git_private_key_name and $git_public_key_name under $key_root_dir"
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
	if [ $? -ne 0 ]; then
		error " openssl smime req failed : $?"
		exit 1
	fi 
    info "Pem files created. Please clone $private_root_dir  from your Github to be under $git_wrap_repositories_abs_dir."
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
    info "create $repo_name under $publicRoot"
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
    #创建本地的未加密的私有库
    if [ -z $repo_name ]; then
    	error "$repo_name is NULL"
    	exit 1
    fi
    
	#切换到私有仓库所在公有库的根目录
    cd "$public_root_dir"
    
    if [ -d $repo_name ]; then
		read -n3 -p "$repo_name is already exist, press y to clear:" clear_confirm	
		case $clear_confirm in
		"y"|"[yY][eE][sS]")
			rm -Rf $repo_name
			 ;;
		"n"|"[nN][oO]")
			echo $clear_confirm
			warn "cancel the operation of create $repo_name under $publicRoot "
			exit 1
			 ;;
		*) 
			echo $clear_confirm
			warn "cancel the operation of create $repo_name under $publicRoot "
			exit 1
			 ;;
		esac
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
	
    info "$repo_name created. Please clone $repo_name from your Local Git Repository"
    info "use cmd in your workspace:"
    info "git clone $git_wrap_repositories_abs_dir/$public_root_dir/$repo_name"
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
	
    info "Push $public_root_dir to Github"
    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
	#检查本地的未加密的私有仓库是否存在
    if [ ! -d "$public_root_dir/$repo_name" ]; then 
		error "public $repo_name does NOT exist."
		exit 1
    fi

	#删除老版本的加密私有仓库
    info "Remove $repo_name under $public_root_dir/"
    #删除root公开git仓库中的老版本已加密私有仓库
	if [ -f $private_root_dir/$repo_name ]; then
    	rm -f $private_root_dir/$repo_name
	fi
    info "Encrypt $repo_name from $public_root_dir to $private_root_dir"
    #将本地未加密的git仓库压缩打包到叶子节点临时操作目录中去
    tar -czf "$public_root_dir/$tmp_name" "$public_root_dir/$repo_name"
    ret=$?
    if [ $ret -ne 0 ]; then
		error " tar $public_root_dir/$repo_name: $ret"
		exit 1
	fi 
	if [ ! -f "$key_root_dir/$git_public_key_name" ]; then
		error " $key_root_dir/$git_public_key_name is NOT exist"
		exit 1
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
		error " openssl smimee  -encrypt failed : $ret"
		exit 1
	fi
	if [ -d $public_root_dir/$tmp_name ]; then
    	 rm -f "$public_root_dir/$tmp_name"
	fi
	#切换到私有仓库所在公有库的根目录
    cd "$private_root_dir"
    info "Add to Github"
    git add "$repo_name"
    ret=$?
    if [ $ret -ne 0 ]; then
		error " git add $repo_name failed : $ret"
		exit 1
	fi
    git commit -m"Push private $repo_name"
    ret=$?
    if [ $ret -ne 0 ]; then
		error " git commit $repo_name failed : $ret"
		exit 1
	fi
	#提交本地版本作为origin主机的maste分支
	#之后如果不重置-u的参数，则默认就是最后设置的主机和分支
    git push -u origin master
    ret=$?
    if [ $ret -ne 0 ]; then
		error " git push $repo_name failed : $ret"
		exit 1
	fi
    info "Finish push $repo_name"
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
    info "Pull from Github"
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
    
	#检查本地的加密的私有仓库是否存在
    if [ ! -d "$public_root_dir" ]; then 
		error "$public_root_dir does NOT exist."
		exit 1
    fi
    
	#切换到私有仓库所在公有库的根目录
    cd "$private_root_dir"
	#git pull的默认行为是git fetch + git merge
	# git pull --rebase则是git fetch + git rebase.
    git pull --rebase 
    ret=$?
    if [ $ret -ne 0 ]; then
		error " git pull failed : $ret"
		exit 1
	fi
    if [ ! -f "$repo_name" ];
	then 
		error "git pulled private $repo_name does NOT exist."
		exit 1
    fi
    
	#切换并获取当前脚本所在路径
    cd "$git_wrap_repositories_abs_dir"
	if [ ! -f "$key_root_dir/$git_private_key_name" ]; then
		error "$key_root_dir/$git_private_key_name is NOT exist"
		exit 1
	fi
    info "Decrypting $private_root_dir/$repo_name to $public_root_dir/$repo_name"
    info "$tmp_name"
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
		error " openssl smimee  -decrypt failed : $ret"
		exit 1
	fi
	
    if [ -d "$public_root_dir/$repo_name" ];
	then 
		rm -Rf $public_root_dir/$repo_name
		exit 1
    fi
     #将从远程下载的已加密的git仓库临时压缩包解压缩到本地未加密库所在根目录中去
    tar -xzf "$public_root_dir/$tmp_name" "$public_root_dir/$repo_name" 
    ret=$?
    if [ $ret -ne 0 ]; then
		error " untar $public_root_dir/$tmp_name: $ret"
		exit 1
	fi 
    rm -r $public_root_dir/$tmp_name
    info "Finish pull $repo_name"
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
#切换并获取当前脚本所在路径
git_wrap_repositories_abs_dir="$(cd `dirname $0`; pwd)"
info "git_wrap_repositories_abs_dir=${git_wrap_repositories_abs_dir}"
#获取当前脚本名称
git_wrap_shell_name="$(basename $0)"
#获取当前动作
git_wrap_action="$1"
#私有库所在公有库的根目录，之后的私有库repo全部以加密文件的形式存放在该公有目录下
private_root_dir="privateRoot"
#私有库repo解密后存放的本地根目录
public_root_dir="publicRoot"
#获取当前动作参数--私有库名称
repo_name="$2"
tmp_name="$repo_name.ttl1"
if ( [ "$git_wrap_action" == "push" ] || [ "$git_wrap_action" == "pull" ] ) && [ -z "$repo_name" ];
then 
    error "Need a repository name."
    exit 1
fi

#加解密库公私钥所在目录
key_root_dir="keyRoot"
#解密库私钥名称
git_private_key_name="git.private.pem"
#加密库公钥名称
git_public_key_name="git.public.pem"

case $git_wrap_action in
"init")
	init
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
	usage
	 ;;
esac

read -n1 -p "Press any key to continue..."
exit 0 
