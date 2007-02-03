#
# HTMLUtils.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

module HTMLUtils

  def htmlFilter(text)
    # TODO: Implement HTML sanitizer
    text
  end

  def generateHeader
    @file << <<END_OF_TEXT
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
"http://www.w3.org/TR/REC-html40/loose.dtd">
<html>
<head>
  <title>Task Report</title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <style type="text/css">
    .tab { background-color:#4486ac }
    .tabhead { background-color:#8fd0f6; font-size:110%; font-weight:bold;
               text-align:center }
    .tabline1 { background-color:#d3eefd}
    .tabline2 { background-color:#dff1fb}
    .tabcell { }
  </style>
</head>
<body>
END_OF_TEXT

  end

  def generateFooter
    @file << "<p align=\"center\"><span style=\"font-size:0.7em\">"
    @file << htmlFilter(@project['copyright']) + " - " if @project['copyright']
    @file << "Version " + htmlFilter(@project['version']) + " - " +
             "Created on #{TjTime.now.to_s("%Y-%m-%d %H:%M:%S")} with " +
             "<a href=\"http://www.taskjuggler.org\">TaskJuggler</a> " +
             "</span></p>"
    @file << "</body></html>\n"
  end

end

