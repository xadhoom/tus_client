defmodule TusClient.HeadTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Plug.Test

  alias TusClient.Head

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "request/1 200", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("upload-offset", "0")
      |> put_resp_header("upload-length", "1234")
      |> put_resp_header("cache-control", "no-store")
      |> resp(200, "")
    end)

    assert {:ok, %{upload_offset: 0, upload_length: 1234}} =
             Head.request(file_url(bypass.port))
  end

  test "request/1 200, with custom headers", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      conn
      |> put_resp_header("upload-offset", "0")
      |> put_resp_header("upload-length", "1234")
      |> put_resp_header("cache-control", "no-store")
      |> resp(200, "")
    end)

    assert {:ok, %{upload_offset: 0, upload_length: 1234}} =
             Head.request(file_url(bypass.port), [{"foo", "bar"}])
  end

  test "request/1 200, without len", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("upload-offset", "0")
      |> put_resp_header("cache-control", "no-store")
      |> resp(200, "")
    end)

    assert {:ok, %{upload_offset: 0, upload_length: nil}} =
             Head.request(file_url(bypass.port))
  end

  test "request/1 offset is mandatory", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("upload-length", "1234")
      |> put_resp_header("cache-control", "no-store")
      |> resp(200, "")
    end)

    assert {:error, :preconditions} = Head.request(file_url(bypass.port))
  end

  test "request/1 cache control is mandatory", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("upload-offset", "0")
      |> put_resp_header("upload-length", "1234")
      |> resp(200, "")
    end)

    assert {:error, :preconditions} = Head.request(file_url(bypass.port))
  end

  test "request/1 403", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("cache-control", "no-store")
      |> resp(403, "")
    end)

    assert {:error, :not_found} = Head.request(file_url(bypass.port))
  end

  test "request/1 404", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("cache-control", "no-store")
      |> resp(404, "")
    end)

    assert {:error, :not_found} = Head.request(file_url(bypass.port))
  end

  test "request/1 410", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header("cache-control", "no-store")
      |> resp(410, "")
    end)

    assert {:error, :not_found} = Head.request(file_url(bypass.port))
  end

  test "request/1 302", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/files/foobar", fn conn ->
      conn
      |> put_resp_header(
        "location",
        "http://localhost:#{bypass.port}/somewhere/foobar"
      )
      |> resp(302, "")
    end)

    Bypass.expect_once(bypass, "HEAD", "/somewhere/foobar", fn conn ->
      conn
      |> put_resp_header("upload-offset", "0")
      |> put_resp_header("upload-length", "1234")
      |> put_resp_header("cache-control", "no-store")
      |> resp(200, "")
    end)

    assert {:ok, %{upload_offset: 0, upload_length: 1234}} =
             Head.request(file_url(bypass.port), [], follow_redirect: true)
  end

  defp file_url(port), do: endpoint_url(port) <> "/foobar"
  defp endpoint_url(port), do: "http://localhost:#{port}/files"
end
