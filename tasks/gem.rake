# GEM TASK
Rake::GemPackageTask.new(GEM_SPEC) { |pkg|
    pkg.need_zip        = true
    pkg.need_tar        = true
    puts "Signed with #{CERT_PRIVATE}" if HAVE_CERT
}

task :release => [:clobber] do
    puts "Preparing release of #{PROJECT_NAME} version #{PROJECT_VERSION}"
    Rake::Task[:test].invoke
#    Rake::Task[:rdoc].invoke
    Rake::Task[:package].invoke
end

