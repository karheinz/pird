pird: Makefile *.d c/cdio/*.d readers/*.d writers/*.d sources/*.d usages/*.txt
	dmd *.d c/cdio/*.d readers/*.d writers/*.d sources/*.d -ofpird \
		-L-lcdio -L-lcdio_cdda -L-lcdio_paranoia -Jusages \
		-w \
		-release

devel: Makefile *.d c/cdio/*.d readers/*.d writers/*.d sources/*.d usages/*.txt
	dmd *.d c/cdio/*.d readers/*.d writers/*.d sources/*.d -ofpird \
		-L-lcdio -L-lcdio_cdda -L-lcdio_paranoia -Jusages \
		-w \
		-version=devel


.PHONY: clean
clean:
	rm -f *.o pird
