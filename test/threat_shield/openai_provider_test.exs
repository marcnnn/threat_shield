defmodule ThreatShield.OpenAIProviderTest do
  # Runs the OpenAI provider of the library over HTTP against a local fake of the chat
  # completion API. It covers the HTTP client stack (openai, httpoison, hackney) that the
  # other tests replace with the stub provider.
  use ExUnit.Case, async: false

  alias AshThreatShield.AI.Providers.OpenAI, as: Provider

  defmodule FakeOpenAI do
    @moduledoc false
    use Plug.Router

    plug :match
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug :dispatch

    post "/v1/chat/completions" do
      case get_req_header(conn, "authorization") do
        ["Bearer valid-key"] ->
          [%{"content" => content} | _] = conn.body_params["messages"]

          body = %{
            "model" => conn.body_params["model"],
            "choices" => [
              %{"message" => %{"role" => "assistant", "content" => "echo: " <> content}}
            ]
          }

          send_json(conn, 200, body)

        _ ->
          send_json(conn, 401, %{"error" => %{"message" => "Incorrect API key provided"}})
      end
    end

    defp send_json(conn, status, body) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, Jason.encode!(body))
    end
  end

  setup do
    {:ok, _} = Plug.Cowboy.http(FakeOpenAI, [], port: 0, ref: __MODULE__)
    port = :ranch.get_port(__MODULE__)

    previous = Application.get_all_env(:openai)
    Application.put_env(:openai, :api_url, "http://localhost:#{port}")

    on_exit(fn ->
      Plug.Cowboy.shutdown(__MODULE__)
      Application.delete_env(:openai, :api_url)
      Application.delete_env(:openai, :api_key)
      for {key, value} <- previous, do: Application.put_env(:openai, key, value)
    end)
  end

  test "returns the content of the answer" do
    Application.put_env(:openai, :api_key, "valid-key")

    assert {:ok, "echo: hello"} =
             Provider.chat([%{role: "user", content: "hello"}], model: "test-model")
  end

  test "returns the error of the API" do
    Application.put_env(:openai, :api_key, "wrong-key")

    assert {:error, %{"message" => "Incorrect API key provided"}} =
             Provider.chat([%{role: "user", content: "hello"}])
  end
end
