#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3AppBase.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'term/ansicolor'
require 'taskjuggler/Tj3Config'
require 'taskjuggler/RuntimeConfig'
require 'taskjuggler/TjTime'
require 'taskjuggler/TextFormatter'
require 'taskjuggler/MessageHandler'
require 'taskjuggler/Log'

class TaskJuggler

  class Tj3AppBase

    include MessageHandler

    def initialize
      # Indent and width of options. The deriving class may has to change
      # this.
      @optsSummaryWidth = 22
      @optsSummaryIndent = 5
      # Show some progress information by default
      @silent = false
      @configFile = nil
      @mandatoryArgs = ''
      @mininumRubyVersion = '1.9.2'

      # If stdout is not a tty, we don't use ANSI escape sequences to color
      # the terminal output. Additionally, we have the --no-color option to
      # force colors off in case this does not work properly.
      Term::ANSIColor.coloring = STDOUT.tty?

      # Make sure the MessageHandler is set to default values.
      MessageHandlerInstance.instance.reset
    end

    def processArguments(argv)
      @opts = OptionParser.new
      @opts.summary_width = @optsSummaryWidth
      @opts.summary_indent = ' ' * @optsSummaryIndent

      @opts.banner = "#{AppConfig.softwareName} v#{AppConfig.version} - " +
                     "#{AppConfig.packageInfo}\n\n" +
                     "Copyright (c) #{AppConfig.copyright.join(', ')}\n" +
                     "              by #{AppConfig.authors.join(', ')}\n\n" +
                     "#{AppConfig.license}\n" +
                     "For more info about #{AppConfig.softwareName} see " +
                     "#{AppConfig.contact}\n\n" +
                     "Usage: #{AppConfig.appName} [options] " +
                     "#{@mandatoryArgs}\n\n"
      @opts.separator ""
      @opts.on('-c', '--config <FILE>', String,
               format('Use the specified YAML configuration file')) do |arg|
         @configFile = arg
      end
      @opts.on('--silent',
               format("Don't show program and progress information")) do
        @silent = true
        MessageHandlerInstance.instance.outputLevel = :warning
        TaskJuggler::Log.silent = true
      end
      @opts.on('--no-color',
               format(<<'EOT'
Don't use ANSI contol sequences to color the terminal output. Colors should
only be used when spooling to an ANSI terminal. In case the detection fails,
you can this option to force colors to be off.
EOT
                     )) do
        Term::ANSIColor::coloring = false
      end
      @opts.on('--debug', format('Enable Ruby debug mode')) do
        $DEBUG = true
      end

      yield

      @opts.on_tail('-h', '--help', format('Show this message')) do
        puts @opts.to_s
        quit
      end
      @opts.on_tail('--version', format('Show version info')) do
        puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
          "#{AppConfig.packageInfo}"
        quit
      end

      begin
        files = @opts.parse(argv)
      rescue OptionParser::ParseError => msg
        puts @opts.to_s + "\n"
        error('tj3app_bad_cmd_options', msg.message)
      end

      files
    end

    def main(argv = ARGV)
      if Gem::Version.new(RUBY_VERSION.dup) <
         Gem::Version.new(@mininumRubyVersion)
        error('tj3app_ruby_version',
              'This program requires at least Ruby version ' +
              "#{@mininumRubyVersion}!")
      end

      # Install signal handler to exit gracefully on CTRL-C.
      intHandler = Kernel.trap('INT') do
        begin
          fatal('tj3app_user_abort', "Aborting on user request!")
        rescue RuntimeError
          exit 1
        end
      end

      retVal = 0
      begin
        args = processArguments(argv)

        # If DEBUG mode has been enabled, we restore the INT trap handler again
        # to get Ruby backtrackes.
        Kernel.trap('INT', intHandler) if $DEBUG

        unless @silent
          puts "#{AppConfig.softwareName} v#{AppConfig.version} - " +
               "#{AppConfig.packageInfo}\n\n" +
               "Copyright (c) #{AppConfig.copyright.join(', ')}\n" +
               "              by #{AppConfig.authors.join(', ')}\n\n" +
               "#{AppConfig.license}\n"
        end

        @rc = RuntimeConfig.new(AppConfig.packageName, @configFile)

        begin
          MessageHandlerInstance.instance.trapSetup = true
          retVal = appMain(args)
          MessageHandlerInstance.instance.trapSetup = false
        rescue TjRuntimeError
          # We have hit a sitatuation that we can't recover from. A message
          # was severed via the MessageHandler to inform the user and we now
          # abort the program.
          return 1
        end

      rescue Exception => e
        if e.is_a?(SystemExit) || e.is_a?(Interrupt)
          # Don't show backtrace on user interrupt unless we are in debug mode.
          $stderr.puts e.backtrace.join("\n") if $DEBUG
          1
        else
          fatal('crash_trap', "#{e}\n#{e.backtrace.join("\n")}\n\n" +
                "#{'*' * 79}\nYou have triggered a bug in " +
                "#{AppConfig.softwareName} version #{AppConfig.version}!\n" +
                "Please see the user manual on how to get this bug fixed!\n" +
                "http://www.taskjuggler.org/tj3/manual/Reporting_Bugs.html#" +
                "Reporting_Bugs_and_Feature_Requests\n" +
                "#{'*' * 79}\n")
        end
      end

      # Exit value in case everything was fine.
      retVal
    end

    private

    def quit
      exit 0
    end

    def format(str, indent = nil)
      indent = @optsSummaryWidth + @optsSummaryIndent + 1 unless indent
      TextFormatter.new(79, indent).format(str)[indent..-1]
    end

  end

end

