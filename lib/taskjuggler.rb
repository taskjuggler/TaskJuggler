#
# taskjuggler.rb - TaskJuggler
#
# Copyright (c) 2006 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#
require 'Project'

prj = Project.new("test", "Test", "1.0")
prj["start"] = TjTime.new((TjTime.now.to_i / 3600) * 3600)
prj["end"] = TjTime.now + 200000000

r0 = Resource.new(prj, 'r0', 'Resource 0', nil)

t0 = Task.new(prj, 't0', 'Task 0', nil)
t0['start', 0] = TjTime.new((TjTime.now.to_i / 3600) * 3600)
t0['duration', 0] = 10

prevTask = 0
1.upto(10) do |i|
  t = Task.new(prj, "t#{i}", "Task #{i}", nil)
  t['effort', 0] = 10
  t['depends', 0] = [ TaskDependency.new("t#{prevTask}") ]
  t['allocate', 0] = [ Allocation.new([ r0 ]) ]
  prevTask = i
end

ExportReport.new(prj, "TestProject.tjp")
taskReport = HTMLTaskReport.new(prj, "TaskReport.html")
element = ReportElement.new(taskReport)
element.columns = %w( name start end )

prj.scheduleAllScenarios

prj.generateReports

lastTask = prj.task("t#{prevTask}")
puts lastTask.to_s
printf("End: %s\n", prj.task("t#{prevTask}")['end', 0])

