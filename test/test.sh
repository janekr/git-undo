#!/bin/sh

verify_op() {
	what=$1
	expect=$2
	desc=$3

	echo "$desc"
	res=$(echo $what | ../git-undo.awk)
	if echo "$res" | grep -Fqs -- "$expect" ; then
		echo "OK"
	else
		echo "FAIL"
		echo "Run: $what"
		echo "Expected: $expect"
		echo "Got: $res"
	fi
}

verify_op "git init" "rm -rf .git" "should remove the .git directory"

verify_op "git clone git@github.com:mapmeld/gitjk.git" "rm -rf ./gitjk" "should remove the default download directory"
verify_op "git clone git@github.com:mapmeld/gitjk.git test_gitjk" "rm -rf ./test_gitjk" "should remove a custom download directory"

verify_op "git add package.json" "git reset package.json" "should reset a previously-indexed file"
verify_op "git add ." "Using . or * affects all files" "should warn instead of doing git reset . or git reset *"

verify_op "git rm package.json --cached" "git add package.json" "should re-index a cached/removed file"
verify_op "git rm package.json" "git checkout HEAD package.json" "should un-delete a deleted file"

verify_op "git mv package.json p.json" "git mv p.json package.json" "should move the file back"

verify_op "git checkout bogus" "git checkout -" "should checkout back to the previous directory"
verify_op "git checkout -b created" "git checkout -" "should checkout back to the previous directory"

verify_op "git remote add github https://github.com" "git remote rm github" "should remove a remote add"
verify_op "git remote remove github" "git remote add github" "should warn a remote remove"
verify_op "git remote rm github" "git remote add github" "should warn a remote rm"
verify_op "git remote rename github banana" "git remote rename banana github" "should swap names in a remote rename"
verify_op "git remote" "doesn't change the repo" "does nothing without args"

verify_op "git commit" "git reset --soft HEAD^" "should unseal a commit"

verify_op "git revert 0ee030" "git reset --soft HEAD^" "should unseal the git revert commit"

verify_op "git fetch" "git update-ref refs/remotes/origin/master refs/remotes/origin/master@{1}" "should un-update master branch"

verify_op "git pull origin master" "git reset --hard HEAD^" "should do a reset after git pull"

verify_op "git merge merged" "git reset --hard HEAD^" "should do a reset after git merge"

verify_op "git archive HEAD" "rm -rf" "should tell user to remove archive"

verify_op "git stash" "git stash apply" "should tell user when they stashed changes"

verify_op "git stash apply" "git stash" "should tell user when they un-stashed changes"

verify_op "git stash pop" "git stash" "should tell user when they un-stashed changes"

verify_op "git stash list" "doesn't change the repo" "should tell user when they listed stashes"
verify_op "git branch banana" "git branch -D banana" "should tell user when they added a branch"
verify_op "git branch -D banana" "git branch" "should tell user when they deleted a branch"
verify_op "git branch -a" "doesn't change the repo" "should tell user when they listed branches"

verify_op "git push origin master" "This uploaded all of your committed changes to a remote repo." "should not fix a git push"
verify_op "git push heroku master" "heroku rollback" "should help fix a push to heroku"

# reassure user on do-nothing commands

verify_op "git status" "doesn't change the repo" "git status"
verify_op "git cat-file 0ee030" "doesn't change the repo" "git cat-file"
verify_op "git diff" "doesn't change the repo" "git diff"
verify_op "git show" "doesn't change the repo" "git show"
verify_op "git log" "doesn't change the repo" "git log"
verify_op "git ls-tree 0ee030" "doesn't change the repo" "git ls-tree"
verify_op "git grep" "doesn't change the repo" "git grep"

# unknown command

verify_op "git blog" "I didn't recognize that command" "should print an error message with unknown command"
verify_op "ls" "I didn't find a git command" "should print an error message without git"
