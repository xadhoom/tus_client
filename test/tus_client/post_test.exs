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
      |> assert_version()
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/foofile")
      |> resp(201, "")
    end)

    assert {:ok, %{location: endpoint_url(bypass.port) <> "/foofile"}} ==
             Post.request(endpoint_url(bypass.port), path)
  end

  test "request/1 with metadata", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> assert_version()
      |> assert_metadata()
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/foofile")
      |> resp(201, "")
    end)

    assert {:ok, %{location: endpoint_url(bypass.port) <> "/foofile"}} ==
             Post.request(
               endpoint_url(bypass.port),
               path,
               metadata: %{"foo" => "bar"}
             )
  end

  test "request/1 invalid key in metadata", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> assert_version()
      |> refute_metadata()
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/foofile")
      |> resp(201, "")
    end)

    assert {:ok, %{location: endpoint_url(bypass.port) <> "/foofile"}} ==
             Post.request(
               endpoint_url(bypass.port),
               path,
               metadata: %{"foo!" => "bar"}
             )
  end

  test "request/1 with empty metadata", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> assert_version()
      |> refute_metadata()
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/foofile")
      |> resp(201, "")
    end)

    assert {:ok, %{location: endpoint_url(bypass.port) <> "/foofile"}} ==
             Post.request(
               endpoint_url(bypass.port),
               path,
               metadata: %{}
             )
  end

  test "request/1 missing location", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> resp(201, "")
    end)

    assert {:error, :location} == Post.request(endpoint_url(bypass.port), path)
  end

  test "request/1 too large", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> assert_upload_len()
      |> resp(413, "")
    end)

    assert {:error, :too_large} == Post.request(endpoint_url(bypass.port), path)
  end

  test "request/1 missing file", %{bypass: bypass} do
    assert {:error, :file_error} ==
             Post.request(
               endpoint_url(bypass.port),
               "/tmp/yaddayadda"
             )
  end

  test "request/1 unexpected status code", %{bypass: bypass, tmp_file: path} do
    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> resp(500, "")
    end)

    assert {:error, :generic} == Post.request(endpoint_url(bypass.port), path)
  end

  test "request/1 transport error", %{bypass: _bypass, tmp_file: path} do
    assert {:error, :transport} == Post.request(endpoint_url(0), path)
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

  defp assert_version(conn) do
    assert get_req_header(conn, "tus-resumable") == ["1.0.0"]
    conn
  end

  defp assert_metadata(conn) do
    assert [md] = get_req_header(conn, "upload-metadata")
    assert valid_metadata?(md)
    conn
  end

  defp refute_metadata(conn) do
    assert [] = get_req_header(conn, "upload-metadata")
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

  defp valid_metadata?(metadata) when is_binary(metadata) do
    split =
      metadata
      |> String.trim()
      |> String.split(",")
      |> Enum.map(fn kv -> kv |> String.trim() end)

    split
    |> Enum.all?(fn kv ->
      kv =~ ~r/^[a-z|A-Z|0-9]+ [a-z|A-Z|0-9|=|\/|\+]+$/
    end)
    |> case do
      false ->
        false

      true ->
        split
        |> Enum.map(fn kv ->
          kv
          |> String.split(" ")
          |> List.to_tuple()
        end)
        |> Enum.all?(fn {_k, v} ->
          case Base.decode64(v) do
            {:ok, _} -> true
            _ -> false
          end
        end)
    end
  end
end
