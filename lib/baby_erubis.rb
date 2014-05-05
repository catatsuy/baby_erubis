# -*- coding: utf-8 -*-

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2014 kuwata-lab.com all rights reserved $
### $License: MIT License $
###


##
## Yet another eRuby implementation, based on Erubis.
##
## * Small and fast
## * Easy to customize
## * Supports HTML as well as plain text
## * Accepts both template file and template string
##
## Example:
##
##   ## render template string
##   template = BabyErubis::Html.new <<'END', __FILE__, __LINE__+1
##     <h1><%= @title %></h1>
##     <% for item in @items %>
##       <p><%= item %></p>
##     <% end %>
##   END
##   context = {:title=>'Example', :items=>['<AAA>', 'B&B', '"CCC"']}
##   output = template.render(context)
##   print output
##
##   ## render template file
##   templat = BabyErubis::Html.load('example.html.erb', 'utf-8')
##   context = {:title=>'Example', :items=>['<AAA>', 'B&B', '"CCC"']}
##   output = template.render(context)
##   print output
##

module BabyErubis


  class Template

    USE_FREEZE = (''.freeze).equal?(''.freeze)   # Ruby 2.1 feature

    def self.load(filename, encoding='utf-8')
      input = File.open(filename, "rb:#{encoding}") {|f| f.read() }
      return self.new(input, filename)
    end

    def initialize(input=nil, filename=nil, linenum=1)
      compile(input, filename, linenum) if input
    end

    attr_reader :src

    #EMBED_REXP = /(^[ \t]*)?<%(==?|\#)?(.*?)%>([ \t]*\r?\n)?/m
    EMBED_REXP = /(^[ \t]*)?<%(==?|\#)? ?(.*?) ?%>([ \t]*\r?\n)?/m

    def embed_rexp
      return EMBED_REXP
    end
    protected :embed_rexp

    def compile(input, filename=nil, linenum=1)
      src = convert(input)
      @src = src
      @proc = eval("proc { #{src} }", empty_binding(), filename || '(eRuby)', linenum)
      return self
    end

    def convert(input)
      src = "_buf = '';"       # preamble
      pos = 0
      rexp = embed_rexp()
      input.scan(rexp) do |lspace, ch, code, rspace|
        match = Regexp.last_match
        text  = input[pos, match.begin(0) - pos]
        pos   = match.end(0)
        src << _t(text)
        if ! ch                # statement
          if lspace && rspace
            src << "#{lspace} #{code};#{rspace}"
          else
            src << _t(lspace) << " #{code};" << _t(rspace)
          end
        elsif ch == '='        # expression (escaping)
          src << _t(lspace) << " _buf << #{escaped_expr(code)};" << _t(rspace)
        elsif ch == '=='       # expression (without escaping)
          src << _t(lspace) << " _buf << (#{code}).to_s;" << _t(rspace)
        elsif ch == '#'        # comment
          src << _t(lspace) << ("\n" * code.count("\n")) << _t(rspace)
        else
          raise "** unreachable: ch=#{ch.inspect}"
        end
      end
      text = pos == 0 ? input : input[pos..-1]   # or $' || input
      src << _t(text)
      src << " _buf.to_s\n"    # postamble
      return src
    end

    def render(context={})
      ctxobj = context.is_a?(Hash) ? new_context(context) : context
      return ctxobj.instance_eval(&@proc)
    end

    def new_context(hash)
      return TemplateContext.new(hash)
    end

    protected

    def escaped_expr(code)
      return "(#{code}).to_s"
    end

    private

    def build_text(text)
      freeze = self.class.const_get(:USE_FREEZE) ? '.freeze' : ''
      return text && !text.empty? ? " _buf << '#{escape_text(text)}'#{freeze};" : ''
      #return text && !text.empty? ? " _buf << %q`#{escape_text(text)}`#{freeze};" : ''
    end
    alias _t build_text

    def escape_text(text)
      return text.gsub!(/['\\]/, '\\\\\&') || text
      #return text.gsub!(/[`\\]/, '\\\\\&') || text
    end

    def empty_binding
      return binding()
    end

  end
  Text = Template              # for shortcut


  class TemplateContext

    def initialize(vars={})
      vars.each do |k, v|
        instance_variable_set("@#{k}", v)
      end if vars
    end

    def [](key)
      return instance_variable_get("@#{key}")
    end

    def []=(key, value)
      instance_variable_set("@#{key}", value)
    end

    def escape(value)
      return value.to_s
    end

  end


  class HtmlTemplate < Template

    protected

    def escaped_expr(code)
      return "escape(#{code})"   # escape() is defined in HtmlTemplateContext
    end

    def new_context(hash)
      return HtmlTemplateContext.new(hash)
    end

  end
  Html = HtmlTemplate          # for shortcut


  module HtmlEscaper

    HTML_ESCAPE = {'&'=>'&amp;', '<'=>'&lt;', '>'=>'&gt;', '"'=>'&quot;', "'"=>'&#39;'}

    module_function

    def escape(value)
      return value.to_s.gsub(/[<>&"']/, HTML_ESCAPE)  # for Ruby 1.9 or later
    end

    if RUBY_VERSION < '1.9'
      def escape(value)
        return value.to_s.gsub(/&/, '&amp;').gsub(/</, '&lt;').gsub(/>/, '&gt;').gsub(/"/, '&quot;').gsub(/'/, '&#39;')
      end
    end

  end


  class HtmlTemplateContext < TemplateContext
    include HtmlEscaper
  end


end
