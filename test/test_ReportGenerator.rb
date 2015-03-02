#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_ReportGenerator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0
$:.unshift File.dirname(__FILE__)

require 'test/unit'
require 'fileutils'

require 'MessageChecker'
require 'taskjuggler/Tj3Config'
require 'taskjuggler/TaskJuggler'

class TestReportGenerator < Test::Unit::TestCase

  include MessageChecker

  def setup
    @tmpDir = 'tmp-test_ReportGenerator'
    Dir.delete(@tmpDir) if File.directory?(@tmpDir)
    Dir.mkdir(@tmpDir)
    AppConfig.appName = 'taskjuggler3'
    ENV['TASKJUGGLER_DATA_PATH'] = './:../'
  end

  def teardown
    FileUtils::rm_rf(@tmpDir)
  end

  def test_ReportGeneratorErrors
    path = File.dirname(__FILE__) + '/'
    Dir.glob(path + 'TestSuite/ReportGenerator/Errors/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      (mh = TaskJuggler::MessageHandlerInstance.instance).reset
      mh.outputLevel = :none
      mh.trapSetup = true
      begin
        tj = TaskJuggler.new
        assert(tj.parse([ f ]), "Parser failed for #{f}")
        assert(tj.schedule, "Scheduler failed for #{f}")
        tj.warnTsDeltas = true
        tj.generateReports(@tmpDir)
      rescue TaskJuggler::TjRuntimeError
      end
      checkMessages(tj, f)
    end
  end

  def test_ReportGeneratorCorrect
    path = File.dirname(__FILE__) + '/'
    Dir.glob(path + 'TestSuite/ReportGenerator/Correct/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      (mh = TaskJuggler::MessageHandlerInstance.instance).reset
      mh.outputLevel = :none
      tj = TaskJuggler.new
      assert(tj.parse([ f ]), "Parser failed for #{f}")
      assert(tj.schedule, "Scheduler failed for #{f}")
      assert(tj.generateReports(@tmpDir), "Report generator failed for #{f}")
      assert(mh.messages.empty?, "Unexpected error in #{f}")

      checkReports(f)
    end
  end

  private

  def checkReports(tjpFile)
    baseName = File.basename(tjpFile)[0..-5]
    dirName = File.dirname(tjpFile)

    counter = 0
    Dir.glob(dirName + "/refs/#{baseName}-[0-9]*").each do |ref|
      reportName = File.basename(ref)
      assert(FileUtils.compare_file(ref, "#{@tmpDir}/#{reportName}"),
             "Comparison of report #{reportName} of test case #{tjpFile} failed")
      counter += 1
    end
    assert(counter > 0, "Project #{tjpFile} has no reference report")
  end

end
