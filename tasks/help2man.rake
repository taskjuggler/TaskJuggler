# TASK MAN GENERATE

CLOBBER.include "man"

directory "man"

desc 'Generate man pages from help'
task :help2man => 'man' do
	help2man = %x{which help2man}
	help2man.chomp!
	Dir.foreach('bin') do |prog|
		next if prog == '.' or prog == '..'
		system help2man,"--output=man/#{prog}.1","--no-info","--manual=TaskJuggler",*("--include=h2m/#{prog}.h2m" unless !File.exists?("h2m/#{prog}.h2m")),"bin/#{prog}"
	end
end

