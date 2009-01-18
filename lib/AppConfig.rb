#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = AppConfig.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'rbconfig'

# This class provides central management of configuration data to an
# application. It stores the version number, the name of the application and
# the suite it belongs to. It also holds copyright and license information.
# These infos have to be set in the main module of the application right after
# launch. Then, all other modules can retrieve them from the global instance
# as needed.
class AppConfig

  def initialize
    @@version = '0.0.0'
    @@packageName = 'unnamed'
    @@packageInfo = 'no info'
    @@appName = 'unnamed'
    @@authors = []
    @@copyright = []
    @@contact = 'not specified'
    @@license = 'no license'
  end

  def AppConfig.version=(version)
    @@version = version
  end

  def AppConfig.version
    @@version
  end

  def AppConfig.packageName=(name)
    @@packageName = name
  end

  def AppConfig.packageName
    @@packageName
  end

  def AppConfig.packageInfo=(info)
    @@packageInfo = info
  end

  def AppConfig.packageInfo
    @@packageInfo
  end

  def AppConfig.appName=(name)
    @@appName = name
  end

  def AppConfig.appName
    @@appName
  end

  def AppConfig.authors=(authors)
    @@authors = authors
  end

  def AppConfig.authors
    @@authors
  end

  def AppConfig.copyright=(copyright)
    @@copyright = copyright
  end

  def AppConfig.copyright
    @@copyright
  end

  def AppConfig.contact=(contact)
    @@contact = contact
  end

  def AppConfig.contact
    @@contact
  end

  def AppConfig.license=(license)
    @@license = license
  end

  def AppConfig.license
    @@license
  end

  def AppConfig.dataDirs
    siteLibDir = ::Config::CONFIG['sitelibdir']
    siteBaseDir, rubyVersionDir = siteLibDir.scan(/(.*\/)(.*)/)[0]
    dirs = []
    # This is for the development version. We assume that we run the app
    # from the lib directory.
    dirs << "../data/"
    # This hopefully works for all setups. Otherwise we have to add more
    # alternative pathes.
    dirs << siteBaseDir + "gems/" + rubyVersionDir + '/gems/' \
        + @@name + '-' + @@version + '/data/'
    dirs << '/usr/share/'
    dirs << '/usr/local/share/'
  end

  def AppConfig.dataFiles(fileName)
    files = []
    dirs = dataDirs
    dirs.each { |d| files << d + fileName if File.exist?(d + fileName) }

    files
  end

  def AppConfig.dataFile(fileName)
    dirs = dataDirs
    dirs.each { |d| return d + fileName if File.exist?(d + fileName) }

    nil
  end

end

