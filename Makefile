libexecdir=/usr/lib
libdir=/usr/lib
gitdir=$(libdir)/git-core

all:

install:
	install -m755 git-undo $(gitdir)/
	install -m755 git-undo.awk $(libexecdir)/
