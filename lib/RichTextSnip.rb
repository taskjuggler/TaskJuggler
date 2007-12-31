#
# RichTextSnip.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'RichText'
require 'HTMLDocument'

class RichTextSnip

  attr_reader :name
  attr_accessor :prevSnip, :nextSnip

  def initialize(document, fileName, sectionCounter)
    @document = document
    # Strip any directories from fileName.
    @name = fileName.index('/') ? fileName[fileName.rindex('/') + 1 .. -1] :
                                  fileName

    text = ''
    File.open(fileName) do |file|
      file.each_line { |line| text += line }
    end
    begin
      @richText = RichText.new(text, sectionCounter)
    rescue RichTextException => msg
      $stderr.puts "Error in RichText of rule #{@keyword}\n" +
                   "Line #{msg.lineNo}: #{msg.text}\n" +
                   "#{msg.line}"
      exit
    end

    @prevSnip = @nextSnip = nil
  end

  def tableOfContents(toc, fileName)
    @richText.tableOfContents(toc, fileName)
  end

  def generateHTML(directory = '')
    html = HTMLDocument.new
    html << (head = XMLElement.new('head'))
    head << XMLNamedText.new(@name, 'title')
    head << XMLElement.new('meta', 'http-equiv' => 'Content-Type',
                           'content' => 'text/html; charset=iso-8859-1')
    head << (style = XMLElement.new('style', 'type' => 'text/css'))
    style << XMLBlob.new(<<'EOT'
pre {
  font-size:16px;
  font-family: Courier;
  padding-left:8px;
  padding-right:8px;
  padding-top:0px;
  padding-bottom:0px;
}
p {
  margin-top:8px;
  margin-bottom:8px;
}
code {
  font-size:16px;
  font-family: Courier;
}
.table {
  background-color:#ABABAB;
  width:90%;
  margin-left:5%;
  margin-right:5%;
}
.tag {
  background-color:#E0E0F0;
  font-size:16px;
  font-weight:bold;
  padding-left:8px;
  padding-right:8px;
  padding-top:5px;
  padding-bottom:5px;
}
.descr {
  background-color:#F0F0F0;
  font-size:16px;
  padding-left:8px;
  padding-right:8px;
  padding-top:5px;
  padding-bottom:5px;
}
EOT
               )

    html << (body = XMLElement.new('body'))
    @document.generateHTMLHeader(body)
    generateHTMLNavigationBar(body)

    body << (div = XMLElement.new('div',
      'style' => 'width:90%; margin-left:5%; margin-right:5%'))
    div << @richText.to_html
    @document.generateHTMLFooter(body)

    html.write(directory + @name + '.html')
  end

private

  def generateHTMLNavigationBar(html)
    # Generate the 'previous'/'next' navigation elements.
    if @prevSnip || @nextSnip
      html << (tab = XMLElement.new('table',
        'style' => 'width:90%; margin-left:5%; margin-right:5%'))
      tab << (tr = XMLElement.new('tr'))
      tr << (td = XMLElement.new('td',
        'style' => 'text-align:left; width:35%;'))
      if @prevSnip
        td << XMLText.new('<< ')
        td << XMLNamedText.new("#{@prevSnip.name}", 'a',
                               'href' => "#{@prevSnip.name}.html")
        td << XMLText.new(' <<')
      end
      tr << (td = XMLElement.new('td',
        'style' => 'text-align:center; width:30%;'))
      td << XMLNamedText.new('Index', 'a', 'href' => 'toc.html')
      tr << (td = XMLElement.new('td',
        'style' => 'text-align:right; width:35%;'))
      if @nextSnip
        td << XMLText.new('>> ')
        td << XMLNamedText.new("#{@nextSnip.name}", 'a',
                               'href' => "#{@nextSnip.name}.html")
        td << XMLText.new(' >>')
      end
      html << XMLElement.new('hr')
    end
  end

end
