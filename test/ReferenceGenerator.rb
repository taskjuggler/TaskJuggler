#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ReferenceGenerator.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This script can be used to (re-)generate all reference reports in the
# TaskJuggler test suite. These reports will be put in the /refs directories
# in the TestSuite sub-directories. Usually, reference reports are generated
# by hand and then manually checked for correctness before they are added to
# the test suite. But sometimes changes in the syntax will require all
# reference files to be regenerated.
# Reference reports must use the following naming scheme:
# <test case name>-[0-9]+.(csv|html)

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0
$:.unshift File.dirname(__FILE__)

require 'fileutils'
require 'Tj3Config'
require 'TaskJuggler'

class TaskJuggler

  class ReferenceGenerator

    def initialize
      AppConfig.appName = 'taskjuggler3'
      ENV['TASKJUGGLER_DATA_PATH'] = './:../'
      ENV['TZ'] = 'Europe/Berlin'
    end

    def generate
      processDirectory('ReportGenerator/Correct')
    end

    private

    def processProject(tjpFile, outputDir)
      deleteOldReports(tjpFile[0..-5])

      puts "Generating references for #{tjpFile}"
      tj = TaskJuggler.new(true)
      tj.parse([ tjpFile ]) || error("Parser failed for ${tjpFile}")
      tj.schedule || error("Scheduler failed for #{tjpFile}")
      tj.generateReports(outputDir) ||
        error("Report generator failed for #{tjpFile}")
      unless tj.messageHandler.messages.empty?
        error("Unexpected error in #{tjpFile}")
      end
    end

    def processDirectory(dir)
      puts "Generating references in #{dir}"
      path = File.dirname(__FILE__) + '/'
      projectDir = path + "TestSuite/#{dir}/"
      outputDir = path + "TestSuite/#{dir}/refs/"

      Dir.glob(projectDir + '*.tjp').each do |f|
        processProject(f, outputDir)
      end
    end

    def deleteOldReports(basename)
      %w( .csv .html ).each do |ext|
        Dir.glob(basename + "-[0-9]*" + ext).each do |f|
          puts "Removing old report #{f}"
          File.delete(f)
        end
      end
    end

    def error(text)
      $stderr.puts text
      exit 1
    end

  end

  ReferenceGenerator.new.generate

end

