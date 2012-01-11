STYLESHEET=manpage.xsl
STYLESHEET_PATH=/usr/share/xml/docbook/stylesheet/docbook-xsl/manpages
XSLTPROC=xsltproc
SRC=manpage.xml

all: doc
doc:
	$(XSLTPROC) --path $(STYLESHEET_PATH) $(STYLESHEET) $(SRC)
clean:
	rm -rf man 
