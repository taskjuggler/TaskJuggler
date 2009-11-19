
# GLOBAL CONFIG
F_CHMOD           = 0644
D_CHMOD           = 0755

# VERSION
RUBY_1_9        = RUBY_VERSION =~ /^1\.9/
WIN             = (RUBY_PLATFORM =~ /mswin|cygwin/)
SUDO            = (WIN ? "" : "sudo" )

# EXTENSIONS
HAVE_EXT        = File.directory? "#{EXT_DIR}"
EXT_CONF_FILES  = FileList["#{EXT_DIR}/**/extconf.rb"]
EXT_SRC_FILES   = FileList["#{EXT_DIR}/**/*.{c,h}"]
EXT_FILES       = EXT_SRC_FILES + EXT_CONF_FILES

# FILES
RAKE_FILES      = FileList[RAKEFILE, PRJ_FILE, GEM_SPEC_FILE, SETUP_FILE, "#{RAKE_DIR}/*"]
BIN_FILES       = FileList["#{BIN_DIR}/**/*"]
LIB_FILES       = FileList["#{LIB_DIR}/**/*.rb"]
TEST_FILES      = FileList["#{TEST_DIR}/**/test_*.rb"]
RDOC_FILES      = FileList[README,LICENSE]#,CHANGES]

# DIST FILES
DIST_FILES       = FileList[]
DIST_FILES.include(RAKE_FILES)
DIST_FILES.include(BIN_FILES)
DIST_FILES.include(LIB_FILES)
DIST_FILES.include(TEST_FILES)
DIST_FILES.include(RDOC_FILES)
DIST_FILES.include(DATA_FILES)
DIST_FILES.include(EXT_FILES) if HAVE_EXT
DIST_FILES.include("#{RDOC_DIR}/**/*.{html,css}", 'man/*.[0-9]')
DIST_FILES.exclude('**/tmp_*', '**/*.tmp')

# 
CLEAN.include( MANUAL_DIR + '/html' )
CLEAN.include( 'README' ) if File.exist? 'README.rb'
CLEAN.include( 'CHANGES' ) if File.exist? 'CHANGES.rb'

# LOADPATH
REQUIRE_PATHS   = [LIB_DIR]
REQUIRE_PATHS   << EXT_DIR if HAVE_EXT
#$LOAD_PATH.concat REQUIRE_PATHS

# C EXTENSIONS TASKS
if HAVE_EXT
    CONFIG_OPTS = ENV['CONFIG']
    file_create '.config' do
        ruby "setup.rb config #{CONFIG_OPTS}"
    end

    desc 'Configure and make C extensions. The CONFIG variable is passed to \'setup.rb config\''
    task :make_ext => '.config' do
        ruby "setup.rb -q setup"
    end

    task :test_ext => :make_ext
    desc 'Run test after making the extensions.'
    task :test => :make_ext do
        Rake::Task[:test_ext].invoke
    end
end

# CERTIFICATE
cert_dir = ENV['CERT_DIR'] ||= File.expand_path(File.join('~', '.gem'))
HAVE_CERT = File.readable?(File.join(cert_dir, 'gem-private_key.pem')) and File.readable?(File.join(cert_dir, 'gem-public_cert.pem'))
if HAVE_CERT
    CERT_PRIVATE = File.join(cert_dir, 'gem-private_key.pem')
    CERT_PUBLIC = File.join(cert_dir, 'gem-public_cert.pem')
end

