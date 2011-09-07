pird: *.d sources/*.d
	dmd *.d sources/*.d -ofpird -L-lcdio -Jusages

.PHONY: clean
clean:
	rm -f *.o pird
