# -*- coding: utf-8 -*-

# PROJECT
PROJECT_NAME    = 'TaskJuggler III'
PROJECT_SUMMARY = 'Project Management Software'
PROJECT_HOMEPAGE= 'http://www.taskjuggler.org'
UNIX_NAME       = File.basename( Dir.pwd ).downcase

# PERSONAL
USER_NAME       = 'Chris Schlaeger'
USER_EMAIL      = 'cs@kde.org'
RUBYFORGE_USER  = ENV['RUBYFORGE_USER']

# VERSION
begin
    $: << 'lib'
    require 'lib/Tj3Config'
    PROJECT_VERSION = AppConfig.version
rescue LoadError
    puts '> unable to set project version, what a shame ... does version mean something to you ??'
    exit 1
end

# DIRECTORIES
BIN_DIR         = 'bin'
LIB_DIR         = 'lib'
EXT_DIR         = 'ext'
TEST_DIR        = 'test'
RDOC_DIR        = 'rdoc'
RCOV_DIR        = 'rcov'
RAKE_DIR        = 'tasks'

# FILES
README          = 'README.rb'
CHANGES         = #'CHANGES'
LICENSE         = 'COPYING'
RAKEFILE        = 'Rakefile'
SETUP_FILE      = 'setup.rb'
PRJ_FILE        = 'prj_cfg.rb'
GEM_SPEC_FILE   = 'gem_spec.rb'
DATA_FILES      = FileList["benchmarks/**/*", "examples/**/*", "manual/**/*", "test/TestSuite/**/*" ]

