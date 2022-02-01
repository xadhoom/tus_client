defmodule TusClient.Patch do
  @moduledoc false
  alias TusClient.Utils

  require Logger

  def request(url, offset, path, headers \\ [], opts \\ []) do
    path
    |> seek(offset)
    |> do_read(opts)
    |> do_request(url, offset, headers, opts)
  end

  defp do_request({:ok, data}, url, offset, headers, opts) do
    hdrs =
      [
        {"content-length", IO.iodata_length(data)},
        {"upload-offset", to_string(offset)}
      ]
      |> Utils.add_version_hdr()
      |> Utils.add_tus_content_type()
      |> add_custom_headers(headers)
      |> Enum.uniq()

    url
    |> HTTPoison.patch(data, hdrs, Utils.httpoison_opts([], opts))
    |> Utils.maybe_follow_redirect(
      &parse/1,
      &do_request({:ok, data}, &1, offset, headers, opts)
    )
  end

  defp do_request({:error, _} = err, _url, _offset, _headers, _opts), do: err

  defp parse({:ok, %{status_code: 204, headers: headers}}) do
    case Utils.get_header(headers, "upload-offset") do
      v when is_binary(v) -> {:ok, String.to_integer(v)}
      _ -> {:error, :protocol}
    end
  end

  defp parse({:ok, resp}) do
    Logger.error("PATCH response not handled: #{inspect(resp)}")
    {:error, :generic}
  end

  defp parse({:error, err}) do
    Logger.error("PATCH request failed: #{inspect(err)}")
    {:error, :transport}
  end

  defp do_read({:error, _} = err, _opts), do: err

  defp do_read({:ok, io_device}, opts) do
    data =
      case :file.read(io_device, get_read_len(opts)) do
        :eof -> {:error, :eof}
        res -> res
      end

    File.close(io_device)
    data
  end

  defp seek(path, offset) when is_binary(path) do
    path
    |> File.open([:read])
    |> seek(offset)
  end

  defp seek({:ok, io_device}, offset) do
    case :file.position(io_device, offset) do
      {:ok, _newpos} ->
        {:ok, io_device}

      err ->
        File.close(io_device)
        err
    end
  end

  defp seek({:error, err}, _offset) do
    Logger.error("Cannot open file for reading: #{inspect(err)}")
    {:error, :file_error}
  end

  defp get_read_len(opts) do
    opts
    |> Keyword.get(:chunk_len, 4_194_304)
  end

  defp add_custom_headers(hdrs1, hdrs2) do
    hdrs1 ++ hdrs2
  end
end
