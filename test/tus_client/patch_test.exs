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
      protocol_assertions(conn)

      {:ok, body, conn} = read_body(conn)
      assert data == body

      len = data |> String.length() |> to_string()

      conn
      |> put_resp_header("upload-offset", len)
      |> resp(204, "")
    end)

    assert {:ok, String.length(data)} ==
             Patch.request(
               endpoint_url(bypass.port, "#{filen}"),
               0,
               path
             )
  end

  test "request/3 204 with custom headers", %{bypass: bypass, tmp_file: path} do
    data = "yaddayaddamohmoh"
    filen = random_file_name()
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "PATCH", "/files/#{filen}", fn conn ->
      protocol_assertions(conn)

      assert ["bar"] = get_req_header(conn, "foo")

      {:ok, body, conn} = read_body(conn)
      assert data == body

      len = data |> String.length() |> to_string()

      conn
      |> put_resp_header("upload-offset", len)
      |> resp(204, "")
    end)

    assert {:ok, String.length(data)} ==
             Patch.request(endpoint_url(bypass.port, "#{filen}"), 0, path, [
               {"foo", "bar"}
             ])
  end

  test "request/3 204 from offset", %{bypass: bypass, tmp_file: path} do
    data = "yaddayaddamohmoh"
    filen = random_file_name()
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "PATCH", "/files/#{filen}", fn conn ->
      protocol_assertions(conn)

      {:ok, body, conn} = read_body(conn)
      # we're sending only last 3 chars, from a 16 len
      assert body == "moh"

      len = data |> String.length() |> to_string()

      conn
      |> put_resp_header("upload-offset", len)
      |> resp(204, "")
    end)

    assert {:ok, String.length(data)} ==
             Patch.request(
               endpoint_url(bypass.port, "#{filen}"),
               13,
               path
             )
  end

  test "request/3 unexpected status code", %{bypass: bypass, tmp_file: path} do
    filen = random_file_name()

    Bypass.expect_once(bypass, "PATCH", "/files/#{filen}", fn conn ->
      protocol_assertions(conn)

      conn
      |> resp(412, "")
    end)

    assert {:error, :generic} ==
             Patch.request(
               endpoint_url(bypass.port, "#{filen}"),
               0,
               path
             )
  end

  test "request/3 204 eof", %{bypass: bypass, tmp_file: path} do
    filen = random_file_name()

    assert {:error, :eof} =
             Patch.request(
               endpoint_url(bypass.port, "#{filen}"),
               13,
               path
             )
  end

  test "request/3 204 nofile", %{bypass: bypass, tmp_file: _path} do
    filen = random_file_name()

    assert {:error, :file_error} =
             Patch.request(
               endpoint_url(bypass.port, "#{filen}"),
               13,
               "foobar"
             )
  end

  test "request/3 204 transport error", %{bypass: _bypass, tmp_file: path} do
    filen = random_file_name()

    assert {:error, :transport} =
             Patch.request(
               endpoint_url(0, "#{filen}"),
               0,
               path
             )
  end

  defp endpoint_url(port, fname), do: "http://localhost:#{port}/files/#{fname}"

  defp protocol_assertions(conn) do
    conn
    |> assert_version()
    |> assert_content_type()
    |> assert_upload_offset()
  end

  defp assert_version(conn) do
    assert get_req_header(conn, "tus-resumable") == ["1.0.0"]
    conn
  end

  defp assert_upload_offset(conn) do
    assert [v] = get_req_header(conn, "upload-offset")
    assert String.to_integer(v) >= 0
    conn
  end

  defp assert_content_type(conn) do
    assert get_req_header(conn, "content-type") == [
             "application/offset+octet-stream"
           ]

    conn
  end

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
