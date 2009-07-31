#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_CSV-Reports.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
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
require 'reports/CSVFile'
require 'MessageChecker'


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
    ref = []
    TaskJuggler::CSVFile.new(ref).read(refFile)

    out = []
    TaskJuggler::CSVFile.new(out).parse(outStr)
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
               "'#{outLine[cell]}' instead of '#{refLine[cell]}' in #{refFile}")
      end
    end
  end

  def test_CSV_Reports
    path = File.dirname(__FILE__)

    Dir.glob(path + 'TestSuite/CSV-Reports/*.tjp').each do |f|
      baseName = f[22 + path.length, f.length - (path.length + 26)]
      refFile = path + "TestSuite/CSV-Reports/#{baseName}-Reference.csv"
      tj = TaskJuggler.new(true)
      assert(tj.parse([ f ]), "Parser failed for #{f}")
      assert(tj.schedule, "Scheduler failed for #{f}")
      if File.file?(refFile)
        # If there is a reference CSV file for this test case, compare the
        # output against it.
        out = captureStdout do
          assert(tj.generateReports, "Report generation failed for #{f}")
        end
        compareCSVs(out, refFile)
      else
        # If not, we generate the reference file.
        stdoutToFile(refFile) do
          assert(tj.generateReports,
                 "Reference file generation failed for #{f}")
        end
      end
      assert(tj.messageHandler.messages.empty?, "Unexpected error in #{f}")
    end
  end

end
