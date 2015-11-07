PrivateGitHub
=========

Use private repository with a free account.

Overview:
=========
This project can encrypt any number of bare git repositories into another git repository which is hosted on Github.com.

How this project work:
======================
0. Beforehand:
There must be a repository called "privateRoot" on your Github.

1. Prepare:
After you extract the github.sh from this project into a certain directory(e.g. GithubRespository). So GithubRespository looks like:
|-GithubRespository
    |- github.sh

Then you should call "./github.sh req" to create pem files. After this, GithubRespository looks like this:
|-GithubRespository
	|- github.sh
	|- keyRoot/
	  |- git.private.pem
	  |- git.public.pem
All the prepare work is finished!

2. Usage:
Suppose I want to create a project called 'sample' which I would like to put onto Github while nobody else can read it.

Then call ./github.sh create sample. So this git repo will work like a remote one.(A bare repo is a git repo withou index and work space which is often used as center repositroy.)

After that, goto some other directory and git clone the newly created git bare repo: git clone dirs/GithubRespository/publicRoot/sample. Great! You are can work as usual now! Add some content and do some change. Then git add && git commit && git push. 

This git push will only push all the changes to your local git bare repos. To push the bare repo to your Github. Please use "github.sh push sample". The repo name following push should be exactly same with the directory name under leaf. Remeber this. This process will compress the secret and encrpyt it into a file under privateRoot/. Then push the update privateRoot to Github. During this process git.public.pem will be used.

Maybe you change the conent under 'sample' from other places with the similar method above and want to fetch the update content to your current PC. Please use "github.sh pull sample". This process will pull the content from Github to privateRoot/ and decrypt it into a normal directory under publicRoot/. During this process git.private.pem will be used.

IMPORTANT:
==========
After the pem files generated with "github.sh init", please take care these *.pem files carefully. Once they are lost, you have no way to decrypt the file on you Github which means you lost them forever!!
