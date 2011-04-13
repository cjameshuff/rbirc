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
        puts "Received ping: #{msg}"
        send_irc("PONG :#{msg[:text]}")
    end
    
    def rx_pong(msg)
        puts "Received pong: #{msg}"
    end
    
    def rx_notice(msg)
        puts "Server notice: #{msg[:text]}"
        @server_notices.push(msg[:text])
    end
    
    def rx_privmsg(msg)
        puts "Received message: #{msg}"
    end
    
    def rx_join(msg)
        # :Nick!Nick@blahblah.net JOIN :#SomeChannel
        nick = msg[:prefix].partition('!')[1..-1]
        channel = msg[:text]
        puts "#{nick} joined #{msg[:text]}"
        
        if(!@channels[channel][:users].include?(nick))
            @channels[channel][:users].push(nick)
        end
        
        if(nick == @nick)
            @channels[channel][:joined] = true
        end
    end
    
    def rx_part(msg)
        nick = msg[:prefix].partition('!')[1..-1]
        channel = msg[:params][0]
        puts "#{nick} left #{msg[:text]}"
        
        @channels[channel][:users].delete(nick)
        
        if(nick == @nick)
            @channels.delete(channel)
        end
    end
    
    def rx_quit(msg)
        puts "Received quit: #{msg}"
        # TODO: iterate through all channels, remove user name
    end
    
    def rx_mode(msg)
        puts "Mode: #{msg}"
    end
    
    # 001-005: server greeting
    def rx_001(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
        @connected = true
    end
    
    def rx_002(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    def rx_003(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    def rx_004(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    def rx_005(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # user/server count
    def rx_251(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # operator count
    def rx_252(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # channel count
    def rx_254(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # client count
    def rx_255(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # local users
    def rx_265(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # global users
    def rx_266(msg)
        puts msg[:rawmsg]
        @server_info.push(msg[:text])
    end
    
    # TOPIC
    def rx_332(msg)
        puts "Topic for #{msg[:params][1]}: #{msg[:text]}"
        @channels[msg[:params][1]][:topic] = msg[:text]
    end
    
    # TOPIC end
    def rx_333(msg)
    end
    
    # NAMES
    def rx_353(msg)
        puts "Currently in #{msg[:params][2]}: #{msg[:text].split(' ')}"
        channel = msg[:params][2]
        # assume list is complete
        @channels[channel][:users] = msg[:text].split(' ')
    end
    
    # end NAMES
    def rx_366(msg)
        puts msg[:rawmsg]
    end
    
    # MOTD
    def rx_372(msg)
        puts msg[:rawmsg]
        @server_motd.push(msg[:text])
    end
    
    # MOTD start
    def rx_375(msg)
        puts msg[:rawmsg]
        @server_motd.push(msg[:text])
    end
    
    # MOTD end
    def rx_376(msg)
        puts msg[:rawmsg]
    end
end # class IRC_Connection

end # module IRC
