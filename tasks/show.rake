# TASK SHOW
def enum_files( label, files=[] )
    puts "#{label}\t:" #{files.length==0 ? 'nil' : ''}"
    files.each{ |f| puts "\t  #{f}" }
end

desc 'Show current configuration of this project'
task :show do
    puts "built on #{GEM_SPEC.date.strftime('%d-%m-%Y')}"
    puts "project\t: #{PROJECT_NAME} #{UNIX_NAME}-#{PROJECT_VERSION} [ #{PROJECT_SUMMARY} ]"
    puts "owner\t: #{USER_NAME} [#{RUBYFORGE_USER}] #{USER_EMAIL}" 
    enum_files 'rake', RAKE_FILES
    enum_files 'bin', BIN_FILES
    enum_files 'lib', LIB_FILES
    enum_files EXT_DIR, EXT_FILES
    enum_files 'test', TEST_FILES
    enum_files 'rdoc', RDOC_FILES
    enum_files 'data', DATA_FILES
    enum_files 'paths', REQUIRE_PATHS
end

