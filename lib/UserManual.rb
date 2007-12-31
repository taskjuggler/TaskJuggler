#
# UserManual.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Tj3Config'
require 'RichTextDocument'
require 'TjTime'

class UserManual < RichTextDocument

  def initialize
    super
  end

  def generateHTMLCover(html)
    html << (div = XMLElement.new('div', 'align' => 'center',
      'style' => 'margin-top:40px; margin-botton:40px'))
    div << XMLNamedText.new("The #{AppConfig.packageName} User Manual",
                            'h1')
    div << XMLNamedText.new('Project Management beyond Gantt Chart drawing',
                            'em')
    div << XMLElement.new('br')
    div << XMLNamedText.new("Copyright (c) #{AppConfig.copyright.join(', ')} " +
                            "by #{AppConfig.authors.join(', ')}", 'b')
    div << XMLElement.new('br')
    div << XMLText.new("Generated on #{TjTime.now.strftime('%Y-%m-%d')}")
    div << XMLElement.new('br')
    div << XMLNamedText.new("This manual covers #{AppConfig.packageName} " +
                            "version #{AppConfig.version}.", 'h3')
    html << XMLElement.new('br')
    html << XMLElement.new('hr')
  end

  def generateHTMLHeader(html)
    html << (headline = XMLElement.new('div', 'align' => 'center'))
    headline << XMLNamedText.new(
      "The #{AppConfig.packageName} User Manual", 'h3',
      'align' => 'center')
    headline << XMLNamedText.new(
      'Project Management beyond Gantt Chart Drawing', 'em',
      'align' => 'center')
    html << XMLElement.new('hr')
  end

  def generateHTMLFooter(html)
    html << XMLElement.new('br')
    html << XMLElement.new('hr')
    html << (div = XMLElement.new('div', 'align' => 'center',
                                  'style' => 'font-size:10px;'))
    div << XMLText.new("Copyright (c) #{AppConfig.copyright.join(', ')} by " +
                       "#{AppConfig.authors.join(', ')}.")
    div << XMLNamedText.new('TaskJuggler', 'a', 'href' => AppConfig.contact)
    div << XMLText.new(' is a trademark of Chris Schlaeger.')

  end

end

AppConfig.appName = 'UserManual'
man = UserManual.new
files = %w( Intro How_To_Contribute Reporting_Bugs Installation
            Getting_Started Tutorial Day_To_Day_Juggling )
files.each do |file|
  man.addSnip('../manual/' + file)
end
man.generateHTML('../data/manual/')

