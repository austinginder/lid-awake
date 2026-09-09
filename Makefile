PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
SHAREDIR ?= $(PREFIX)/share/lid-awake

.PHONY: install uninstall

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 lid-awake $(DESTDIR)$(BINDIR)/lid-awake
	install -d $(DESTDIR)$(SHAREDIR)/menubar/Sources
	install -d $(DESTDIR)$(SHAREDIR)/menubar/Resources/Assets
	install -m 644 menubar/Sources/main.m $(DESTDIR)$(SHAREDIR)/menubar/Sources/main.m
	install -m 644 menubar/Resources/Info.plist $(DESTDIR)$(SHAREDIR)/menubar/Resources/Info.plist
	install -m 644 menubar/Resources/Assets/lid-awake.svg $(DESTDIR)$(SHAREDIR)/menubar/Resources/Assets/lid-awake.svg

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/lid-awake
	rm -rf $(DESTDIR)$(SHAREDIR)
