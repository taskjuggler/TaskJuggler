
task :CHANGES do
    if File.directory? '.git'
        system('git log >CHANGES')
    elsif not File.exist? CHANGES
        open( CHANGES, 'a' ) { |fn| fn <<"
= #{PROJECT_NAME} Changelog

== Version #{PROJECT_VERSION}

* Added XXX
* Added YYY
* Added ZZZ
" }
    end
end

task :README do
    load 'README.rb' if File.exist? 'README.rb'
end

