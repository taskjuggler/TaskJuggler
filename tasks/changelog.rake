require 'time'

desc 'update changelog'
task :CHANGELOG do
  releases = `git tag`.split("\n").map { |r| r.chomp }

  File.open('CHANGELOG', 'w+') do |changelog|
    prevRelease = nil
    releases.each do |release|
      version = /\d\.\d\.\d/.match(release)
      interval = prevRelease ? "#{prevRelease}..#{release}" : release
      prevRelease = release

      date = Time.parse(/Date: (.*)/.match(`git show #{release}`)[1]).utc
      date = date.strftime("%Y-%m-%d")
      # We use RDOC markup syntax to generate a title
      changelog.puts "= Release #{version} (#{date})\n"

      `git log -z #{interval}`.split("\0").each do |commit|
        next if commit =~ /^Merge: \d*/
        ref, author, time, _, message = commit.split("\n", 5)
        ref = ref[/commit ([0-9a-f]+)/, 1]
        author = author[/Author: (.*)/, 1].strip
        time = Time.parse(time[/Date: (.*)/, 1]).utc
        # Eleminate git-svn-id: lines
        message.gsub!(/git-svn-id: .*\n/, '')
        # Eliminate Signed-off-by: lines
        message.gsub!(/Signed-off-by: .*\n/, '')
        message.strip!

        changelog.puts '', "  * #{message}"
      end
      changelog.puts
    end
  end
end
