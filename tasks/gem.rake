# GEM TASK
require 'rake/gempackagetask'
require 'find'

execs = Dir.glob('./bin/*') + Dir.glob('./test/**/genrefs')

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

  # Make sure all files and directories are readable.
  Find.find('.') do |f|
    FileUtils.chmod_R((FileTest.directory?(f) ||
                       execs.include?(f)) ? 0755 : 0644, f)
  end
  Rake::Task[:package].invoke
end

