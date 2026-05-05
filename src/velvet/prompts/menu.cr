module Velvet
  module Prompts
    class Menu
      ESC    = "\e"
      UP     = "\e[A"
      DOWN   = "\e[B"
      CTRL_C = "\u0003"

      def self.fit_footer_text(text : String, cols : Int32, prefix_width : Int32 = 2) : String
        available = cols - prefix_width
        return "" if available <= 0
        return text if text.size <= available
        return "." * available if available <= 3

        keep = available - 3
        text[0, keep] + "..."
      end

      def self.terminal_columns : Int32
        cols = ENV["COLUMNS"]?.try(&.to_i?)
        cols && cols > 0 ? cols : 80
      end

      def self.footer_line(text : String) : String
        fitted = fit_footer_text(text, terminal_columns)
        "\e[48;5;238m\e[97m  #{fitted}\e[0m\r\n"
      end

      def self.bottom_footer_line(text : String, cols : Int32 = terminal_columns) : String
        fitted = fit_footer_text(text, cols)
        # Moving to row 999 is clamped by terminals to the last visible row.
        "\e7\e[999;1H\e[2K\e[48;5;238m\e[97m  #{fitted}\e[0m\e8"
      end

      def self.render_bottom_statusbar(text : String)
        print bottom_footer_line(text)
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
        print "  \e[36m#{@label}\e[0m\r\n"
        @choices.each_with_index do |choice, i|
          if i == @index
            print "  \e[36m> #{choice}\e[0m\r\n"
          else
            print "  \e[2m  #{choice}\e[0m\r\n"
          end
        end

        if (status = @status_text)
          Menu.render_bottom_statusbar(status)
        end
      end

      private def clear
        lines = @choices.size + 1
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
        print "  \e[36m#{@label}\e[0m \e[2m(space to select, enter to confirm)\e[0m\r\n"
        @choices.each_with_index do |choice, i|
          tick = @picked.includes?(choice) ? "◉" : "○"
          cursor = i == @index ? "\e[36m>" : " "
          reset = "\e[0m"
          print "  #{cursor} #{tick} #{choice}#{reset}\r\n"
        end

        if (status = @status_text)
          Menu.render_bottom_statusbar(status)
        end
      end

      private def clear
        lines = @choices.size + 1
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
