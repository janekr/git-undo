#!/usr/bin/gawk -f

BEGIN {
	info = ""
	undo = ""
	autorun = 0
	foundGit = 0
}

{
	gsub(/[ \t]+/, " ", $0)
	gsub(/\r?\n|\r/, " ", $0)
	gsub(/(^ )|( $)/, "", $0)
}

/^git / {
	undoCommand()
	if (info) {
		print info
		print "INFO|" info "|" >"/dev/fd/3"
		if (undo) {
			print undo
			print "UNDO|" undo "|" >"/dev/fd/3"
		} else if (autorun) {
			print "No undo command necessary"
			print "UNDO|1|" >"/dev/fd/3"
		} else {
			print "No undo command known"
			print "UNDO|2|" >"/dev/fd/3"
		}
		foundGit = 1
	} else {
		print "I didn't recognize that command"
		print "ERROR" >"/dev/fd/3"
	}
}

END {
	if (!foundGit) {
		print "I didn't find a git command"
	}
}

function remove_options(s, c) {
	cmd = substr(s, length(c)+1)
	nfiles = split(cmd, parts, / /)
	for (i=1; i<=nfiles; i++) {
		if (!match(parts[i], /^-/)) {
			files = files " " parts[i]
		}
	}
	return substr(files, 2)
}

function undoCommand() {
	if (/git init/) {
		info = "This created a .git folder in the current directory. You can remove it."
		undo = "rm -rf .git"
		autorun = 1
	} else if (/git clone/) {
		cloned = split(remove_options($0, "git clone "), cloned_into, / /)
		if (cloned > 1) {
			# specified output folder
			outputfolder = cloned_into[2]
		} else {
			# default output folder
			# extract from remote - for example https://github.com/mapmeld/gitjk.git
			urln = split(cloned_into[1], url, /\//)
			outputfolder = url[urln]
			sub(/\.git$/, "", outputfolder)
		}
		info = "This downloaded a repo and all of its git history to a folder. You can remove it."
		if (outputfolder && !match(outputfolder, /\.\./)) {
			gsub(/ /, "\\ ", outputfolder)
			undo = "rm -rf ./" outputfolder
			autorun = 1
		} else {
			info = info "\nCouldn't figure out what folder this was downloaded to."
			autorun = 0
		}
	} else if (/git add/) {
		filenames = remove_options($0, "git add ")
		info = "This added files to the changes staged for commit. All changes to files will be removed from staging for this commit, but remain saved in the local file system."
		if (match(filenames, /( |^)\.($| )/) || match(filenames, /\*/)) {
			info = info "\nUsing . or * affects all files, so you will need to run 'git reset <file>' on each file you didn't want to add."
			autorun = 0
		} else {
			undo = "git reset " filenames
			autorun = 1
		}
	} else if (/git rm/) {
		filenames = remove_options($0, "git rm ")
		if (/--cached/) {
			info = "This took files out of the changes staged for commit. All changes will be re-added to staging for this commit."
			undo = "git add " filenames
		} else {
			info = "Don't panic, but this deleted files from the file system. They're not in the recycle bin; they're gone. These files can be restored from your last commit, but uncommited changes were lost."
			undo = "git checkout HEAD " filenames
		}
		autorun = 1
	} else if (/git mv/) {
		split(remove_options($0, "git mv "), mvnames, / /)
		info = "This moved the file (named " mvnames[1] ") to " mvnames[2] ". It can be moved back."
		undo = "git mv " mvnames[2] " " mvnames[1]
		autorun = 1
	} else if (/git checkout/) {
		info = "git checkout moved you into a different branch of the repo. You can checkout any branch by name, or checkout the last one using -"
		undo = "git checkout -"
		autorun = 1
	} else if (/git remote add/) {
		split(remove_options($0, "git remote add "), repoinfo, / /)

		info = "This added a remote repo (named " repoinfo[1] ") pointing to " repoinfo[2]
		info = info "\nIt can be removed."
		undo = "git remote rm " repoinfo[1]
		autorun = 1
	} else if (/git remote remove/ || /git remote rm/) {
		split(remove_options($0, "git remote "), repo_name, / /)

		info = "This removed a remote repo (named " repo_name[2] ")"
		info = info "\nIt needs to be added back using git remote add " repo_name[2] " <git-url>"
		autorun = 0
	} else if (/git remote set-url/) {
		split(remove_options($0, "git remote set-url "), repoinfo, / /)

		info = "This changed the remote repo (named " repoinfo[1] ") to point to " repoinfo[2]
		info = info "\nIt can be removed (using git remote rm) or set again (using git remote set-url)."
		autorun = 0
	} else if (/git remote rename/) {
		split(remove_options($0, "git remote rename "), repoinfo, / /)

		info = "This changed the remote repo (named " repoinfo[1] ") to have the name " repoinfo[2] ". It can be reset."
		undo = "git remote rename " repoinfo[2] " " repoinfo[1]
		autorun = 1
	} else if (/git commit/) {
		info = "This saved your staged changes as a commit, which can be updated with git commit --amend or completely uncommited:"
		undo = "git reset --soft HEAD^"
	} else if (/git revert/) {
		info = "This made a new commit to retract a commit. You can undo *the revert commit* using a more extreme approach:"
		undo = "git reset --soft HEAD^"
	} else if (/git fetch/) {
		info = "This updated the local copy of all branches in this repo. Un-updating master (and you can do other branches, too)."
		undo = "git update-ref refs/remotes/origin/master refs/remotes/origin/master@{1}"
		autorun = 1
	} else if (/git pull/ || /git merge/) {
		info = "This merged another branch (local or remote) into your current branch. This resets you to the last version."
		undo = "git reset --hard HEAD^"
		autorun = 1
	} else if (/git push/) {
		autorun = 0
		info = "This uploaded all of your committed changes to a remote repo. It may be difficult to reverse it."
		info = info "\nYou can use git revert <commit_id> to tell repos to turn back these commits."
		info = info "\nThere is git checkout <commit_id> and git push --force, but this will mess up others' git history!"
		if (/git push heroku/) {
			info = info "\nIf you are hosting this app on Heroku, run 'heroku rollback' to reset your app now."; 
		}
	} else if (/git branch/) {
		autorun = 1
		if (/ -D/) {
			# delete branch
			info = "You deleted a branch. You can use 'git branch' to create it again, or 'git pull' to restore it from a remote repo."
			autorun = 0
		}
		if (/git branch /) {
			# create branch
			branchn = split(remove_options($0, "git branch "), branch, / /)

			if(branchn && branch[1] != "-"){
				info = "You created a new branch named " branch[1] ". You can delete it:"
				undo = "git branch -D " branch[1]
			}
		}
		if (!info) {
			# must have listed branches
			info = "git branch on its own doesn't change the repo; it just lists all branches. Use it often!"
		}
	} else if (/git stash/) {
		if (/stash list/) {
			info = "git stash list doesn't change the repo; it just tells you the stashed changes which you can restore using git stash apply."
			autorun = 1
		} else if (/stash pop/ || /stash apply/) {
			info = "You restored changes from the stash. You can stash specific changes again using git stash."
			autorun = 0
		} else {
			info = "You stashed any changes which were not yet commited. Restore the latest stash using:"
			undo = "git stash apply"
			autorun = 1
		}
	} else if (/git archive/) {
		info = "This created an archive of part of the repo - you can delete it using 'rm -rf <archive_file_or_folder>'."
		autorun = 0
	} else # harmless
	if (/git cat-file/) {
		info = "git cat-file doesn't change the repo; it just tells you the type of an object in the repo."
		autorun = 1
	} else if (/git diff/) {
		info = "git diff doesn't change the repo; it just tells you the changes waiting for commit OR the changes between branches. Use it often!"
		autorun = 1
	} else if (/git grep/) {
		info = "git grep doesn't change the repo; it's a search tool. Use grep and git grep often!"
		autorun = 1
	} else if (/git ls-tree/) {
		info = "git ls-tree doesn't change the repo; it just tells you about an object in the git repo."
		autorun = 1
	} else if (/git show/) {
		info = "git show doesn't change the repo; it just tells you the changes waiting for commit OR the changes between branches."
		autorun = 1
	} else if (/git log/) {
		info = "git log doesn't change the repo; it just lists the last several commits in this branch. Use it often!"
		autorun = 1
	} else if (/git status/) {
		info = "git status doesn't change the repo; it just tells you what changes there are. Use it often!"
		autorun = 1
	} else if (/git remote/) {
		info = "git remote (without additional arguments) doesn't change the repo; it just tells you what remotes there are. Use it often!"
		autorun = 1
	}
}
