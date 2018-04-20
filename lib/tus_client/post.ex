defmodule TusClient.Post do
  @moduledoc false
  alias TusClient.Utils

  require Logger

  def request(url: url, path: path) do
    path
    |> get_filesize()
    |> do_request(url)
  end

  defp do_request({:ok, size}, url) do
    hdrs = [{"upload-length", to_string(size)}]

    url
    |> HTTPoison.post("", hdrs)
    |> parse()
  end

  defp do_request(res, _url) do
    res
  end

  defp parse({:ok, %{status_code: 201} = resp}) do
    resp
    |> process()
  end

  defp parse({:ok, %{status_code: 413}}) do
    {:error, :too_large}
  end

  defp parse({:ok, resp}) do
    Logger.error("POST response not handled: #{inspect(resp)}")
    {:error, :generic}
  end

  defp parse({:error, err}) do
    Logger.error("POST request failed: #{inspect(err)}")
    {:error, :transport}
  end

  defp process(%{headers: []}), do: {:error, :not_supported}

  defp process(%{headers: headers}) do
    case get_location(headers) do
      {:ok, location} -> {:ok, %{location: location}}
      _ -> {:error, :location}
    end
  end

  defp get_location(headers) do
    case Utils.get_header(headers, "location") do
      v when is_binary(v) -> {:ok, v}
      _ -> {:error, :location}
    end
  end

  defp get_filesize(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> {:ok, size}
      _ -> {:error, :file_error}
    end
  end
end
