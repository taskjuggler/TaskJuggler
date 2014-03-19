#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MacroTable.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler::TextParser

  class Macro

    attr_reader :name, :value, :sourceFileInfo

    def initialize(name, value, sourceFileInfo)
      @name = name
      @value = value
      @sourceFileInfo = sourceFileInfo
    end

  end

  # The MacroTable is used by the TextScanner to store defined macros and
  # resolve them on request later on. A macro is a text pattern that has a name.
  # The pattern may contain variable parts that are replaced by arguments passed
  # during the macro call.
  class MacroTable

    def initialize
      @macros = {}
    end

    # Add a new macro definition to the table or replace an existing one.
    def add(macro)
      @macros[macro.name] = macro
    end

    # Remove all definitions from the table.
    def clear
      @macros = []
    end

    # Returns true only if a macro named _name_ is defined in the table.
    def include?(name)
      @macros.include?(name)
    end

    # Returns the definition of the macro specified by name as first entry of
    # _args_. The other entries of _args_ are parameters that are replacing the
    # ${n} tokens in the macro definition. In case the macro call has less
    # arguments than the macro definition uses, the ${n} tokens remain
    # unchanged. No error is generated.
    def resolve(args, sourceFileInfo)
      name = args[0]
      # If the first character of the macro name is a '?', the macro may be
      # undefined and is silently ignored.
      if name[0] == ??
        # Remove the '?' from the name.
        name = name[1..-1]
        return [ nil, '' ] unless @macros[name]
      end
      return nil unless @macros[name]

      resolved = @macros[name].value.dup
      i = 0
      args.each do |arg|
        resolved.gsub!(Regexp.new("(([^$]|^))\\$\\{#{i}\\}"), "\\1#{arg}")
        i += 1
      end
      # Remove the escape character from all the escaped '${...}'.
      resolved.gsub!('$${', '${')
      [ @macros[name], resolved ]
    end

  end

end

