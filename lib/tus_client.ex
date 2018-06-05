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

  @spec upload(
          binary(),
          binary(),
          list(
            {:metadata, binary()}
            | {:max_retries, integer()}
            | {:chunk_len, integer()}
            | {:headers, list()}
            | {:ssl, list()}
            | {:hackney, list()}
          )
        ) :: {:ok, binary} | {:error, upload_error()}
  def upload(base_url, path, opts \\ []) do
    md = Keyword.get(opts, :metadata)

    with {:ok, _} <- Options.request(base_url, get_headers(opts)),
         {:ok, %{location: loc}} <-
           Post.request(base_url, path, get_headers(opts), metadata: md) do
      do_patch(loc, path, opts)
    end
  end

  defp do_patch(location, path, opts) do
    location
    |> Patch.request(0, path, get_headers(opts), opts)
    |> do_patch(location, path, opts, 1, 0)
  end

  defp do_patch({:ok, new_offset}, location, path, opts, _retry_nr, _offset) do
    case file_size(path) do
      ^new_offset ->
        {:ok, location}

      _ ->
        location
        |> Patch.request(new_offset, path, get_headers(opts), opts)
        |> do_patch(location, path, opts, 0, new_offset)
    end
  end

  defp do_patch({:error, reason}, location, path, opts, retry_nr, offset) do
    case get_max_retries(opts) do
      ^retry_nr ->
        Logger.error("Max retries reached, bailing out...")
        {:error, :too_many_errors}

      _ ->
        Logger.warn("Patch error #{inspect(reason)}, retrying...")

        location
        |> Patch.request(offset, path, get_headers(opts), opts)
        |> do_patch(location, path, opts, retry_nr + 1, offset)
    end
  end

  defp file_size(path) do
    {:ok, %{size: size}} = File.stat(path)
    size
  end

  defp get_max_retries(opts) do
    opts
    |> Keyword.get(:max_retries, 3)
  end

  defp get_headers(opts) do
    opts |> Keyword.get(:headers, [])
  end
end
