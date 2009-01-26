
require 'rexml/formatters/pretty'

class REXML::Formatters::Pretty
    def wrap(string, width)
        return string if string.length <= width
        ret = ""
        while place = string.rindex(' ', width)
            string[place]="\n"
            ret += string[0,place]
            string = string[place+1..-1]
        end
        return ret + string
    end
end

