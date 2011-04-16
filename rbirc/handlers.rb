#*******************************************************************************
#    Copyright (c) 2011, Christopher James Huff
#    All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#*******************************************************************************

module IRC

class IRC_Connection
    # IRC message handlers
    def rx_unimplemented_msg(msg)
        puts "IRC message not implemented:"
        pp msg
    end
    
    def rx_ping(msg)
        puts "Received ping: #{msg.rawmsg}"
        send_irc("PONG :#{msg.text}")
    end
    
    def rx_pong(msg)
        update_lag(Time.now.to_f - msg.text.to_f)
        @waiting_for_pong = false
    end
    
    def rx_notice(msg)
        puts "Notice: #{msg.text}"
        @server_notices.push(msg.text)
    end
    
    def rx_privmsg(msg)
        channel = msg.params[0]
        puts "#{channel} <#{msg.nick}>: #{msg.text}"
    end
    
    def rx_join(msg)
        nick = msg.nick
        channel = msg.text
        puts "#{nick} joined #{channel}"
        
        if(!@channels[channel][:users].include?(nick))
            @channels[channel][:users].push(nick)
        end
        
        if(nick == @nick)
            @channels[channel][:joined] = true
        end
    end
    
    def rx_part(msg)
        nick = msg.prefix.partition('!')[1..-1]
        channel = msg.params[0]
        puts "#{nick} left #{msg.text}"
        
        @channels[channel][:users].delete(nick)
        
        if(nick == @nick)
            @channels.delete(channel)
        end
    end
    
    def rx_nick(msg)
        puts "#{msg.nick} is now known as #{msg.text}"
        @channels.each {|ch|
            if(!ch[:users].include?(msg.nick))
                ch[:users].delete(msg.nick)
                ch[:users].push(msg.text)
            end
        }
    end
    
    def rx_quit(msg)
        puts "Received quit: #{msg.rawmsg}"
        @channels.each {|ch|
            if(!ch[:users].include?(msg.nick))
                ch[:users].delete(msg.nick)
            end
        }
    end
    
    def rx_mode(msg)
        puts "Mode: #{msg.rawmsg}"
    end
    
    # 001-005: server greeting
    def rx_001(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
        @connected = true
    end
    
    def rx_002(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    def rx_003(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    def rx_004(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    def rx_005(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # user/server count
    def rx_251(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # operator count
    def rx_252(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # channel count
    def rx_254(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # client count
    def rx_255(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # local users
    def rx_265(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # global users
    def rx_266(msg)
        pp msg.rawmsg
        @server_info.push(msg.text)
    end
    
    # TOPIC
    def rx_332(msg)
        puts "Topic for #{msg.params[1]}: #{msg.text}"
        @channels[msg.params[1]][:topic] = msg.text
    end
    
    # TOPIC end
    def rx_333(msg)
    end
    
    # NAMES
    def rx_353(msg)
        puts "Currently in #{msg.params[2]}: #{msg.text.split(' ')}"
        channel = msg.params[2]
        # assume list is complete
        @channels[channel][:users] = msg.text.split(' ')
    end
    
    # end NAMES
    def rx_366(msg)
        pp msg.rawmsg
    end
    
    # MOTD
    def rx_372(msg)
        pp msg.rawmsg
        @server_motd.push(msg.text)
    end
    
    # MOTD start
    def rx_375(msg)
        pp msg.rawmsg
        @server_motd.push(msg.text)
    end
    
    # MOTD end
    def rx_376(msg)
        pp msg.rawmsg
    end
    
    def rx_421(msg)
        puts "Server error, unknown IRC command"
        pp msg.rawmsg
    end
end # class IRC_Connection

end # module IRC
