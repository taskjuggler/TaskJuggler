    
desc 'lines and words count of real ruby code ( no empty lines or comments )'
task :stats do
    pattern = Regexp.new("^\s*(?:#.*)?$")
#    count_proc = Proc.new do |path|
#        Dir[path].collect { |f| File.open(f).readlines.reject { |l| l =~ pattern }.size }.inject(0) { |sum,n| sum+=n }
#    end
    stat_proc = Proc.new do |files,name|
        lines=0
        words=0
        files.each { |fn| open(fn){ |f| f.each{ |line|
            begin
                lines += 1
                words += line.split(' ').size
            end if not pattern.match(line)
        } } }
        puts "#{ format('%10s',name)} => #{format('%7d',lines)} code lines, #{format('%7d',words)} words."
    end
    stat_proc.call BIN_FILES, 'bin'
    stat_proc.call LIB_FILES, 'lib'
    stat_proc.call TEST_FILES, 'test'
    stat_proc.call EXT_FILES, 'ext'

end

