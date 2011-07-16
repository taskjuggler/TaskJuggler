# GEM TASK
require 'rake/gempackagetask'
require 'find'

task :release => [:clobber] do
  Rake::Task[:test].invoke
  Rake::Task[:spec].invoke
  Rake::Task[:rdoc].invoke

  Rake::Task[:vim].invoke
  Rake::Task[:manual].invoke

  load 'taskjuggler.gemspec';

  Rake::GemPackageTask.new(GEM_SPEC) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = true
  end

  # Find the bin and test directories relative to this file.
  baseDir = File.expand_path('..', File.dirname(__FILE__))

  execs = Dir.glob("#{baseDir}/bin/*") +
          Dir.glob("#{baseDir}/test/**/genrefs")
  # Make sure all files and directories are readable.
  Find.find(baseDir) do |f|
    # Ignore the whoke pkg directory as it may contain links to the other
    # directories.
    next if Regexp.new("#{baseDir}/pkg/*").match(f)

    FileUtils.chmod_R((FileTest.directory?(f) ||
                       execs.include?(f) ? 0755 : 0644), f)
  end
  Rake::Task[:package].invoke
end

