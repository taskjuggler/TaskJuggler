#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Man.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Tj3AppBase'
require 'taskjuggler/TernarySearchTree'
require 'taskjuggler/SyntaxReference'
require 'taskjuggler/UserManual'

AppConfig.appName = 'tj3man'

class TaskJuggler

  class Tj3Man < Tj3AppBase

    def initialize
      super

      @man = SyntaxReference.new
      @keywords = TernarySearchTree.new(@man.all)
      @manual = false
      @showHtml = false
      @browser = ENV['BROWSER'] || 'firefox'
      @directory = './'
      @mininumRubyVersion = '1.8.7'
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
This program can be used to generate the user manual in HTML format or to get
a textual help for individual keywords.
EOT
        @opts.on('-d', '--dir <directory>', String,
                format('directory to put the manual')) do |dir|
          @directory = dir
        end
        @opts.on('--html',
                 format('Show the user manual in your local web browser. ' +
                        'By default, Firefox is used or the brower specified ' +
                        'with the $BROWSER environment variable.')) do
          @showHtml = true
        end
        @opts.on('--browser <command>', String,
                 format('Specify the command to start your web browser. ' +
                        'The default is \'firefox\'.')) do |browser|
          @browser = browser
        end
        @opts.on('-m', '--manual',
                format('Generate the user manual into the current directory ' +
                       'or the directory specified with the -d option.')) do
          @manual = true
        end
      end
    end

    def appMain(requestedKeywords)
      if @manual
        UserManual.new.generate(@directory)
      elsif requestedKeywords.empty?
        showManual
      else
        requestedKeywords.each do |keyword|
          if (kws = @keywords[keyword, true]).nil?
            error('tj3man_no_matches', "No matches found for '#{keyword}'")
          elsif kws.length == 1 || kws.include?(keyword)
            showManual(keyword)
          else
            warning('tj3man_multi_match',
                    "Multiple matches found for '#{keyword}':\n" +
                    "#{kws.join(', ')}")
          end
        end
      end

      0
    end

    private

    def showManual(keyword = nil)
      if @showHtml
        # If the user requested HTML format, we start the browser.
        startBrowser(keyword)
      else
        if keyword
          # Print the documentation for the keyword.
          puts @man.to_s(keyword)
        else
          # Print a list of all documented keywords.
          puts @man.all.join("\n")
        end
      end
    end

    # Start the web browser with either the entry page or the page for the
    # specified keyword.
    def startBrowser(keyword = nil)
      # Find the manual relative to this file.
      manualDir = File.join(File.dirname(__FILE__), '..', '..', '..',
                            'manual', 'html')
      file = "#{manualDir}/#{keyword || 'index'}.html"
      # Make sure the file exists.
      unless File.exists?(file)
        $stderr.puts "Cannot open manual file #{file}"
        exit 1
      end

      # Start the browser.
      begin
        `#{@browser} file:#{file}`
      rescue
        $stderr.puts "Cannot open browser: #{$!}"
        exit 1
      end
    end

  end

end

