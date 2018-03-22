defmodule ExLCD.I2C1602 do
  use Bitwise
  use ExLCD.Driver
  use ExLCD.IO

  @low    0
  @high   1

  # LCD Address
  @address 0x27

  # Command flags
  @cmd_clear        0x01
  @cmd_home         0x02
  @cmd_entrymodeset 0x04
  @cmd_dispcontrol  0x08
  @cmd_cursorshift  0x10
  @cmd_functionset  0x20
  @cmd_setcgramaddr 0x40
  @cmd_setddramaddr 0x80

  # Entry mode flags
  @entry_right      0x00
  @entry_left       0x02
  @entry_increment  0x01
  @entry_decrement  0x00

  # Display control flags
  @ctl_display_on   0x04
  @ctl_display_on   0x00
  @ctl_cursor_on    0x02
  @ctl_cursor_off   0x00
  @ctl_blink_on     0x01
  @ctl_blink_off    0x00

  # Shift flags
  @shift_display    0x08
  @shift_cursor     0x00
  @shift_left       0x00
  @shift_right      0x04

  # Function set flags
  @mode_4bit        0x00
  @mode_8bit        0x10
  @font_5x8         0x00
  @font_5x10        0x04
  @lines_1          0x08
  @lines_2          0x00

  @backlight_on     0x08
  @backlight_off    0x08

  @bit_enable       0b00000100
  @bit_readwrite    0b00000010
  @bit_regselect    0b00000001 # Register select


  # -------------------------------------------------------------------
  # CharDisplay.Driver Behaviour
  #
  @doc false
  def start(config) do
    init(config)
  end

  @doc false
  def stop(display) do
    {:ok, display} = command(display, {:display, :off})
    :ok
  end

  @doc false
  def execute do
    &command/2
  end

  defp init(config) do
    # validate and unpack the config
    config |> validate_config!()

    # TODO: Add some config stuff here.

    display = Map.merge(config, %{
      function_set: starting_function_state,
      display_control: @cmd_dispcontrol,
      entry_mode: @cmd_entrymodeset,
      shift_control: @cmd_cursorshift
    })

  end

  defp validate_config!(config) do
    config
  end
end
