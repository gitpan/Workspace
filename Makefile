#
# Top-level makefile for Tk::Workspace.pm v 0.1, Sep 19, 2000.
#

# Directory where you want the executable scripts installed.

BINDIR=/usr/local/bin

SUBDIRS=Tk
MODULES=Tk/Workspace.pm
EXECUTABLES=mkws
MAKEFILES=Tk/Makefile 

all:  
	for i in $(SUBDIRS); do \
	sh -c "cd $$i && make"; \
	done

install: 
	for i in $(SUBDIRS); do \
	sh -c "cd $$i && make install"; \
	done
	cp mkws $(BINDIR)

clean: 
	for i in $(SUBDIRS); do \
	rm -f $$i/Makefile; \
	rm -f $$i/*~; \
	rm -f $$i/*.c; \
	rm -f $$i/*.o; \
	rm -f $$i/*.bs; \
	rm -rf $$i/blib; \
	rm -rf $$i/pm_to_blib; \
	done
	rm -f ./*~

veryclean: 
	for i in $(SUBDIRS); do \
	rm -f $$i/Makefile; \
	rm -f $$i/*~; \
	rm -f $$i/*.c; \
	rm -f $$i/*.o; \
	rm -f $$i/*.bs; \
	rm -f $$i/*.pm; \
	rm -rf $$i/blib; \
	rm -rf $$i/pm_to_blib; \
	done
	rm -f ./*~ browser*

makefiles: 
	for i in $(SUBDIRS); do \
	sh -c "cd $$i && perl Makefile.PL"; \
	done

devel:  $(MODULES) $(EXECUTABLES)

Tk/Workspace.pm:
	cp $(HOME)/objects/Tk/Workspace.pm Tk

mkws:
	cp $(HOME)/objects/mkws .

# h2xs: Tk/Browser/Makefile.PL Lib/Module/Makefile.PL

