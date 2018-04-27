defmodule TusClient.Utils do
  @moduledoc false

  @doc false
  def get_header(headers, header_name) do
    headers
    |> Enum.map(fn {header, value} ->
      {String.downcase(header), value}
    end)
    |> get_header_impl(String.downcase(header_name))
  end

  def get_header_impl(headers, header_name) do
    headers
    |> Enum.filter(fn
      {^header_name, _value} ->
        true

      _ ->
        false
    end)
    |> Enum.at(0)
    |> case do
      {_hdr, value} -> value
      _ -> nil
    end
  end
end
