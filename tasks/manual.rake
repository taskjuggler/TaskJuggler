# TASK MANUAL

desc 'Generate User Manual'
task :manual do
    htmldir = MANUAL_DIR + '/html'
    rm_rf htmldir if File.exists? htmldir
    mkdir_p htmldir
    ENV['TASKJUGGLER_DATA_PATH'] = Dir.getwd
    sh "ruby -Ilib lib/tj3man.rb -d #{htmldir} -m"
end


