defmodule ExLCD.IO do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @gpio Application.get_env(:ex_lcd, :gpio, ElixirALE.GPIO)
      @i2c Application.get_env(:ex_lcd, :i2c, ElixirALE.I2C)
      @spi Application.get_env(:ex_lcd, :spi, ElixirALE.SPI)
    end
  end
end

defmodule ExLCD.GPIO do
  @moduledoc false

  def start_link(pin, _pin_direction \\ :foo, _opts \\ []) do
    {:ok, pin}
  end

  def write(pin, value) do
    MockHD44780.write(pin, value)
    :ok
  end

  def release(_pin), do: :ok
end

defmodule ExLCD.I2C do
  @moduledoc false
  use GenServer

end

defmodule ExLCD.SPI do
  @moduledoc false
  use GenServer

end
