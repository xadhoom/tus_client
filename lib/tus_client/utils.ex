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
    follow_redirect = tus_opts |> Keyword.get(:follow_redirect, false)

    http_opts ++ [ssl: ssl_opts] ++ [follow_redirect: follow_redirect]
  end

  @doc false
  def maybe_follow_redirect(
        {:ok, %HTTPoison.MaybeRedirect{redirect_url: new_loc}},
        _parse_fn,
        rereq_fn
      )
      when is_binary(new_loc) do
    rereq_fn.(new_loc)
  end

  # TODO remove this when https://github.com/edgurgel/httpoison/issues/453 is fixed
  def maybe_follow_redirect(
        {:ok, %HTTPoison.MaybeRedirect{headers: headers}} = resp,
        parse_fn,
        rereq_fn
      ) do
    case get_header(headers, "location") do
      new_loc when is_binary(new_loc) -> rereq_fn.(new_loc)
      nil -> parse_fn.(resp)
    end
  end

  def maybe_follow_redirect(response, parse_fn, _rereq_fn) do
    parse_fn.(response)
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
