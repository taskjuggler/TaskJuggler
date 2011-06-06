require 'time'

desc 'update changelog'
task :CHANGELOG do

  # 'git tag' is not sorted numerically. This function implements a numerical
  # comparison for tag versions of the format 'release-X.X.X'. X can be a
  # multi-digit number.
  def compareTags(a, b)

    def versionToComparable(v)
      /\d+\.\d+\.\d+/.match(v)[0].split('.').map{ |l| sprintf("%03d", l.to_i)}.
                                                           join('.')
    end

    versionToComparable(a) <=> versionToComparable(b)
  end

  # Get list of release tags from Git repository
  releases = `git tag`.split("\n").map { |r| r.chomp }.
    sort{ |a, b| compareTags(a, b) }
  releases << 'HEAD'

  # Now we get the commit entries for each release
  sections = []
  prevRelease = nil
  releases.each do |release|
    # This buffer holds the final text for the release section. It will
    # contain the commit messages in RDoc format.
    text = ''
    # We only support release tags in the form X.X.X
    version = /\d+\.\d+\.\d+/.match(release)
    # Construct a Git range.
    interval = prevRelease ? "#{prevRelease}..#{release}" : release
    prevRelease = release

    # Get the date of the release
    date = Time.parse(/Date: (.*)/.match(`git show #{release}`)[1]).utc
    date = date.strftime("%Y-%m-%d")

    logText = ''
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

      logText += "  * #{message}\n"
    end

    # Skip the release if there are no changes. E. g. HEAD at release.
    next if logText.empty?

    # We use RDOC markup syntax to generate a title
    if version
      text += "= Release #{version} (#{date})\n\n"
    else
      text += "= Next Release (Some Day)\n\n"
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
