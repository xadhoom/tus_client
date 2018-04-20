defmodule TusClient.Options do
  @moduledoc false
  alias TusClient.Utils

  require Logger

  def request(url: url) do
    url
    |> HTTPoison.options()
    |> parse()
  end

  defp parse({:ok, %{status_code: status} = resp}) when status in [200, 204] do
    resp
    |> process()
  end

  defp parse({:ok, resp}) do
    Logger.error("OPTIONS response not handled: #{inspect(resp)}")
    {:error, :generic}
  end

  defp parse({:error, err}) do
    Logger.error("OPTIONS request failed: #{inspect(err)}")
    {:error, :transport}
  end

  defp process(%{headers: []}), do: {:error, :not_supported}

  defp process(%{headers: headers}) do
    with :ok <- check_supported_protocol(headers),
         {:ok, extensions} <- check_required_extensions(headers) do
      max_size =
        case Utils.get_header(headers, "tus-max-size") do
          v when is_binary(v) -> String.to_integer(v)
          _ -> nil
        end

      {:ok,
       %{
         max_size: max_size,
         extensions: extensions
       }}
    else
      {:error, :unfulfilled_extensions} = err -> err
      {:error, :not_supported} = err -> err
    end
  end

  defp check_required_extensions(headers) do
    supported =
      headers
      |> Utils.get_header("tus-extension")
      |> String.split(",")
      |> Enum.map(fn x -> String.trim(x) end)

    creation = Enum.member?(supported, "creation")
    expiration = Enum.member?(supported, "expiration")

    case creation and expiration do
      true -> {:ok, supported}
      false -> {:error, :unfulfilled_extensions}
    end
  end

  defp check_supported_protocol(headers) do
    case Utils.get_header(headers, "tus-version") do
      "1.0.0" -> :ok
      _ -> {:error, :not_supported}
    end
  end
end
