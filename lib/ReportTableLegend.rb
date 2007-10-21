#
# ReportLegend.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class ReportTableLegend

  def initialize
  end

  def to_html
    table = XMLElement.new('table', 'width' => '100%', 'border' => '0',
                           'cellpadding' => '2', 'cellspacing' => '1')
    table << XMLBlob.new(<<'EOT'
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
    <td width="10%" align="center">
EOT
        )
    container = GanttContainer.new(nil, 0, 15, 5, 35, 0)
    table << (div = XMLElement.new('div',
      'style' => 'position:relative; width:40px; height:15px;'))
    div << container.to_html

    table << XMLBlob.new(<<'EOT'
    </td>
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
    <td align="center">
EOT
        )
    taskBar = GanttTaskBar.new(nil, 0, 15, 5, 35, 0)
    table << (div = XMLElement.new('div',
      'style' => 'position:relative; width:40px; height:15px;'))
    div << taskBar.to_html

    table << XMLBlob.new(<<'EOT'
    </td>
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
    <td align="center">
EOT
        )
    milestone = GanttMilestone.new(nil, 15, 10, 0)
    table << (div = XMLElement.new('div',
      'style' => 'position:relative; width:20px; height:15px;'))
    div << milestone.to_html
    table << XMLBlob.new(<<'EOT'
    </td>
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
EOT
        )
    table
  end

end
