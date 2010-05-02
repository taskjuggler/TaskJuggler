#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LogFile.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'singleton'

class TaskJuggler

  class LogFile

    attr_accessor :logFile, :appName, :outputLevel, :logLevel

    include Singleton

    def initialize
      @logFile = 'logfile'
      @appName = 'undefined'
      @logLevel = 3
      @outputLevel = 3
    end

    def debug(message)
      $stderr.puts message if @outputLevel >= 4
      log('DEBUG', message) if @logLevel >= 4
    end

    def info(message)
      $stderr.puts message if @outputLevel >= 3
      log('INFO', message) if @logLevel >= 3
    end

    def warning(message)
      $stderr.puts message if @outputLevel >= 2
      log('WARN', message) if @logLevel >= 2
    end

    def error(message)
      $stderr.puts message if @outputLevel >= 1
      log("ERROR", message) if @logLevel >= 1
    end

    def fatal(message)
      $stderr.puts message if @outputLevel >= 0
      log("FATAL", message) if @logLevel >= 0
      exit 1
    end

    def log(type, message)
      timeStamp = Time.new.strftime("%Y-%m-%d %H:%M:%S")
      begin
        @logFile.untaint
        File.open(@logFile, 'a') do |f|
          f.write("#{timeStamp} #{type} #{@appName}[#{Process.pid}]: " +
                  "#{message}\n")
        end
      rescue
        $stderr.puts "Cannot write to log file #{@logFile}: #{$!}"
      end
    end

  end

end

