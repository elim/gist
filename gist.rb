#!/usr/bin/env ruby

=begin

INSTALL:

  curl http://github.com/elim/gist/tree/master%2Fgist.rb?raw=true > gist &&
  chmod 755 gist &&
  sudo mv gist /usr/local/bin/gist

=end

require 'open-uri'
require 'net/http'

class Gist
  GIST_URL = 'http://gist.github.com/%s.txt'
  attr_accessor(:private, :use_pit)

  def initialize(opts = {})
    self.private   = opts[:private]
    self.use_pit   = opts[:use_pit]
  end

  def run
    if $stdin.tty?
      puts read(ARGV.first)
    else
      puts write($stdin.read, @private)
    end
  end

  def read(gist_id)
    open(GIST_URL % gist_id).read
  end

  def write(content, private_gist)
    url = URI.parse('http://gist.github.com/gists')
    req = Net::HTTP.post_form(url, data(nil, nil, content, private_gist))
    copy req['Location']
  end

  private
  def copy(content)
    case RUBY_PLATFORM

    when /darwin/
      return content if `which pbcopy`.strip == ''
      IO.popen('pbcopy', 'r+') { |clip| clip.puts content }
    when /linux/
      return content if `which xclip`.strip == ''
      IO.popen('xclip', 'r+') { |clip| clip.puts content }
    end

    content
  end

  def data(name, ext, content, private_gist)
    return {
      'file_ext[gistfile1]'      => ext,
      'file_name[gistfile1]'     => name,
      'file_contents[gistfile1]' => content
    }.merge(private_gist ? { 'private' => 'on' } : {}).merge(auth)
  end

  def auth
    if @use_pit || ENV['GIST_USE_PIT']
      auth_pit
    else
      auth_gitconfig
    end || {}
  end

  def auth_gitconfig
    user  = `git config --global github.user`.strip
    token = `git config --global github.token`.strip

    unless (user.empty? || token.empty?)
      { :login => user, :token => token }
    end
  end

  def auth_pit
    require 'rubygems'
    require 'pit'

    config = Pit.get("github.com", :require => {
        "user"   => "your username in github",
        "token"  => "your token in github",
      })

    config['user'] && config['token'] &&
      {:login => config['user'], :token => config['token']}
  end
end

if $0 == __FILE__
  require 'optparse'
  opts = {:command => true}

  OptionParser.new do |parser|
    parser.instance_eval do
      self.banner = <<EOF
USE:
  cat file.txt | gist
  echo secret | gist -p  # or --private
  gist 1234 > something.txt

EOF
      on('-p', '--private', 'private post.') do
        opts[:private] = true
      end

      on('-P', '--pit', 'using Pit.') do
        opts[:use_pit]  = true
      end

      parse(ARGV)
    end
  end

  Gist.new(opts).run
end
