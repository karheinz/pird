pird: *.d c/cdio/*.d sources/*.d
	dmd *.d c/cdio/*.d sources/*.d -ofpird -L-lcdio -L-lcdio_cdda -Jusages

.PHONY: clean
clean:
	rm -f *.o pird
