require 'rexml/text'

module REXML
  class Text < Child
    # check for illegal characters
    def Text.check string, pattern, doctype

      # illegal anywhere
      if string !~ VALID_XML_CHARS
        if String.method_defined? :encode
          string.chars.each do |c|
            case c.ord
            when *VALID_CHAR
            else
              raise "Illegal character #{c.inspect} in raw string \"#{string}\""
            end
          end
        else
          string.scan(/[\x00-\x7F]|[\x80-\xBF][\xC0-\xF0]*|[\xC0-\xF0]/n) do |c|
            case c.unpack('U')
            when *VALID_CHAR
            else
              raise "Illegal character #{c.inspect} in raw string \"#{string}\""
            end
          end
        end
      end
        # UGLY cut off, we'll see later
      # context sensitive
#      string.scan(pattern) do
#        if $1[-1] != ?;
#          raise "Illegal character '#{$1}' in raw string \"#{string}\""
#        elsif $1[0] == ?&
#          if $5 and $5[0] == ?#
#            case ($5[1] == ?x ? $5[2..-1].to_i(16) : $5[1..-1].to_i)
#            when *VALID_CHAR
#            else
#              raise "Illegal character '#{$1}' in raw string \"#{string}\""
#            end
#          elsif $3 and !SUBSTITUTES.include?($1)
#            if !doctype or !doctype.entities.has_key?($3)
#              raise "Undeclared entity '#{$1}' in raw string \"#{string}\""
#            end
#          end
#        end
#      end
    end
  end
end
