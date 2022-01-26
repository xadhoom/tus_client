defmodule TusClient.Head do
  @moduledoc false
  alias TusClient.Utils

  require Logger

  def request(url, headers \\ [], opts \\ []) do
    url
    |> HTTPoison.head(headers, Utils.httpoison_opts([], opts))
    |> Utils.maybe_follow_redirect(&parse/1, &request(&1, headers, opts))
  end

  defp parse({:ok, %{status_code: status} = resp}) when status in [200, 204] do
    resp
    |> process()
  end

  defp parse({:ok, %{status_code: status}}) when status in [403, 404, 410] do
    {:error, :not_found}
  end

  defp parse({:ok, resp}) do
    Logger.error("HEAD response not handled: #{inspect(resp)}")
    {:error, :generic}
  end

  defp parse({:error, err}) do
    Logger.error("HEAD request failed: #{inspect(err)}")
    {:error, :transport}
  end

  defp process(%{headers: []}), do: {:error, :preconditions}

  defp process(%{headers: headers}) do
    with {:ok, offset} <- get_upload_offset(headers),
         :ok <- ensure_no_cache(headers),
         {:ok, len} <- get_upload_len(headers) do
      {:ok,
       %{
         upload_offset: offset,
         upload_length: len
       }}
    else
      {:error, :no_offset} -> {:error, :preconditions}
      {:error, :wrong_cache} -> {:error, :preconditions}
    end
  end

  defp get_upload_len(headers) do
    case Utils.get_header(headers, "upload-length") do
      v when is_binary(v) -> {:ok, String.to_integer(v)}
      _ -> {:ok, nil}
    end
  end

  defp get_upload_offset(headers) do
    case Utils.get_header(headers, "upload-offset") do
      v when is_binary(v) -> {:ok, String.to_integer(v)}
      _ -> {:error, :no_offset}
    end
  end

  defp ensure_no_cache(headers) do
    case Utils.get_header(headers, "cache-control") do
      "no-store" -> :ok
      _ -> {:error, :wrong_cache}
    end
  end
end
