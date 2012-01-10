#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjpGen.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'taskjuggler/TjTime'

class TjpGen

  def initialize(fileName = 'test.tjp', seed = 12345, tasks = 100,
                 resources = 15)
    @fileName = fileName
    srand(seed)
    @tasks = tasks
    @resources = resources

    @start = TjTime.local(2000, 1, 1) + rand(365 * 5) * (60 * 60 * 24)
    @resourceList = []
    @taskList = []

    @depTargets = []
  end

  def generate
    File.open(@fileName, "w") do |f|
      f.puts "project test \"Test\" \"1.0\" #{@start} +270d"
      begin
        genResource(f, 0)
      end while @resourceList.length < @resources
      begin
        genTask(f, 0, '', [])
      end while @taskList.length < @tasks

      #genReports(f)
    end
  end

private

  def genResource(f, level)
    id = "r#{@resourceList.length}"
    indent = ' ' * 2 * level
    f.puts "#{indent}resource #{id} \"Resource #{@resourceList.length}\" {"
    @resourceList << id
    if rand(10) < 2
      genResource(f, level + 1)
    end
    f.puts "#{indent}}"
  end

  def genTask(f, level, parent, brothers)
    id = "t#{@taskList.length}"
    fullId = parent + id
    indent = ' ' * 2 * level
    f.puts "#{indent}task #{id} \"Task #{@taskList.length}\" {"
    @taskList << fullId

    if rand(10) < 1
      f.puts "#{indent}  priority #{(rand(9) + 1) * 100}"
    end
    if level == 0
      f.puts "#{indent}  start #{@start + (60 * 60 * rand(@taskList.length))}"
    end

    children = []
    if (level <= (Math.log10(@tasks) * 2) && rand(10) < 6)
      0.upto(rand(1 + level)) do |i|
        children << genTask(f, level + 1, fullId + '.', children)
      end
    end

    if children.empty?
      wof = rand(100)
      milestone = false
      if wof < 10
        f.puts "#{indent}  milestone"
        milestone = true
      elsif wof < 70
        f.puts "#{indent}  effort #{1 + rand(60)}h"
        genAllocate(f, indent)
      elsif wof < 80
        f.puts "#{indent}  length #{1 + rand(80)}h"
        genAllocate(f, indent) if rand(5) < 2
      else
        f.puts "#{indent}  duration #{1 + rand(200)}h"
        genAllocate(f, indent) if rand(5) < 1
      end

      if @depTargets.empty? || rand(10) < 1 || level == 0
        f.puts "#{indent}  start #{@start + rand(20) * (60 * 60 * 24)}"
      else
        deps = []
        if rand(5) < 1
          depList = @depTargets
        else
          depList = brothers
        end
        while !depList.empty? && rand(100) < (milestone ? 60 : 30)
          dep = depList[rand(depList.length)]
          deps << dep unless deps.include?(dep)
        end
        f.puts "#{indent}  depends #{deps.join(', ')}" unless deps.empty?
      end
    end
    if level > 0 && rand(10) < 3
      @depTargets << fullId
    end
    f.puts "#{indent}}"

    fullId
  end

  def genAllocate(f, indent)
    res = []
    res << @resourceList[rand(@resourceList.length)]
    while rand(10) < 2
      r = @resourceList[rand(@resourceList.length)]
      res << r unless res.include?(r)
    end
    f.puts "#{indent}  allocate #{res.join(', ')}"
  end

  def genReports(f)
    f.puts "taskreport \"Tasks\" {"
    f.puts "  columns no, name, start, end, chart"
    f.puts "}"

    f.puts "resourcereport \"Resources\" {"
    f.puts "  columns no, name, effort, utilization, chart"
    f.puts "}"
  end

end

fileName = ARGV[0] ? ARGV[0] : 'test.tjp'
seed = ARGV[1] ? ARGV[1].to_i : 12345
tasks = ARGV[2] ? ARGV[2].to_i : 100
resources = 1 + (tasks / 21.0).to_i

gtor = TjpGen.new(fileName, seed, tasks, resources)
gtor.generate

