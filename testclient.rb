#!/usr/bin/env ruby
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

$: << '.'

require 'pp'
require 'fileutils'
require 'rbirc/rbirc'
require 'json'
require 'json/add/core'

if(File.exists?('ircopts.json'))
    opts = JSON.parse(File.read('ircopts.json'))
    # JSON uses string keys, so convert them to symbols
    opts.replace(opts.inject({}) {|h, (k, v)| h[k.to_sym] = v; h})
else
    opts = {
        server: "irc.blahblah.net",
        port: 6667,
        shortusername: 'ShortName',
        realusername: 'Long Name',
        nick: 'NickName',
        joinchannel: '#somechannel',
        logging: 'raw',
        logdir: 'logs',
        logfileprefix: 'irclog_'
    }
    # Again, JSON expects string keys, so convert them before writing
    File.open('ircopts.json', 'w') {|f|
        f.write(JSON.pretty_generate(opts.inject({}) {|h, (k, v)| h[k.to_s] = v; h}))
    }
end

class ClientConnection < IRC::IRC_Connection
    def initialize(server, port, options = {})
        super(server, port, options)
        
        if(options[:logging] != nil)
            if(!File.exists?(options[:logdir]))
                FileUtils.mkdir_p(options[:logdir])
            end
            @lastlogged = Time.now
            pp 
            @logfile = File.open(logfilename(@lastlogged), 'a')
        end
    end
    
    def logfilename(t)
        logfileprefix = options[:logfileprefix]
        logdir = options[:logdir]
        "#{logdir}/#{logfileprefix}#{sprintf('%0.4d.%0.2d.%0.2d', t.year, t.month, t.mday)}.txt"
    end
    
    def rawlog(msg)
        now = Time.now
        if(now.mday != @lastlogged.mday)
            @logfile.close()
            @logfile = File.open(logfilename(now), 'a')
        end
        @lastlogged = now
        @logfile.write(msg[:rawmsg])
    end

    def handle_msg(msg)
        super(msg)
        if(options[:logging] == "raw")
            # Log everything but pings and pongs
            if(msg[:cmd] != 'PING' && msg[:cmd] != 'PONG')
                rawlog(msg)
            end
        end
    end # handle_msg()
end

irc = ClientConnection.new(opts[:server], opts[:port], opts)
irc.connect()
irc.nick(opts[:nick])
irc.join(opts[:joinchannel])

begin
    while(1)
        irc.poll()
    end
rescue Interrupt
rescue Exception => detail
    puts detail.message()
    print detail.backtrace.join("\n")
    retry
end
