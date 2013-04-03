#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RuntimeConfig.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'yaml'

# The RuntimeConfig searches for a YAML config file in a list of directories.
# When a file is found it is read-in. The read-in config values are grouped in
# a tree of sections. The values of a section can then be used to overwrite
# the instance variable of a passed object.
class RuntimeConfig

  attr_accessor :debugMode

  def initialize(appName, configFile = nil)
    @appName = appName
    @config = nil
    @debugMode = false

    if configFile
      # Read user specified config file.
      unless loadConfigFile(configFile)
        error("Config file #{configFile} not found!")
      end
    else
      # Search config files in certain directories.
      [ '.', ENV['HOME'], '/etc' ].each do |path|
        # Try UNIX style hidden file first, then .rc.
        [ "#{path}/.#{appName}rc", "#{path}/#{appName}.rc" ].each do |file|
          break if loadConfigFile(file)
        end
      end
    end
  end

  def configure(object, section)
    debug("Configuring object of type #{object.class}")
    sections = section.split('.')
    p = @config
    sections.each do |sec|
      if p.nil? || !p.include?('_' + sec)
        debug("Section #{section} not found in config file")
        return false
      end
      p = p['_' + sec]
    end

    object.instance_variables.each do |iv|
      ivName = iv[1..-1]
      debug("Processing class variable #{ivName}")
      if p.include?(ivName)
        debug("Setting @#{ivName} to #{p[ivName]}")
        object.instance_variable_set(iv, p[ivName])
      end
    end

    true
  end

  private

  def loadConfigFile(fileName)
    if File.exist?(fileName)
      debug("Loading #{fileName}")
      begin
        @config = YAML::load(File.read(fileName))
      rescue
        error("Error in config file #{fileName}: #{$!}")
      end
      debug(@config.to_s)
      return true
    end
    false
  end

  def debug(message)
    return unless @debugMode

    puts message
  end

  def error(message)
    $stderr.puts message
    exit 1
  end

end

