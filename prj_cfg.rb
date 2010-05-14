# -*- coding: utf-8 -*-

# PROJECT
PROJECT_NAME    = 'TaskJuggler III'
PROJECT_SUMMARY = 'Project Management Software'
PROJECT_HOMEPAGE= 'http://www.taskjuggler.org'
UNIX_NAME       = 'taskjuggler'

# PERSONAL
USER_NAME       = 'Chris Schlaeger'
USER_EMAIL      = 'cs@kde.org'
RUBYFORGE_USER  = ENV['RUBYFORGE_USER']
#CERT_PRIVATE    = ENV['HOME']/.gem/certs/gem-private-key.pem

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
DATA_DIR        = 'data'
RDOC_DIR        = 'doc'
RCOV_DIR        = 'rcov'
RAKE_DIR        = 'tasks'
MANUAL_DIR      = 'manual'

# FILES
README          = FileList['README']
CHANGES         = ''#'CHANGES'
LICENSE         = 'COPYING'
DESCRIPTION     = <<'EOT'
TaskJuggler is a project management software that goes far beyond the commonly
known Gantt chart editors.
EOT
RAKEFILE        = 'Rakefile'
SETUP_FILE      = 'setup.rb'
PRJ_FILE        = 'prj_cfg.rb'
GEM_SPEC_FILE   = 'gem_spec.rb'
DATA_FILES      = FileList["benchmarks/**/*", "examples/**/*", "manual/*", "test/all.rb", "test/MessageChecker.rb", "test/TestSuite/**/*", "data/**/*"]
DEPENDENCIES    = { 'mail' => '= 2.1.3',
                    'open4' => '1.0.1' }
