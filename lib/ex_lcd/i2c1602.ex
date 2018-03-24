defmodule ExLCD.I2C1602 do
  alias ExLCD.I2C1602.Display
  import ExLCD.I2C1602.Commands

  use Bitwise
  use ExLCD.Driver
  use ExLCD.IO

  # commands
  @lcd_cleardisplay 0x01
  @lcd_returnhome 0x02
  @lcd_entrymodeset 0x04
  @lcd_displaycontrol 0x08
  @lcd_cursorshift 0x10
  @lcd_functionset 0x20
  @lcd_setcgramaddr 0x40
  @lcd_setddramaddr 0x80

  # flags for display entry mode
  @lcd_entryright 0x00
  @lcd_entryleft 0x02
  @lcd_entryshiftincrement 0x01
  @lcd_entryshiftdecrement 0x00

  # flags for display on/off control
  @lcd_displayon 0x04
  @lcd_displayoff 0x00
  @lcd_cursoron 0x02
  @lcd_cursoroff 0x00
  @lcd_blinkon 0x01
  @lcd_blinkoff 0x00

  # flags for display/cursor shift
  @lcd_displaymove 0x08
  @lcd_cursormove 0x00
  @lcd_moveright 0x04
  @lcd_moveleft 0x00

  # flags for function set
  @lcd_8bitmode 0x10
  @lcd_4bitmode 0x00
  @lcd_2line 0x08
  @lcd_1line 0x00
  @lcd_5x10dots 0x04
  @lcd_5x8dots 0x00

  # flags for backlight control
  @lcd_backlight 0x08
  @lcd_nobacklight 0x00

  # enable bit
  @en 0b00000100
  # read/write bit
  @rw 0b00000010
  # register select bit
  @rs 0b00000001

  @spec start(map) :: Display
  def start(config) do
    lines =
      case config.rows do
        1 -> @lcd_1line
        _ -> @lcd_2line
      end

    font =
      case config[:font_5x10] do
        true -> @lcd_5x10
        _ -> @lcd_5x8
      end

    device =
      case config[:i2c_device] do
        val -> val
        _ -> "i2c-1"
      end

    %Display{
      lines: lines,
      lcd_display_function: @lcd_4bitmode ||| lines || font,
      i2c_pid: pid
    }
  end

  @spec stop(Display) :: :ok
  def stop(display) do
    :ok
  end

  # specs for commands using this driver should be:
  # function(I2C1602.Display, operation) :: I2C1602.Display
  @doc false
  def execute do
    &command/2
  end
end

defmodule ExLCD.I2C1602.Display do
  defstruct i2c_device: "i2c-1",
            i2c_address: 0x27,
            i2c_pid: nil,
            lines: 2,
            backlight_value: @lcd_nobacklight,
            display_function: @lcd_4bitmode ||| @lcd_1line ||| @lcd_5x8dots,
            display_mode: @lcd_entryleft ||| @lcd_entryshiftdecrement
end

defmodule ExLCD.I2C1602.Commands do
  require ExLCD.I2C1602.Constants
  alias ExLCD.I2C1602.Display

  # Any command not implemented here is unsupported
  def command(display, _), do: {:unsupported, display}

  def command(display, {:clear, _params}) do
    clear(display)
    {:ok, display}
  end

  def command(display, {:home, _params}) do
    home(display)
    {:ok, display}
  end

  # --- Private Functions ---

  defp clear(display) do
  end

  defp home(display) do
  end

  defp send(display, value) do
    send(value, 0)
  end

  # --- Low-level Functions
  defp send(display, value, mode) do
    display
    |> write_four_bits(<<(value &&& 0xF0) ||| mode>>)
    |> write_four_bits(<<(value <<< 4 &&& 0xF0) ||| mode>>)
  end

  defp write_four_bits(display, data) do
    display
    |> expander_write(display, data)
    |> pulse_enable(display, data)
  end

  @spec expander_write(Display, binary) :: Display
  defp expander_write(display, data) do
    %Diaplay{i2c_pid: pid, backlight_value: backlight} = display
    @i2c.write(pid, <<data ||| backlight>>)

    display
  end

  defp pulse_enable(display, data) do
    display
    |> expander_write(<<data ||| @en>>)
    |> delay(1)
    |> expander_write(<<data ||| ~~~@en>>)
    |> delay(50)
  end

  def delay(display, microseconds) do
    # Unfortunately, BEAM does not provides microsecond precision
    # And if we need waiting, we MUST wait
    ms = max(round(microseconds / 1000), 1)
    Process.sleep(ms)
    display
  end
end
