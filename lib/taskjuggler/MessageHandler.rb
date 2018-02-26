#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MessageHandler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

if RUBY_VERSION < "1.9.0"
  require 'rubygems'
end

require 'singleton'
require 'term/ansicolor'
require 'taskjuggler/TextParser/SourceFileInfo'

class TaskJuggler

  class TjRuntimeError < RuntimeError
  end

  # The Message object can store several classes of messages that the
  # application can send out.
  class Message

    include Term::ANSIColor

    attr_reader :type, :id, :message, :line
    attr_accessor :sourceFileInfo

    # Create a new Message object.  The _type_ specifies what tpye of message
    # this is. The following types are supported: fatal, error, warning, info
    # and debug. _id_ is a String that must uniquely identify the source of
    # the Message. _message_ is a String with the actual message.
    # _sourceLineInfo_ is a SourceLineInfo object that can reference a
    # location in a specific file. _line_ is a String of that file. _data_ can
    # be any context sensitive data. _sceneario_ specifies the Scenario in
    # which the message originated.
    def initialize(type, id, message, sourceFileInfo, line, data, scenario)
      unless [ :fatal, :error, :warning, :info, :debug ].
             include?(type)
        raise "Unknown message type: #{type}"
      end
      @type = type

      @id = id

      if message && !message.is_a?(String)
        raise "String object expected as message but got #{message.class}"
      end
      @message = message

      if sourceFileInfo && !sourceFileInfo.is_a?(TextParser::SourceFileInfo)
        raise "SourceFileInfo object expected but got #{sourceFileInfo.class}"
      end
      @sourceFileInfo = sourceFileInfo

      if line && !line.is_a?(String)
        raise "String object expected as line but got #{line.class}"
      end
      @line = line

      @data = data

      if scenario && !scenario.is_a?(Scenario)
        raise "Scenario object expected by got #{scenario.class}"
      end
      @scenario = scenario
    end

    # Convert the Message into a String that can be printed to the console.
    def to_s
      str = ""
      # The SourceFileInfo is printed as <fileName>:line:
      if @sourceFileInfo
        str += "#{@sourceFileInfo.fileName}:#{sourceFileInfo.lineNo}: "
      end
      if @scenario
        tag = "#{@type.to_s.capitalize} in scenario #{@scenario.id}: "
      else
        tag = "#{@type.to_s.capitalize}: "
      end
      colors = { :fatal => red, :error => red, :warning => magenta,
                 :info => blue, :debug => green }
      str += colors[@type] + tag + @message + reset
      str += "\n" + @line if @line
      str
    end

    # Convert the Message into a String that can be stored in a log file.
    def to_log
      str = ""
      # The SourceFileInfo is printed as <fileName>:line:
      if @sourceFileInfo
        str += "#{@sourceFileInfo.fileName}:#{sourceFileInfo.lineNo}: "
      end
      str += "Scenario #{@scenario.id}: " if @scenario
      str += @message
      str
    end

  end

  # The MessageHandler can display and store application messages. Depending
  # on the type of the message, a TjExeption can be raised (:error), or the
  # program can be immedidately aborted (:fatal). Other types will just
  # continue the program flow.
  class MessageHandlerInstance

    include Singleton

    attr_reader :messages, :errors
    attr_accessor :logFile, :appName, :abortOnWarning

    LogLevels = { :none => 0, :fatal => 1, :error => 2, :critical => 2,
                  :warning => 3, :info => 4, :debug => 5 }

    # Initialize the MessageHandler.
    def initialize
      reset
    end

    # Reset the MessageHandler to the initial state. All messages will be
    # purged and the error counter set to 0.
    def reset
      # This setting controls what type of messages will be written to the
      # console.
      @outputLevel = 4
      # This setting controls what type of messages will be written to the log
      # file.
      @logLevel = 3
      # The full file name of the log file.
      @logFile = nil
      # Toggle if scenario ids are included in the messages or not.
      @hideScenario = true
      # The name of the current application
      @appName = 'unknown'
      # Set to true if program should be exited on warnings.
      @abortOnWarning = false
      # A SourceFileInfo object that will be used to baseline the provided
      # source file infos of the messages. We use a Hash to keep per Thread
      # values.
      @baselineSFI = {}
      # Each tread can request to only throw a TjRuntimeError instead of
      # using exit(). This hash keeps a flag for each thread using the
      # object_id of the Thread object as key.
      @trapSetup = {}

      clear
    end

    def baselineSFI=(line)
      @baselineSFI[Thread.current.object_id] = line
    end

    def trapSetup=(enable)
      @trapSetup[Thread.current.object_id] = enable
    end

    # Clear the error log.
    def clear
      # A counter for messages of type error.
      @errors = 0
      # A list of all generated messages.
      @messages = []
    end

    # Set the console output level.
    def outputLevel=(level)
      @outputLevel = checkLevel(level)
    end

    # Set the log output level.
    def logLevel=(level)
      @logLevel = checkLevel(level)
    end

    def hideScenario=(yesNo)
      @hideScenario = yesNo
    end

    # Generate a fatal message that will abort the application.
    def fatal(id, message, sourceFileInfo = nil, line = nil, data = nil,
              scenario = nil)
      addMessage(:fatal, id, message, sourceFileInfo, line, data, scenario)
    end

    # Generate an error message.
    def error(id, message, sourceFileInfo = nil, line = nil, data = nil,
              scenario = nil)
      addMessage(:error, id, message, sourceFileInfo, line, data, scenario)
    end

    # Generate an critical message.
    def critical(id, message, sourceFileInfo = nil, line = nil, data = nil,
                 scenario = nil)
      addMessage(:critical, id, message, sourceFileInfo, line, data, scenario)
    end

    # Generate a warning.
    def warning(id, message, sourceFileInfo = nil, line = nil, data = nil,
                scenario = nil)
      addMessage(:warning, id, message, sourceFileInfo, line, data, scenario)
    end

    # Generate an info message.
    def info(id, message, sourceFileInfo = nil, line = nil, data = nil,
             scenario = nil)
      addMessage(:info, id, message, sourceFileInfo, line, data, scenario)
    end

    # Generate a debug message.
    def debug(id, message, sourceFileInfo = nil, line = nil, data = nil,
              scenario = nil)
      addMessage(:debug, id, message, sourceFileInfo, line, data, scenario)
    end

    # Convert all messages into a single String.
    def to_s
      text = ''
      @messages.each { |msg| text += msg.to_s }
      text
    end

    private

    def checkLevel(level)
      if level.is_a?(Integer)
        if level < 0 || level > 5
          raise ArgumentError, "Unsupported level #{level}"
        end
      else
        unless (level = LogLevels[level])
          raise ArgumentError, "Unsupported level #{level}"
        end
      end

      level
    end

    def log(type, message)
      return unless @logFile

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

    # Generate a message by specifying the _type_.
    def addMessage(type, id, message, sourceFileInfo = nil, line = nil,
                   data = nil, scenario = nil)
      # If we have a SourceFileInfo and a baseline SFI, we correct the
      # sourceFileInfo accordingly.
      baselineSFI = @baselineSFI[Thread.current.object_id]
      if sourceFileInfo && baselineSFI
        sourceFileInfo = TextParser::SourceFileInfo.new(
          baselineSFI.fileName, sourceFileInfo.lineNo + baselineSFI.lineNo - 1,
          sourceFileInfo.columnNo)
      end

      # Treat criticals like errors but without generating another
      # exception.
      msg = Message.new(type == :critical ? :error : type, id, message,
                        sourceFileInfo, line, data,
                        @hideScenario ? nil : scenario)
      @messages << msg

      # Append the message to the log file if requested by the user.
      log(type, msg.to_log) if @logLevel >= LogLevels[type]

      # Print the message to $stderr if requested by the user.
      $stderr.puts msg.to_s if @outputLevel >= LogLevels[type]

      case type
      when :warning
        raise TjException.new, '' if @abortOnWarning
      when :critical
        # Increase the error counter.
        @errors += 1
      when :error
        # Increase the error counter.
        @errors += 1
        if @trapSetup[Thread.current.object_id]
          raise TjRuntimeError
        else
          exit 1
        end
      when :fatal
        raise RuntimeError
      end
    end

  end

  module MessageHandler

    # Generate a fatal message that will abort the application.
    def fatal(id, message, sourceFileInfo = nil, line = nil, data = nil,
              scenario = nil)
      MessageHandlerInstance.instance.fatal(id, message, sourceFileInfo, line,
                                            data, scenario)
    end

    # Generate an error message.
    def error(id, message, sourceFileInfo = nil, line = nil, data = nil,
              scenario = nil)
      MessageHandlerInstance.instance.error(id, message, sourceFileInfo, line,
                                            data, scenario)
    end

    # Generate an critical message.
    def critical(id, message, sourceFileInfo = nil, line = nil, data = nil,
                 scenario = nil)
      MessageHandlerInstance.instance.critical(id, message, sourceFileInfo,
                                               line, data, scenario)
    end

    # Generate a warning.
    def warning(id, message, sourceFileInfo = nil, line = nil, data = nil,
                scenario = nil)
      MessageHandlerInstance.instance.warning(id, message, sourceFileInfo,
                                              line, data, scenario)
    end

    # Generate an info message.
    def info(id, message, sourceFileInfo = nil, line = nil, data = nil,
             scenario = nil)
      MessageHandlerInstance.instance.info(id, message, sourceFileInfo, line,
                                           data, scenario)
    end

    # Generate a debug message.
    def debug(id, message, sourceFileInfo = nil, line = nil, data = nil,
              scenario = nil)
      MessageHandlerInstance.instance.debug(id, message, sourceFileInfo, line,
                                            data, scenario)
    end

  end

end

