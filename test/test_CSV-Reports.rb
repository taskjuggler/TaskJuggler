#
# test_CSV-Reports.rb - TaskJuggler
#
# Copyright (c) 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'stringio'
require 'csv'
require 'test/unit'
require 'TaskJuggler'
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
    CSV.foreach(refFile, { :col_sep => ';' }) do |row|
      ref << row
    end

    out = []
    CSV.parse(outStr, { :col_sep => ';' }) do |row|
      out << row
    end
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
    Dir.glob('TestSuite/CSV-Reports/*.tjp').each do |f|
      baseName = f[22, f.length - 26]
      refFile = "TestSuite/CSV-Reports/#{baseName}-Reference.csv"
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
