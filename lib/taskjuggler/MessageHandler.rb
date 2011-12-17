#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MessageHandler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'term/ansicolor'
require 'taskjuggler/TextParser/SourceFileInfo'

class TaskJuggler

  # The Message object can store several classes of messages that the
  # application can send out.
  class Message

    include Term::ANSIColor

    attr_reader :type, :id, :message, :sourceFileInfo, :line

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

    # Convert the Message into a String.
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

  end

  # The MessageHandler can display and store application messages. Depending
  # on the type of the message, a TjExeption can be raised (:error), or the
  # program can be immedidately aborted (:fatal). Other types will just
  # continue the program flow.
  class MessageHandler

    attr_reader :messages, :errors
    attr_accessor :scenario, :abortOnWarning

    # Initialize the MessageHandler. _console_ specifies if the messages
    # should be printed to $stderr.
    def initialize(console = false)
      @messages = []
      @console = console
      # We count the errors.
      @errors = 0
      # Set to true if program should be exited on warnings.
      @abortOnWarning = false
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
      addMessage(:info, id, message, sourceFileInfo, line, data, scenario)
    end

    # Generate a message by specifying the _type_.
    def addMessage(type, id, message, sourceFileInfo = nil, line = nil,
                   data = nil, scenario = nil)
      # Treat criticals like errors but without generating another
      # exception.
      msg = Message.new(type == :critical ? :error : type, id, message,
                        sourceFileInfo, line, data, scenario)
      @messages << msg
      # Print the message to $stderr if requested by the user.
      $stderr.puts msg.to_s if @console

      case type
      when :warning
        raise TjException.new, '' if @abortOnWarning
      when :critical
        # Increase the error counter.
        @errors += 1
      when :error
        # Increase the error counter.
        @errors += 1
        raise TjException.new, ''
      when :fatal
        raise RuntimeError
      end
    end

    # Convert all messages into a single String.
    def to_s
      text = ''
      @messages.each { |msg| text += msg.to_s }
      text
    end

  end

end

