#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Tj3Man.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
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
      @directory = nil
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
        @opts.on('-m', '--manual',
                format('Generate the user manual into the current directory ' +
                       'or the directory specified with the -d option.')) do
          @manual = true
        end
      end
    end

    def main(argv = ARGV)
      requestedKeywords = super
      if @manual
        UserManual.new.generate(@directory)
      elsif requestedKeywords.empty?
        puts @man.all.join("\n")
      else
        requestedKeywords.each do |keyword|
          if (kws = @keywords[keyword, true]).nil?
            $stderr.puts "No matches found for '#{keyword}'"
            exit 1
          elsif kws.length == 1 || kws.include?(keyword)
            puts @man.to_s(keyword)
          else
            $stderr.puts "Multiple matches found for '#{keyword}':\n" +
                         "#{kws.join(', ')}"
            return 1
          end
        end
      end
      0
    end

  end

end

