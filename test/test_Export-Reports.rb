#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Export-Reports.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0
$:.unshift File.dirname(__FILE__)

require 'stringio'
require 'test/unit'
require 'TaskJuggler'
require 'MessageChecker'
require 'AlgorithmDiff'

class TestExportReport < Test::Unit::TestCase

  include MessageChecker

  # This function captures the $stdout output of the passed block to a String
  # and returns it.
  def captureStdout
    oldStdOut = $stdout
    $stdout = (out = StringIO.new)
    begin
      yield
    ensure
      $stdout = oldStdOut
    end
    out.string
  end

  # This functions redirects all output of the passed block to a new file with
  # the name fileName.
  def stdoutToFile(fileName)
    oldStdOut = $stdout
    $stdout = File.open(fileName, 'w')
    begin
      yield
      $stdout.close
    ensure
      $stdout = oldStdOut
    end
  end

  # Compare the output Export (passed as String in _out_) with the content of
  # the Export reference files _refFile_.
  def compareExports(out, refFile, testCase)
    ref = File.new(refFile, 'r').read

    diff = ref.extend(DiffableString).diff(out).to_s
    if diff != ''
      File.new('failed.tjp', 'w').write(out)
    end
    assert_equal('', diff, "output for #{testCase} does not match " +
                 "#{refFile}:\n#{diff}")
  end

  def checkExportReport(projectFile, repFile, refFile)
    tj = TaskJuggler.new(true)
    assert(tj.parse([ projectFile, repFile ]),
           "Parser failed for #{projectFile}")

    # Schedule the project.
    assert(tj.schedule, "Scheduler failed for #{projectFile}")

    tj.project.reports.each do |report|
      next unless report.get('formats').include?(:tjp)

      if File.file?(refFile)
        # If there is a reference Export file for this test case, compare the
        # output against it.
        out = captureStdout do
          assert(tj.generateReport(report.fullId, false),
                 "Report generation failed for #{projectFile}")
        end
        compareExports(out, refFile, projectFile)
      else
        # If not, we generate the reference file.
        stdoutToFile(refFile) do
          assert(tj.generateReport(report.fullId, false),
                 "Reference file generation failed for #{projectFile}")
        end
      end
    end
    assert(tj.messageHandler.messages.empty?,
           "Unexpected error in #{projectFile}")
  end

  def test_Export_Reports
    path = File.dirname(__FILE__)

    testDir = path + '/TestSuite/Syntax/Correct/'
    Dir.glob(testDir + '*.tjp').each do |f|
      # We ignore some test cases that cannot work in this setup.
      next if %w( Freeze.tjp Export.tjp ).include?(f[testDir.length..-1])

      # Take the project, schedule it, check it against the reference and
      # export it. Then check the export against the reference file.

      refFile = refFileName(f)
      repFile = reportDefFileName(f)
      checkExportReport(f, repFile, refFile)
      checkExportReport(refFile, repFile, refFile)
    end
    TaskJuggler::TjTime.setTimeZone(nil)
  end

  private

  def refFileName(originalFile)
    baseDir = File.dirname(originalFile)
    baseName = File.basename(originalFile, '.tjp')
    baseDir + "/../../Export-Reports/refs/#{baseName}.tjp"
  end

  def reportDefFileName(originalFile)
    File.dirname(originalFile) + "/../../Export-Reports/export.tji"
  end

end
