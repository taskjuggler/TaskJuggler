#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_CSV-Reports.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
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

require 'MessageChecker'
require 'taskjuggler/TaskJuggler'
require 'taskjuggler/reports/CSVFile'
require 'taskjuggler/AlgorithmDiff'

class TestScheduler < Test::Unit::TestCase

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
    ensure
      $stdout = oldStdOut
    end
  end

  # Compare the output CSV (passed as String) with the content of the CSV
  # reference files _refFile_.
  def compareCSVs(outStr, refFile)
    refStr = File.new(refFile, 'r').read

    diff = refStr.extend(DiffableString).diff(outStr).to_s
    if diff != ''
      puts diff
      File.new('failed.csv', 'w').write(outStr)

      ref = TaskJuggler::CSVFile.new.parse(refStr)
      out = TaskJuggler::CSVFile.new.parse(outStr)

      assert(ref.length == out.length,
             "Line number mismatch (#{out.length} instead of #{ref.length}) " +
             "in #{refFile}")
      0.upto(ref.length - 1) do |line|
        refLine = ref[line]
        outLine = out[line]
        assert(refLine.length == outLine.length,
               "Line #{line} size mismatch (#{outLine.length} instead of " +
               "#{refLine.length}) in #{refFile}")
        0.upto(refLine.length - 1) do |cell|
          assert(refLine[cell] == outLine[cell],
                 "Cell #{cell} of line #{line} mismatch: " +
                 "'#{outLine[cell]}' instead of '#{refLine[cell]}' " +
                 "in #{refFile}")
        end
      end
    end
  end

  def checkCSVReport(projectFile)
    baseDir = File.dirname(projectFile)
    baseName = File.basename(projectFile, '.tjp')
    # The reference files must have the same base name as the project file but
    # they need to be in the ./refs/ directory relative to the project file.
    refFile = baseDir + "/refs/#{baseName}.csv"

    tj = TaskJuggler.new(true)
    assert(tj.parse([ projectFile ]), "Parser failed for #{projectFile}")
    assert(tj.schedule, "Scheduler failed for #{projectFile}")
    if File.file?(refFile)
      # If there is a reference CSV file for this test case, compare the
      # output against it.
      out = captureStdout do
        assert(tj.generateReports(baseDir),
               "Report generation failed for #{projectFile}")
      end
      compareCSVs(out, refFile)
    else
      # If not, we generate the reference file.
      puts "refFile: #{refFile}"
      stdoutToFile(refFile) do
        assert(tj.generateReports,
               "Reference file generation failed for #{projectFile}")
      end
    end
    assert(tj.messageHandler.messages.empty?,
           "Unexpected error in #{projectFile}")
  end

  def test_CSV_Reports
    path = File.dirname(__FILE__)

    testDir = path + '/TestSuite/CSV-Reports/'
    Dir.glob(testDir + '*.tjp').each do |f|
      TaskJuggler::TjTime.setTimeZone('Europe/Berlin')
      checkCSVReport(f)
    end
  end

end
