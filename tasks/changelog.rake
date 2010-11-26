require 'time'

desc 'update changelog'
task :CHANGELOG do
  # Get list of release tags from Git repository
  releases = `git tag`.split("\n").map { |r| r.chomp }

  # Now we get the commit entries for each release
  sections = []
  prevRelease = nil
  releases.each do |release|
    # This buffer holds the final text for the release section. It will
    # contain the commit messages in RDoc format.
    text = ''
    # We only support release tags in the form X.X.X
    version = /\d\.\d\.\d/.match(release)
    # Construct a Git range.
    interval = prevRelease ? "#{prevRelease}..#{release}" : release
    prevRelease = release

    # Get the date of the release
    date = Time.parse(/Date: (.*)/.match(`git show #{release}`)[1]).utc
    date = date.strftime("%Y-%m-%d")
    # We use RDOC markup syntax to generate a title
    text += "= Release #{version} (#{date})\n\n"

    # Use -z option for git-log to get 0 bytes as separators.
    `git log -z #{interval}`.split("\0").each do |commit|
      # We ignore merges.
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

      text += "  * #{message}\n"
    end
    sections << text
  end

  File.open('CHANGELOG', 'w+') do |changelog|
    # List releases from last to first.
    sections.reverse.each do |section|
      changelog.puts section + "\n"
    end
  end
end
