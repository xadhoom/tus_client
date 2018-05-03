defmodule TusClient do
  @moduledoc """
  A minimal client for the https://tus.io protocol.
  """
  alias TusClient.{Options, Post, Patch}

  require Logger

  @type upload_error ::
          :file_error
          | :generic
          | :location
          | :not_supported
          | :too_large
          | :too_many_errors
          | :transport
          | :unfulfilled_extensions

  @spec upload(binary(), binary(), list({:metadata | :headers, binary()})) ::
          {:ok, binary} | {:error, upload_error()}
  def upload(base_url, path, opts \\ []) do
    md = Keyword.get(opts, :metadata)
    hdrs = Keyword.get(opts, :headers, [])

    with {:ok, _} <- Options.request(base_url, hdrs),
         {:ok, %{location: loc}} <-
           Post.request(base_url, path, hdrs, metadata: md) do
      do_patch(loc, path, hdrs)
    end
  end

  defp do_patch(location, path, headers) do
    location
    |> Patch.request(0, path, headers)
    |> do_patch(location, path, headers, 1, 0)
  end

  defp do_patch({:ok, new_offset}, location, path, headers, _retry_nr, _offset) do
    case file_size(path) do
      ^new_offset ->
        {:ok, location}

      _ ->
        location
        |> Patch.request(new_offset, path, headers)
        |> do_patch(location, path, headers, 0, new_offset)
    end
  end

  defp do_patch({:error, reason}, location, path, headers, retry_nr, offset) do
    case max_retries() do
      ^retry_nr ->
        Logger.error("Max retries reached, bailing out...")
        {:error, :too_many_errors}

      _ ->
        Logger.warn("Patch error #{inspect(reason)}, retrying...")

        location
        |> Patch.request(offset, path, headers)
        |> do_patch(location, path, headers, retry_nr + 1, offset)
    end
  end

  defp file_size(path) do
    {:ok, %{size: size}} = File.stat(path)
    size
  end

  defp max_retries do
    :tus_client
    |> Application.get_env(TusClient)
    |> Keyword.get(:max_retries, 3)
  end
end
