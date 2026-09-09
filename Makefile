PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: install uninstall

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 lid-awake $(DESTDIR)$(BINDIR)/lid-awake

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/lid-awake
