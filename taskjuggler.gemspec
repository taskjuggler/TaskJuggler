# -*- coding: utf-8 -*-
#
# = taskjuggler.gemspec -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This gemspec file will be used to package the taskjuggler gem. Before you
# use it, the manual and other generated files must have been created!

lib = File.expand_path('../lib', __FILE__)
$:.unshift lib unless $:.include?(lib)

# Get software version number from Tj3Config class.
begin
  $: << 'lib'
  require 'taskjuggler/Tj3Config'
  PROJECT_VERSION = AppConfig.version
  PROJECT_NAME = AppConfig.softwareName
rescue LoadError
  raise "Error: Cannot determine software settings: #{$!}"
end

GEM_SPEC = Gem::Specification.new { |s|
  s.name = 'taskjuggler'
  s.version = PROJECT_VERSION
  s.homepage = 'http://www.taskjuggler.org'
  s.author = 'Chris Schlaeger'
  s.email = 'chris@linux.com'
  s.summary = 'A Project Management Software'
  s.description = <<'EOT'
TaskJuggler is a modern and powerful, Free and Open Source Software project
management tool. It's new approach to project planning and tracking is more
flexible and superior to the commonly used Gantt chart editing tools.

TaskJuggler is project management software for serious project managers. It
covers the complete spectrum of project management tasks from the first idea
to the completion of the project. It assists you during project scoping,
resource assignment, cost and revenue planning, risk and communication
management.
EOT
  s.license = 'GPL-2.0-only'
  s.require_path = 'lib'
  s.files = (`git ls-files -- lib`).split("\n") +
            (`git ls-files -- data`).split("\n") +
            (`git ls-files -- manual`).split("\n") +
            (`git ls-files -- examples`).split("\n") +
            (`git ls-files -- tasks`).split("\n") +
            %w( .gemtest taskjuggler.gemspec Rakefile ) +
            # Generated files, not contained in Git repository.
            %w( data/tjp.vim ) + Dir.glob('manual/html/**/*') + Dir.glob('man/*.1')
  s.bindir = 'bin'
  s.executables = (`git ls-files -- bin`).split("\n").
                  map { |fn| File.basename(fn) }
  s.test_files = (`git ls-files -- test`).split("\n") +
                 (`git ls-files -- spec`).split("\n")

  s.extra_rdoc_files = %w( README.rdoc COPYING CHANGELOG )

  s.add_dependency('mail', '~> 2.7', '>= 2.7.1')
  s.add_runtime_dependency('term-ansicolor', '~> 1.7', '>= 1.7.1')
  s.add_development_dependency('rspec', '~> 2.5', '>= 2.5.0')
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version  = '>= 2.0.0'
}
