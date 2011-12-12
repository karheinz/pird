pird: *.d c/cdio/*.d readers/*.d sources/*.d
	dmd *.d c/cdio/*.d readers/*.d sources/*.d -ofpird -L-lcdio -L-lcdio_cdda -Jusages -version=devel

.PHONY: clean
clean:
	rm -f *.o pird
