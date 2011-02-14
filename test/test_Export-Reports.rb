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
    ensure
      $stdout = oldStdOut
    end
  end

  # Compare the output Export (passed as String in _out_) with the content of
  # the Export reference files _refFile_.
  def compareExports(out, refFile)
    ref = File.new(refFile, 'r').read

    refLines = ref.split("\n")
    outLines = out.split("\n")
    assert(refLines.length == outLines.length,
           "Line number mismatch (#{outLines.length} instead of " +
           "#{refLines.length}) in #{refFile}")
    refLines.length.times do |line|
      refLine = refLines[line]
      outLine = outLines[line]
      assert(refLine == outLine,
             "#{refFile} line #{line + 1} mismatch:\n#{outLine}\ninstead of\n" +
             "#{refLine}")
    end
  end

  def checkExportReport(projectFile)
    refFile = refFileName(projectFile)

    tj = TaskJuggler.new(true)
    assert(tj.parse([ projectFile ]), "Parser failed for #{projectFile}")
    assert(tj.schedule, "Scheduler failed for #{projectFile}")
    if File.file?(refFile)
      # If there is a reference Export file for this test case, compare the
      # output against it.
      out = captureStdout do
        assert(tj.generateReports(File.dirname(projectFile)),
               "Report generation failed for #{projectFile}")
      end
      compareExports(out, refFile)

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

  def test_Export_Reports
    path = File.dirname(__FILE__)

    testDir = path + '/TestSuite/Export-Reports/'
    Dir.glob(testDir + '*.tjp').each do |f|
      # Take the project, schedule it, check it against the reference and
      # export it.
      checkExportReport(f)

      # Take the exported project, schedule it and check it against the
      # reference.
      stage1File = stage1FileName(f)
      generateStage1File(refFileName(f), stage1File)

      checkExportReport(stage1File)

      # Remove the stage 1 project again.
      File.delete(stage1File)
    end
  end

  private

  def generateStage1File(originalFile, stage1File)
    out = File.new(originalFile, 'r').read
    out += <<"EOF"

export "." {
  definitions *
  taskattributes *
  resourceattributes *
}
EOF
    File.new(stage1File, 'w').write(out)
  end

  def refFileName(originalFile)
    baseDir = File.dirname(originalFile)
    suffix = originalFile[-11..-1] == '-stage1.tjp' ? '-stage1.tjp' : '.tjp'
    baseName = File.basename(originalFile, suffix)
    # The reference files must have the same base name as the project file but
    # they need to be in the ./refs/ directory relative to the project file.
    baseDir + "/refs/#{baseName}.tjp"
  end

  def stage1FileName(originalFile)
    originalFile[0..-5] + '-stage1.tjp'
  end

end
