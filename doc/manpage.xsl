<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:import href="docbook.xsl" />
  <!--xsl:import href="/usr/share/xml/docbook/stylesheet/docbook-xsl/manpages/docbook.xsl" /-->
  <xsl:param name="man.links.are.numbered">1</xsl:param>
  <xsl:param name="man.output.base.dir">man/</xsl:param>
  <xsl:param name="man.output.subdirs.enabled" select="1"></xsl:param>
  <xsl:param name="man.output.in.separate.dir" select="1"></xsl:param>
  <xsl:param name="man.authors.section.enabled">1</xsl:param>
</xsl:stylesheet>
