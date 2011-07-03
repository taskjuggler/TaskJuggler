# GEM TASK
require 'find'

Rake::GemPackageTask.new(GEM_SPEC) { |pkg|
    pkg.need_zip        = true
    pkg.need_tar        = true
    puts "Signed with #{CERT_PRIVATE}" if HAVE_CERT
}

execs = Dir.glob('./bin/*') + Dir.glob('./**/run') +
        Dir.glob('./test/**/genrefs')

task :release => [:clobber] do
    puts "Preparing release of #{PROJECT_NAME} version #{PROJECT_VERSION}"
    Rake::Task[:vim].invoke
    Rake::Task[:spec].invoke
    Rake::Task[:test].invoke
    Rake::Task[:rdoc].invoke
    # Make sure all files and directories are readable.
    Find.find('.') do |f|
      FileUtils.chmod_R((FileTest.directory?(f) ||
                         execs.include?(f)) ? 0755 : 0644, f)
    end
    Rake::Task[:package].invoke
end

