defmodule TusClientTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use Plug.Test

  alias TusClient

  setup do
    bypass = Bypass.open()
    {:ok, path} = random_file()

    cur_conf = Application.get_env(:tus_client, TusClient)
    Application.put_env(:tus_client, TusClient, chunk_len: 4)

    on_exit(fn ->
      File.rm!(path)
      Application.put_env(:tus_client, TusClient, cur_conf)
    end)

    {:ok, bypass: bypass, tmp_file: path}
  end

  test "upload/3", %{bypass: bypass, tmp_file: path} do
    fname = random_file_name()
    data = "yaddayaddamohmoh"
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/#{fname}")
      |> resp(201, "")
    end)

    {:ok, store_path} = random_file()

    Bypass.expect(bypass, "PATCH", "/files/#{fname}", fn conn ->
      {:ok, body, conn} = read_body(conn)
      File.write!(store_path, body, [:append])

      {:ok, %{size: new_offset}} = File.stat(store_path)

      conn
      |> put_resp_header("upload-offset", to_string(new_offset))
      |> resp(204, "")
    end)

    File.rm!(store_path)

    assert {:ok, _location} = TusClient.upload(endpoint_url(bypass.port), path)
  end

  test "upload/3 with custom headers", %{bypass: bypass, tmp_file: path} do
    fname = random_file_name()
    data = "yaddayaddamohmoh"
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      conn
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/#{fname}")
      |> resp(201, "")
    end)

    {:ok, store_path} = random_file()

    Bypass.expect(bypass, "PATCH", "/files/#{fname}", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      {:ok, body, conn} = read_body(conn)
      File.write!(store_path, body, [:append])

      {:ok, %{size: new_offset}} = File.stat(store_path)

      conn
      |> put_resp_header("upload-offset", to_string(new_offset))
      |> resp(204, "")
    end)

    File.rm!(store_path)

    assert {:ok, _location} =
             TusClient.upload(
               endpoint_url(bypass.port),
               path,
               headers: [{"foo", "bar"}]
             )
  end

  test "upload/3 with errors on patch", %{bypass: bypass, tmp_file: path} do
    fname = random_file_name()
    data = "yaddayaddamohmoh"
    :ok = File.write!(path, data)

    {:ok, agent} = Agent.start_link(fn -> 0 end, name: __MODULE__)
    {:ok, store_path} = random_file()

    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/#{fname}")
      |> resp(201, "")
    end)

    Bypass.expect(bypass, "PATCH", "/files/#{fname}", fn conn ->
      case Agent.get(agent, fn iter_nr -> iter_nr end) do
        0 ->
          # first time is ok
          Agent.update(agent, fn iter_nr -> iter_nr + 1 end)
          {:ok, body, conn} = read_body(conn)
          File.write!(store_path, body, [:append])

          {:ok, %{size: new_offset}} = File.stat(store_path)

          conn
          |> put_resp_header("upload-offset", to_string(new_offset))
          |> resp(204, "")

        1 ->
          # 2nd time error
          Agent.update(agent, fn iter_nr -> iter_nr + 1 end)

          conn
          |> resp(500, "")

        _ ->
          # then ok
          Agent.update(agent, fn iter_nr -> iter_nr + 1 end)
          {:ok, body, conn} = read_body(conn)
          File.write!(store_path, body, [:append])

          {:ok, %{size: new_offset}} = File.stat(store_path)

          conn
          |> put_resp_header("upload-offset", to_string(new_offset))
          |> resp(204, "")
      end
    end)

    File.rm!(store_path)

    assert {:ok, _location} = TusClient.upload(endpoint_url(bypass.port), path)
  end

  test "upload/3 with errors on patch and custom headers", %{
    bypass: bypass,
    tmp_file: path
  } do
    fname = random_file_name()
    data = "yaddayaddamohmoh"
    :ok = File.write!(path, data)

    {:ok, agent} = Agent.start_link(fn -> 0 end, name: __MODULE__)
    {:ok, store_path} = random_file()

    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      conn
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/#{fname}")
      |> resp(201, "")
    end)

    Bypass.expect(bypass, "PATCH", "/files/#{fname}", fn conn ->
      assert ["bar"] = get_req_header(conn, "foo")

      case Agent.get(agent, fn iter_nr -> iter_nr end) do
        0 ->
          # first time is ok
          Agent.update(agent, fn iter_nr -> iter_nr + 1 end)
          {:ok, body, conn} = read_body(conn)
          File.write!(store_path, body, [:append])

          {:ok, %{size: new_offset}} = File.stat(store_path)

          conn
          |> put_resp_header("upload-offset", to_string(new_offset))
          |> resp(204, "")

        1 ->
          # 2nd time error
          Agent.update(agent, fn iter_nr -> iter_nr + 1 end)

          conn
          |> resp(500, "")

        _ ->
          # then ok
          Agent.update(agent, fn iter_nr -> iter_nr + 1 end)
          {:ok, body, conn} = read_body(conn)
          File.write!(store_path, body, [:append])

          {:ok, %{size: new_offset}} = File.stat(store_path)

          conn
          |> put_resp_header("upload-offset", to_string(new_offset))
          |> resp(204, "")
      end
    end)

    File.rm!(store_path)

    assert {:ok, _location} =
             TusClient.upload(
               endpoint_url(bypass.port),
               path,
               headers: [{"foo", "bar"}]
             )
  end

  test "upload/3 too many errors", %{bypass: bypass, tmp_file: path} do
    fname = random_file_name()
    data = "yaddayaddamohmoh"
    :ok = File.write!(path, data)

    Bypass.expect_once(bypass, "OPTIONS", "/files", fn conn ->
      conn
      |> put_resp_header("tus-version", "1.0.0")
      |> put_resp_header("tus-max-size", "1234")
      |> put_resp_header("tus-extension", "creation,expiration")
      |> resp(200, "")
    end)

    Bypass.expect_once(bypass, "POST", "/files", fn conn ->
      conn
      |> put_resp_header("location", endpoint_url(bypass.port) <> "/#{fname}")
      |> resp(201, "")
    end)

    Bypass.expect(bypass, "PATCH", "/files/#{fname}", fn conn ->
      conn
      |> resp(500, "")
    end)

    assert {:error, :too_many_errors} =
             TusClient.upload(endpoint_url(bypass.port), path)
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/files"

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
