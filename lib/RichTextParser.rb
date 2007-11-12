#
# RichTextParser.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TextParser'
require 'RichTextScanner'
require 'RichTextSyntaxRules'

class RichTextParser < TextParser

  include RichTextSyntaxRules

  def initialize
    super
    @variables = %w( SPACE LINEBREAK TEXT CODE TITLE1 TITLE2 TITLE3
                     BULLET1 BULLET2 BULLET3 NUMBER1 NUMBER2 NUMBER3 )
    initRules
    @sectionCounter = [ 0, 0, 0 ]
    @numberListCounter = [ 0, 0, 0 ]
  end

  def open(text)
    @scanner = RichTextScanner.new(text + "\n\n")
  end

  def close
  end

  def nextToken
    @scanner.nextToken
  end

  def returnToken(token)
    @scanner.returnToken(token)
  end

end
