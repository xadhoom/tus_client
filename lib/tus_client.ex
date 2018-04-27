defmodule TusClient do
  @moduledoc """
  A minimal client for the https://tus.io protocol.
  """
  alias TusClient.{Options, Post, Patch}

  require Logger

  @spec upload(binary(), binary(), list({binary, binary})) :: {:ok, binary}
  def upload(base_url, path, _headers \\ []) do
    with {:ok, _} <- Options.request(url: base_url),
         {:ok, %{location: loc}} <- Post.request(url: base_url, path: path) do
      do_patch(loc, path)
    end
  end

  defp do_patch(location, path) do
    Patch.request(location, 0, path)
    |> do_patch(location, path, 1, 0)
  end

  defp do_patch({:ok, new_offset}, location, path, _retry_nr, _offset) do
    case file_size(path) do
      ^new_offset ->
        {:ok, location}

      _ ->
        Patch.request(location, new_offset, path)
        |> do_patch(location, path, 0, new_offset)
    end
  end

  defp do_patch({:error, reason}, location, path, retry_nr, offset) do
    case max_retries() do
      ^retry_nr ->
        Logger.error("Max retries reached, bailing out...")
        {:error, :too_many_errors}

      _ ->
        Logger.warn("Patch error #{inspect(reason)}, retrying...")

        Patch.request(location, offset, path)
        |> do_patch(location, path, retry_nr + 1, offset)
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
