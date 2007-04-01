#
# MacroTable.rb - TaskJuggler
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# $Id$
#

require 'SourceFileInfo'
require 'MessageHandler'
require 'Message'
require 'TjException'

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

  def initialize(messageHandler)
    @messageHandler = messageHandler
    @macros = {}
  end

  def add(macro)
    @macros[macro.name] = macro
  end

  def clear
    @macros = []
  end

  def resolve(args, sourceFileInfo)
    name = args.delete_at(0)
    if name[0] == ??
      name.slice!(1..-1)
      unless @macros.include?(name)
        return nil
      end
    end
    unless @macros.include?(name)
      error('undef_macro', "Macro #{name} is undefined", sourceFileInfo)
      return nil
    end
    resolved = @macros[name].value.clone
    i = 1
    args.each do |arg|
      resolved.gsub!("${#{i}}", arg)
      i += 1
    end
    [ @macros[name], resolved ]
  end

  def error(id, text, sourceFileInfo)
    message = Message.new(id, 'error', text, nil, nil, sourceFileInfo)
    @messageHandler.send(message)
    raise TjException.new, 'Macro expasion error'
  end

end

