require 'time'

desc 'Generate the CHANGELOG file'
task :changelog do

  class Entry

    attr_reader :type

    def initialize(ref, author, time, message)
      @ref = ref
      @author = author
      @time = time
      @message = message
      if (m = /New: (.*)/.match(@message))
        @type = :feature
        @message = m[1]
      elsif (m = /Fix: (.*)/.match(@message))
        @type = :bugfix
        @message = m[1]
      else
        @type = :other
      end
    end

    def to_s
      "  * #{@message}\n"
    end

  end

  class Release

    attr_reader :date, :version, :tag

    def initialize(tag, predecessor)
      @tag = tag
      # We only support release tags in the form X.X.X
      @version = /\d+\.\d+\.\d+/.match(tag)

      # Construct a Git range.
      interval = predecessor ? "#{predecessor.tag}..#{@tag}" : @tag

      # Get the date of the release
      date = Time.parse(/Date: (.*)/.match(`git show #{tag}`)[1]).utc
      @date = date.strftime("%Y-%m-%d")

      @entries = []
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
        @entries << Entry.new(ref, author, time, message)
      end
    end

    def empty?
      @entries.empty?
    end

    def to_s
      s = ''
      if hasFeatures? || hasFixes?
        if hasFeatures?
          s << "== New Features\n\n"
          @entries.each do |entry|
            s << entry.to_s if entry.type == :feature
          end
          s << "\n"
        end
        if hasFixes?
          s << "== Bug Fixes\n\n"
          @entries.each do |entry|
            s << entry.to_s if entry.type == :bugfix
          end
          s << "\n"
        end
      else
        @entries.each do |entry|
          s << entry.to_s
        end
      end
      s
    end

    private

    def hasFeatures?
      @entries.each do |entry|
        return true if entry.type == :feature
      end
      false
    end

    def hasFixes?
      @entries.each do |entry|
        return true if entry.type == :bugfix
      end
      false
    end

  end

  class ChangeLog

    def initialize
      @releases = []
      predecessor = nil
      getReleaseVersions.each do |version|
        @releases << (predecessor = Release.new(version, predecessor))
      end
    end

    def to_s
      s = ''
      @releases.reverse.each do |release|
        next if release.empty?

        # We use RDOC markup syntax to generate a title
        if release.version
          s << "= Release #{release.version} (#{release.date})\n\n"
        else
          s << "= Next Release (Some Day)\n\n"
        end
        s << release.to_s + "\n"
      end
      s
    end

    private

    # 'git tag' is not sorted numerically. This function implements a
    # numerical comparison for tag versions of the format 'release-X.X.X'. X
    # can be a multi-digit number.
    def compareTags(a, b)

      def versionToComparable(v)
        /\d+\.\d+\.\d+/.match(v)[0].split('.').map{ |l| sprintf("%03d", l.to_i)}.
                                                             join('.')
      end

      versionToComparable(a) <=> versionToComparable(b)
    end

    def getReleaseVersions
      # Get list of release tags from Git repository
      releaseVersions = `git tag`.split("\n").map { |r| r.chomp }.
        sort{ |a, b| compareTags(a, b) }
      releaseVersions << 'HEAD'
    end

  end

  File.open('CHANGELOG', 'w+') do |changelog|
    changelog.puts ChangeLog.new.to_s
  end

end
