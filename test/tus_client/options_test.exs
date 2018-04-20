defmodule TusClient.OptionsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Plug.Test

  alias TusClient.Options

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "request/1 200", %{bypass: bypass} do
    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(200, "")
    end)

    assert {:ok, %{max_size: 1234, extensions: ["creation", "expiration"]}} =
             Options.request(url: endpoint_url(bypass.port))
  end

  test "request/1 204", %{bypass: bypass} do
    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(204, "")
    end)

    assert {:ok, %{max_size: 1234, extensions: ["creation", "expiration"]}} =
             Options.request(url: endpoint_url(bypass.port))
  end

  test "request/1 no version", %{bypass: bypass} do
    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> resp(200, "")
    end)

    assert {:error, :not_supported} =
             Options.request(url: endpoint_url(bypass.port))
  end

  test "request/1 different version", %{bypass: bypass} do
    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.1.0")
      |> resp(200, "")
    end)

    assert {:error, :not_supported} =
             Options.request(url: endpoint_url(bypass.port))
  end

  test "request/1 missing expected extensions", %{bypass: bypass} do
    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "expiration")
      |> resp(204, "")
    end)

    assert {:error, :unfulfilled_extensions} =
             Options.request(url: endpoint_url(bypass.port))
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/files"
end
