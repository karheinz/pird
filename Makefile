pird: *.d c/cdio/*.d sources/*.d
	dmd *.d c/cdio/*.d sources/*.d -ofpird -L-lcdio -Jusages

.PHONY: clean
clean:
	rm -f *.o pird
