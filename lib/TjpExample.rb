#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TjpExample.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'stringio'

# This class can extract snippets from an annotated TJP syntax file. The file
# does not care about the TJP syntax but the annotation lines must start with
# a '#' character at the begining of the line. The snippets must be enclosed
# by a starting line and an ending line. Each snippet must have a unique tag
# that can be used to retrieve the specific snip.
#
# The following line starts a snip called 'foo':
# # *** EXAMPLE: foo +
#
# The following line ends a snip called 'foo':
# # *** EXAMPLE: foo -
#
# The function TjpExample#to_s() can be used to get the content of the snip.
# It takes the tag name as optional parameter. If no tag is specified, the
# full example without the annotation lines is returned.
class TjpExample

  # Create a new TjpExample object.
  def initialize
    @snippets = { }
    # Here we will store the complete example.
    @snippets['full text'] = []
    @file = nil
  end

  # Use this function to process the file called _fileName_.
  def open(fileName)
    @file = File.open(fileName, 'r')
    process
    @file.close
  end

  # Use this function to process the String _text_.
  def parse(text)
    @file = StringIO.new(text)
    process
  end

  # This method returns the snip identified by _tag_.
  def to_s(tag = nil)
    tag = 'full text' unless tag
    return nil unless @snippets[tag]

    s = ''
    @snippets[tag].each { |l| s << l }
    s
  end

private

  def process
    # This mark identifies the annotation lines.
    mark = '# *** EXAMPLE: '

    # We need this to remember what snippets are currently active.
    snippetState = { }
    # Now process the file or String line by line.
    @file.each_line do |line|
      if line[0, mark.length] == mark
        # We've found an annotation line. Get the tag and indicator.
        dum, dum, dum, tag, indicator = line.split

        if indicator == '+'
          # Start a new snip
          if snippetState[tag]
            raise "Snippet #{tag} has already been started"
          end
          snippetState[tag] = true
        elsif indicator == '-'
          # Stop an existing snip
          unless snippetState[tag]
            raise "Snippet #{tag} has not yet been started"
          end
          snippetState[tag] = false
        else
          raise "Bad indicator: #{line}"
        end
      else
        # Process the regular lines and add them to all currently active
        # snippets.
        snippetState.each do |t, state|
          if state
            # Create a new snip buffer if it does not yet exist.
            @snippets[t] = [] unless @snippets[t]
            # Add the line.
            @snippets[t] << line
          end
        end
        # Add all lines to this buffer.
        @snippets['full text'] << line
      end
    end

    # Remove empty lines at end of all snips
    @snippets.each_value do |snip|
      snip.delete_at(-1) if snip[-1] == "\n"
    end
  end

end
