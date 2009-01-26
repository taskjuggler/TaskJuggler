# TASK MANUAL

desc 'Generate User Manual'
task :manual do
    rm_rf MANUAL_DIR if File.exists? MANUAL_DIR
    mkdir_p MANUAL_DIR
    sh "ruby -Ilib lib/UserManual.rb"
end


