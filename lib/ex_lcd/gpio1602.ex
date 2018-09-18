defmodule ExLCD.GPIO1602 do
  require Logger
  alias Pigpiox.GPIO
  use Bitwise

  @low 0
  @high 1

  # Function set flags
  @mode_4bit 0x00
  @mode_8bit 0x10
  @font_5x8 0x00
  @font_5x10 0x04
  @lines_1 0x00
  @lines_2 0x08

  # Command flags
  @cmd_clear 0x01
  @cmd_home 0x02
  @cmd_entrymodeset 0x04
  @cmd_dispcontrol 0x08
  @cmd_cursorshift 0x10
  @cmd_functionset 0x20
  @cmd_setcgramaddr 0x40
  @cmd_setddramaddr 0x80

  # Entry mode flags
  @entry_left 0x02
  @entry_increment 0x01

  # Display control flags
  @ctl_display 0x04
  @ctl_cursor 0x02
  @ctl_blink 0x01

  # Shift flags
  @shift_display 0x08
  @shift_right 0x04

  @pins_4bit [:rs, :en, :d4, :d5, :d6, :d7]
  @pins_8bit [:d0, :d1, :d2, :d3]
  @lcd %{rs: 25, en: 24, d4: 23, d5: 22, d6: 18, d7: 17, rows: 2, cols: 20, font_5x10: false}
  # -------------------------------------------------------------------
  #
  # -------------------------------------------------------------------
  # CharDisplay.Driver Behaviour
  #

  def start(config) do
    init(config)
  end

  def stop(display) do
    {:ok, display} = command(display, {:display, :off})
    Logger.debug("Display : #{inspect(display)}")
    :ok
  end

  @doc false
  def execute do
    &command/2
  end

  # ------------------------------------------------------------------
  # Initialization
  #
  def init(config) do
    bits =
      case config[:d0] do
        nil -> @mode_4bit
        _ -> @mode_8bit
      end

    lines =
      case config.rows do
        1 -> @lines_1
        _ -> @lines_2
      end

    font =
      case config[:font_5x10] do
        true -> @font_5x10
        _ -> @font_5x8
      end

    pins =
      case bits do
        @mode_8bit -> @pins_4bit ++ @pins_8bit
        _ -> @pins_4bit
      end

    starting_function_state = @cmd_functionset ||| bits ||| font ||| lines

    display =
      Map.merge(config, %{
        function_set: starting_function_state,
        display_control: @cmd_dispcontrol,
        entry_mode: @cmd_entrymodeset,
        shift_control: @cmd_cursorshift
      })

    display
    |> reserve_gpio_pins(pins)
    |> rs(@low)
    |> en(@low)
    |> poi(bits)
    |> set_feature(:function_set)
    |> clear()
  end

  @doc """
    alias Nerves.Grove.Lcd1602GPIO
    config =  %{rs: 25, en: 24, d4: 23, d5: 22, d6: 18, d7: 17, rows: 2, cols: 20, font_5x10: false}
    pins_4bit = [:rs, :en, :d4, :d5, :d6, :d7]

    Lcd1602GPIO.reserve_gpio_pins(config, pins_4bit)

  """
  # setup GPIO output pins, add the pids to the config and return
  def reserve_gpio_pins(config, pins) do
    config
    |> Map.take(pins)
    |> Enum.map(fn {k, v} -> {String.to_atom("#{k}_pid"), GPIO.set_mode(v, :output)} end)
    |> Map.new()
    |> Map.merge(config)
  end

  # Software Power On Init (POI) for 4bit operation of HD44780 controller.
  # Since the display is initialized more than 50mS after > 4.7V on due to
  # OS/BEAM/App boot time this isn't strictly necessary but let's be
  # safe and do it anyway.
  defp poi(state, @mode_4bit) do
    state
    |> write_4_bits(0x03)
    |> write_4_bits(0x03)
    |> write_4_bits(0x03)
    |> write_4_bits(0x02)
  end

  # -------------------------------------------------------------------
  # ExLCD API callback
  #

  defp command(display, {:clear, _params}) do
    clear(display)
    {:ok, display}
  end

  defp command(display, {:home, _params}) do
    home(display)
    {:ok, display}
  end

  # translate string to charlist
  defp command(display, {:print, content}) do
    characters = String.to_charlist(content)
    command(display, {:write, characters})
  end

  defp command(display, {:write, content}) do
    content
    |> Enum.each(fn x -> write_a_byte(display, x, @high) end)

    {:ok, display}
  end

  defp command(display, {:set_cursor, {row, col}}) do
    {:ok, set_cursor(display, {row, col})}
  end

  defp command(display, {:cursor, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @ctl_cursor)}
  end

  defp command(display, {:cursor, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @ctl_cursor)}
  end

  defp command(display, {:blink, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @ctl_blink)}
  end

  defp command(display, {:blink, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @ctl_blink)}
  end

  defp command(display, {:display, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @ctl_display)}
  end

  defp command(display, {:display, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @ctl_display)}
  end

  defp command(display, {:autoscroll, :off}) do
    {:ok, disable_feature_flag(display, :entry_mode, @entry_increment)}
  end

  defp command(display, {:autoscroll, :on}) do
    {:ok, enable_feature_flag(display, :entry_mode, @entry_increment)}
  end

  defp command(display, {:rtl_text, :on}) do
    {:ok, disable_feature_flag(display, :entry_mode, @entry_left)}
  end

  defp command(display, {:ltr_text, :on}) do
    {:ok, enable_feature_flag(display, :entry_mode, @entry_left)}
  end

  # Scroll the entire display left (-) or right (+)
  defp command(display, {:scroll, 0}), do: {:ok, display}

  defp command(display, {:scroll, cols}) when cols < 0 do
    write_a_byte(display, @cmd_cursorshift ||| @shift_display)
    command(display, {:scroll, cols + 1})
  end

  defp command(display, {:scroll, cols}) do
    write_a_byte(display, @cmd_cursorshift ||| @shift_display ||| @shift_right)
    command(display, {:scroll, cols - 1})
  end

  # Scroll(move) cursor right
  defp command(display, {:right, 0}), do: {:ok, display}

  defp command(display, {:right, cols}) do
    write_a_byte(display, @cmd_cursorshift ||| @shift_right)
    command(display, {:right, cols - 1})
  end

  # Scroll(move) cursor left
  defp command(display, {:left, 0}), do: {:ok, display}

  defp command(display, {:left, cols}) do
    write_a_byte(display, @cmd_cursorshift)
    command(display, {:left, cols - 1})
  end

  # Program custom character to CGRAM
  defp command(display, {:char, idx, bitmap}) when idx in 0..7 and length(bitmap) === 8 do
    write_a_byte(display, @cmd_setcgramaddr ||| idx <<< 3)

    for line <- bitmap do
      write_a_byte(display, line, @high)
    end

    {:ok, display}
  end

  # All other commands are unsupported
  defp command(display, _), do: {:unsupported, display}

  # -------------------------------------------------------------------
  # Low-level device and utility functions
  #
  # Write 4 parallel bits to the device
  # Write a feature register to the controller and return the state.
  defp clear(display) do
    display
    |> write_a_byte(@cmd_clear)
    |> delay(3_000)
  end

  defp home(display) do
    display
    |> write_a_byte(@cmd_home)
    |> delay(3_000)
  end

  # DDRAM is organized as two 40 byte rows. In a 2x display the first row
  # maps to address 0x00 - 0x27 and the second row maps to 0x40 - 0x67
  # in a 4x display rows 0 & 2 are mapped to the first row of DDRAM and
  # rows 1 & 3 map to the second row of DDRAM. This means that the rows
  # are not contiguous in memory.
  #
  # row_offsets/1 determines the starting DDRAM address of each display row
  # and returns a map for up to 4 rows.
  defp row_offsets(cols) do
    %{0 => 0x00, 1 => 0x40, 2 => 0x00 + cols, 3 => 0x40 + cols}
  end

  # Set the DDRAM address corresponding to the {row,col} position
  defp set_cursor(display, {row, col}) do
    col = min(col, display[:cols] - 1)
    row = min(row, display[:rows] - 1)
    %{^row => offset} = row_offsets(display[:cols])
    write_a_byte(display, @cmd_setddramaddr ||| col + offset)
  end

  # Switch a register flag bit OFF(0). Return the updated state.
  defp disable_feature_flag(state, feature, flag) do
    %{state | feature => state[feature] &&& ~~~flag}
    |> set_feature(feature)
  end

  # Switch a register flag bit ON(1). Return the updated state.
  defp enable_feature_flag(state, feature, flag) do
    %{state | feature => state[feature] ||| flag}
    |> set_feature(feature)
  end

  defp set_feature(display, feature) do
    display |> write_a_byte(display[feature])
  end

  # Write a byte to the device
  defp write_a_byte(display, byte_to_write, rs_value \\ @low) do
    display |> rs(rs_value) |> delay(1_000)

    case display[:d0] do
      nil ->
        display
        |> write_4_bits(byte_to_write >>> 4)
        |> write_4_bits(byte_to_write)

      _ ->
        display
        |> write_8_bits(byte_to_write)
    end
  end

  # Write 8 parallel bits to the device
  defp write_8_bits(display, bits) do
    GPIO.write(display.d0, bits &&& 0x01)
    GPIO.write(display.d1, bits >>> 1 &&& 0x01)
    GPIO.write(display.d2, bits >>> 2 &&& 0x01)
    GPIO.write(display.d3, bits >>> 3 &&& 0x01)
    GPIO.write(display.d4, bits >>> 4 &&& 0x01)
    GPIO.write(display.d5, bits >>> 5 &&& 0x01)
    GPIO.write(display.d6, bits >>> 6 &&& 0x01)
    GPIO.write(display.d7, bits >>> 7 &&& 0x01)
    pulse_en(display)
  end

  defp write_4_bits(display, bits) do
    GPIO.write(display.d4, bits &&& 0x01)
    GPIO.write(display.d5, bits >>> 1 &&& 0x01)
    GPIO.write(display.d6, bits >>> 2 &&& 0x01)
    GPIO.write(display.d7, bits >>> 3 &&& 0x01)
    pulse_en(display)
  end

  defp rs(display, value) do
    GPIO.write(display[:rs], value)
    display
  end

  defp en(display, value) do
    GPIO.write(display[:en], value)
    display
  end

  defp pulse_en(display) do
    display
    |> en(@low)
    |> en(@high)
    |> en(@low)
  end

  def delay(display, microseconds) do
    # Unfortunately, BEAM does not provides microsecond precision
    # And if we need waiting, we MUST wait
    ms = max(round(microseconds / 1000), 1)
    Process.sleep(ms)
    display
  end
end
