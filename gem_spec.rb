# GEM SPECIFICATION
GEM_SPEC = Gem::Specification.new { |s|
    s.name              = UNIX_NAME
    s.version           = PROJECT_VERSION
    s.summary           = PROJECT_SUMMARY
    s.description       = DESCRIPTION
    s.rubyforge_project = UNIX_NAME
    s.homepage          = PROJECT_HOMEPAGE
    s.author            = USER_NAME
    s.email             = USER_EMAIL
    s.files             = DIST_FILES
    s.require_path      = LIB_DIR
    s.bindir            = BIN_DIR
    s.test_files        = TEST_FILES
    s.executables       = BIN_FILES.map { |fn| File.basename(fn) }
    s.has_rdoc          = true
    s.extra_rdoc_files  = RDOC_FILES
    #s.rdoc_options      = GENERAL_RDOC_OPTS.to_a.flatten
    DEPENDENCIES.each do |package, version|
      s.add_dependency(package, version)
    end
    DEVEL_DEPENDENCIES.each do |package, version|
      s.add_development_dependency(package, version)
    end
    s.date              = Time.now
    if HAVE_EXT
        s.extensions    = EXT_CONF_FILES
        s.require_paths << EXT_DIR
    end
    if HAVE_CERT
        s.signing_key = CERT_PRIVATE
        s.cert_chain  = [CERT_PUBLIC]
    end
    s.platform          = Gem::Platform::RUBY
    s.required_ruby_version  = '>= 1.8.7'
}

