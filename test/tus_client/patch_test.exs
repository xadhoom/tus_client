defmodule TusClient.PatchTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Plug.Test

  alias TusClient.Patch

  setup do
    bypass = Bypass.open()
    {:ok, path} = random_file()

    on_exit(fn ->
      File.rm!(path)
    end)

    {:ok, bypass: bypass, tmp_file: path}
  end

  test "request/3 204", %{bypass: bypass, tmp_file: path} do
    data = "yaddayaddamohmoh"
    filen = random_file_name()
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "PATCH", "/files/#{filen}", fn conn ->
      {:ok, body, conn} = read_body(conn)
      assert data == body

      len = String.length(data) |> to_string()

      conn
      |> put_resp_header("upload-offset", len)
      |> resp(204, "")
    end)

    assert {:ok, String.length(data)} ==
             Patch.request(
               location: endpoint_url(bypass.port, "#{filen}"),
               offset: 0,
               path: path
             )
  end

  test "request/3 204 from offset", %{bypass: bypass, tmp_file: path} do
    data = "yaddayaddamohmoh"
    filen = random_file_name()
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "PATCH", "/files/#{filen}", fn conn ->
      {:ok, body, conn} = read_body(conn)
      # we're sending only last 3 chars, from a 16 len
      assert body == "moh"

      len = String.length(data) |> to_string()

      conn
      |> put_resp_header("upload-offset", len)
      |> resp(204, "")
    end)

    assert {:ok, String.length(data)} ==
             Patch.request(
               location: endpoint_url(bypass.port, "#{filen}"),
               offset: 13,
               path: path
             )
  end

  test "request/3 unexpected status code", %{bypass: bypass, tmp_file: path} do
    filen = random_file_name()

    Bypass.expect_once(bypass, "PATCH", "/files/#{filen}", fn conn ->
      conn
      |> resp(412, "")
    end)

    assert {:error, :generic} ==
             Patch.request(
               location: endpoint_url(bypass.port, "#{filen}"),
               offset: 0,
               path: path
             )
  end

  test "request/3 204 eof", %{bypass: bypass, tmp_file: path} do
    filen = random_file_name()

    assert {:error, :eof} =
             Patch.request(
               location: endpoint_url(bypass.port, "#{filen}"),
               offset: 13,
               path: path
             )
  end

  test "request/3 204 nofile", %{bypass: bypass, tmp_file: _path} do
    filen = random_file_name()

    assert {:error, :file_error} =
             Patch.request(
               location: endpoint_url(bypass.port, "#{filen}"),
               offset: 13,
               path: "foobar"
             )
  end

  test "request/3 204 transport error", %{bypass: _bypass, tmp_file: path} do
    filen = random_file_name()

    assert {:error, :transport} =
             Patch.request(
               location: endpoint_url(0, "#{filen}"),
               offset: 0,
               path: path
             )
  end

  defp endpoint_url(port, fname), do: "http://localhost:#{port}/files/#{fname}"

  defp random_file do
    path = "/tmp/#{random_file_name()}"
    File.write!(path, "yadda")
    {:ok, path}
  end

  defp random_file_name do
    Base.hex_encode32(
      :crypto.strong_rand_bytes(8),
      case: :lower,
      padding: false
    )
  end
end
