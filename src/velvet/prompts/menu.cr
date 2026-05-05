module Velvet
  module Prompts
    class Menu
      ESC    = "\e"
      UP     = "\e[A"
      DOWN   = "\e[B"
      CTRL_C = "\u0003"

      def self.summary_line(text : String) : String
        "\e[2m  #{text}\e[0m\r\n"
      end

      def initialize(@label : String, @choices : Array(String), @status_text : String? = nil)
        @index = 0
      end

      def run : String
        raise Error.new("Interactive menu requires a TTY.") unless STDIN.tty?

        print "\e[?25l" # hide cursor
        render

        STDIN.raw do
          loop do
            key = read_key
            case key
            when UP         then move(-1)
            when DOWN       then move(1)
            when "\r", "\n" then break
            when CTRL_C     then raise Abort.new
            end
          end
        end

        @choices[@index]
      ensure
        print "\e[?25h" # restore cursor
      end

      private def move(dir : Int32)
        clear
        @index = (@index + dir) % @choices.size
        render
      end

      private def render
        if (status = @status_text)
          print Menu.summary_line(status)
        end

        print "  \e[36m#{@label}\e[0m\r\n"
        @choices.each_with_index do |choice, i|
          if i == @index
            print "  \e[36m> #{choice}\e[0m\r\n"
          else
            print "  \e[2m  #{choice}\e[0m\r\n"
          end
        end
      end

      private def clear
        lines = @choices.size + 1
        lines += 1 if @status_text
        print "\e[#{lines}A\e[J"
      end

      private def read_key : String
        ch = STDIN.read_char.to_s
        if ch == ESC
          STDIN.read_timeout = 0.05.seconds
          begin
            ch += STDIN.read_char.to_s
            ch += STDIN.read_char.to_s
          rescue IO::TimeoutError
          ensure
            STDIN.read_timeout = nil
          end
        end
        ch
      end
    end

    class MultiMenu
      def initialize(@label : String, @choices : Array(String), @selected : Array(String), @status_text : String? = nil)
        @index = 0
        @picked = Set(String).new(@selected)
      end

      ESC    = "\e"
      UP     = "\e[A"
      DOWN   = "\e[B"
      SPACE  = " "
      CTRL_C = "\u0003"

      def run : Array(String)
        raise Error.new("Interactive menu requires a TTY.") unless STDIN.tty?

        print "\e[?25l"
        render

        STDIN.raw do
          loop do
            key = read_key
            case key
            when UP         then move(-1)
            when DOWN       then move(1)
            when SPACE      then toggle
            when "\r", "\n" then break
            when CTRL_C     then raise Abort.new
            end
          end
        end

        @picked.to_a
      ensure
        print "\e[?25h"
      end

      private def move(dir : Int32)
        clear
        @index = (@index + dir) % @choices.size
        render
      end

      private def toggle
        choice = @choices[@index]
        if @picked.includes?(choice)
          @picked.delete(choice)
        else
          @picked.add(choice)
        end
        clear
        render
      end

      private def render
        if (status = @status_text)
          print Menu.summary_line(status)
        end

        print "  \e[36m#{@label}\e[0m \e[2m(space to select, enter to confirm)\e[0m\r\n"
        @choices.each_with_index do |choice, i|
          tick = @picked.includes?(choice) ? "◉" : "○"
          cursor = i == @index ? "\e[36m>" : " "
          reset = "\e[0m"
          print "  #{cursor} #{tick} #{choice}#{reset}\r\n"
        end
      end

      private def clear
        lines = @choices.size + 1
        lines += 1 if @status_text
        print "\e[#{lines}A\e[J"
      end

      private def read_key : String
        ch = STDIN.read_char.to_s
        if ch == ESC
          STDIN.read_timeout = 0.05.seconds
          begin
            ch += STDIN.read_char.to_s
            ch += STDIN.read_char.to_s
          rescue IO::TimeoutError
          ensure
            STDIN.read_timeout = nil
          end
        end
        ch
      end
    end
  end
end
