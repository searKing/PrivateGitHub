function _github_autocomplete
{
    #local定义变量
    #cur表示当前光标下的单词
    #prev表示上一个单词
    #opts表示选项
    local cur prev opts
    #COMP_CWORD 已输入单词个数
    #给COMPREPLY赋值之前，最好将它重置清空，避免被其它补全函数干扰
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="req create push pull -f -m"

    case "$prev" in
    req)
        COMPREPLY=()
        return 0
        ;;
    create | push | pull | -m)
    	#定位当前目录的文件
    	#http://cnswww.cns.cwru.edu/php/chet/bash/NEWS.
        COMPREPLY=( $(compgen -o default -o plusdirs -f -- $cur) )
        return 0
        ;;
    -f)
        COMPREPLY=( $(compgen -W "req create -m" -- $cur ))
        return 0
        ;;
    -m)
        COMPREPLY=( $(compgen -W "push" -- $cur ))
        return 0
        ;;
    *)
        local prev2="${COMP_WORDS[COMP_CWORD-2]}"
        if [ "$prev2" == "create" ] || [ "$prev2" == "push" ] || [ "$prev2" == "pull" ];then
            return 0
        fi
        ;;
    esac	

    COMPREPLY=( $(compgen -W "$opts" -- $cur) )
    return 0
}
#调用github.sh命令，则会调用-F指定的补全函数_github_autocomplete
complete -F _github_autocomplete ./github.sh

