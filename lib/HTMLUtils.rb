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

require 'Tj3Config.rb'

module HTMLUtils

  def htmlFilter(text)
    out = ''
    text.each_byte do |c|
      case c
      when ?<
        out << '&lt;'
      when ?>
        out << '&gt;'
      else
        out << c
      end
    end
    out
  end

  def generateHeader
    @file << <<'EOT'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
 "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
  <title>Task Report</title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <style type="text/css">
    .tabback { background-color:#9a9a9a }
    .tabfront { background-color:#d4dde6 }
    .tabhead {
      background-color:#7a7a7a;
      color:#ffffff;
      font-size:110%;
      font-weight:bold;
      text-align:center;
    }
    .tabhead_offduty {
      background-color:#dde375;
      color:#000000;
    }
    .tabfooter {
      background-color:#9a9a9a;
      color:#ffffff;
      font-size:50%;
      text-align:center;
    }
    .taskcell1 { background-color:#ebf2ff }
    .taskcell2 { background-color:#d9dfeb }
    .resourcecell1 { background-color:#fff2eb }
    .resourcecell2 { background-color:#ebdfd9 }
    .busy1 { background-color:#ff3b3b }
    .busy2 { background-color:#eb4545 }
    .loaded1 { background-color:#ff9b9b }
    .loaded2 { background-color:#eb8f8f }
    .free1 { background-color:#a5ffb4 }
    .free2 { background-color:#98eba6 }
    .offduty1 { background-color:#f3f990 }
    .offduty2 { background-color:#dde375 }
    .done1 { background-color:#abbeae }
    .done2 { background-color:#99aa9c }
    .todo1 { background-color:#beabab }
    .todo2 { background-color:#aa9999 }
  </style>
</head>
<body>
<table summary="Outer table" cellspacing="2" border="0" cellpadding="0"
       align="center" class="tabback">
EOT
    if @element.headline
      @file << <<'EOT'
  <thead>
    <tr><td>
      <table summary="headline" cellspacing="1" border="0" cellpadding="0"
             align="center" width="100%">
        <tr><td align="center" style="font-size: 130%" class="tabfront">
EOT

    @file << "<p>" << htmlFilter(@element.headline) << "</p>\n"

        @file << <<'EOT'
        </td></tr>
      </table>
    </td></tr>
  </thead>
EOT
    end

    @file << <<'EOT'
  <tbody>
    <tr><td>
EOT

  end

  def generateFooter
    @file << "    </td></tr>\n    <tr><td style=\"font-size:70%\">\n"

    generateLegend

    @file << <<'EOT'
    </td></tr>
    <tr><td class="tabfooter">
EOT

    @file << htmlFilter(@project['copyright']) + " - " if @project['copyright']
    @file << "Project: #{htmlFilter(@project['name'])} " +
             "Version: #{htmlFilter(@project['version'])} - " +
             "Created on #{TjTime.now.to_s("%Y-%m-%d %H:%M:%S")} with " +
             "<a href=\"#{AppConfig.contact}\">#{AppConfig.packageName}</a> " +
             " v#{AppConfig.version}"

    @file << <<'EOT'
    </td></tr>
  </tbody>
</table>
</body></html>
EOT

  end

private

  def generateLegend
    @file << <<'EOT'
<table summary="Legend" width="100%" align="center" border="0" cellpadding="2"
       cellspacing="1">
  <thead>
    <tr><td colspan="8"></td></tr>
    <tr class="tabfront">
<!--      <td class="tabback"></td> -->
      <td align="center" width="33%" colspan="2"><b>Gantt Symbols</b></td>
      <td class="tabback"></td>
      <td align="center" width="33%" colspan="2"><b>Task Colors</b></td>
      <td class="tabback"></td>
      <td align="center" width="33%" colspan="2"><b>Resource Colors</b></td>
<!--      <td class="tabback"></td> -->
    </tr>
  </thead>
  <tbody>
    <tr class="tabfront">
<!--    <td class="tabback"></td> -->
    <td width="23%">Container Task</td>
    <td width="10%" align="center"><b>v--------v</b></td>
    <td class="tabback"></td>
    <td width="23%">Completed Work</td>
    <td width="10%" class="done1"></td>
    <td class="tabback"></td>
    <td width="23%">Free</td>
    <td width="10%" class="free1"></td>
<!--    <td class="tabback"></td> -->
  </tr>
  <tr class="tabfront">
<!--    <td class="tabback"></td> -->
    <td>Normal Task</td>
    <td align="center">[======]</td>
    <td class="tabback"></td>
    <td>Incomplete Work</td>
    <td class="todo1"></td>
    <td class="tabback"></td>
    <td>Partially Loaded</td>
    <td class="loaded1"></td>
<!--    <td class="tabback"></td> -->
  </tr>
  <tr class="tabfront">
<!--    <td class="tabback"></td> -->
    <td>Milestone</td>
    <td align="center"><b>&lt;&gt;</b></td>
    <td class="tabback"></td>
    <td>Vacation</td>
    <td class="offduty1"></td>
    <td class="tabback"></td>
    <td>Fully Loaded</td>
    <td class="busy1"></td>
<!--    <td class="tabback"></td> -->
  </tr>
  <tr><td colspan="8"></td></tr>
  </tbody>
</table>
EOT

  end

end

