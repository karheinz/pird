STYLESHEET=manpage.xsl
STYLESHEET_PATH=/usr/share/xml/docbook/stylesheet/docbook-xsl/manpages
XSLTPROC=xsltproc
SRC=manpage.xml

all: usage
usage: readme
	awk -f usage.awk ../README > ../usages/DefaultCommandLineParserUsage.txt
readme: doc
	stty cols 80
	man man/man1/pird.1 | col -bx > ../README
doc: manpage.xml
	$(XSLTPROC) --path $(STYLESHEET_PATH) $(STYLESHEET) $(SRC)
clean:
	rm -rf man 
