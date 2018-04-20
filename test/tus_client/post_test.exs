defmodule TusClient.PostTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Plug.Test

  alias TusClient.Post

  setup do
    bypass = Bypass.open()
    {:ok, path} = random_file()

    on_exit(fn ->
      File.rm!(path)
    end)

    {:ok, bypass: bypass, tmp_file: path}
  end

  test "request/1 201", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/foofile")
      |> resp(201, "")
    end)

    assert {:ok, %{location: endpoint_url(bypass.port) <> "/foofile"}} ==
             Post.request(url: endpoint_url(bypass.port), path: path)
  end

  test "request/1 missing location", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> resp(201, "")
    end)

    assert {:error, :location} ==
             Post.request(url: endpoint_url(bypass.port), path: path)
  end

  test "request/1 too large", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> resp(413, "")
    end)

    assert {:error, :too_large} ==
             Post.request(url: endpoint_url(bypass.port), path: path)
  end

  test "request/1 missing file", %{bypass: bypass} do
    assert {:error, :file_error} ==
             Post.request(
               url: endpoint_url(bypass.port),
               path: "/tmp/yaddayadda"
             )
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/files"

  defp assert_upload_len(conn) do
    len_hdr =
      conn
      |> get_req_header("upload-length")

    assert [len] = len_hdr
    assert String.to_integer(len) > 0
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
