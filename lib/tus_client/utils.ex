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

  @doc false
  def add_version_hdr(headers) do
    headers ++ [{"tus-resumable", "1.0.0"}]
  end

  @doc false
  def add_tus_content_type(headers) do
    headers ++ [{"content-type", "application/offset+octet-stream"}]
  end

  @doc false
  def httpoison_opts(http_opts, tus_opts) do
    ssl_opts = tus_opts |> Keyword.get(:ssl, [])
    hackney_opts = tus_opts |> Keyword.get(:hackney, [])
    http_opts ++ ssl_opts ++ hackney_opts
  end

  defp get_header_impl(headers, header_name) do
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
