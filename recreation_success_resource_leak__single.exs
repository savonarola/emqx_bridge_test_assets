Mix.install([
  {:req, "~> 0.3"},
  {:emqtt, github: "emqx/emqtt", tag: "1.6.1", system_env: [{"BUILD_WITHOUT_QUIC", "1"}]}
])
Logger.configure(level: :info)

api_key = "b38b3d01d11cc0a0"
api_secret = "JnQ7KUpgs53rcL0Y8lKKrZn0tC6ai2B8ST6K9AeQhLhL"

create_bridge = %{
  "enable" => true,
  "command_template" => [
    "RPUSH",
    "msgs",
    "${payload}"
  ],
  "resource_opts" => %{
    "worker_pool_size" => 16,
    "health_check_interval" => "15s",
    "start_after_created" => true,
    "start_timeout" => "5s",
    "auto_restart_interval" => "60s",
    "query_mode" => "async",
    "request_timeout" => "15s",
    "async_inflight_window" => 100,
    "batch_size" => 10,
    "batch_time" => "20ms",
    "max_queue_bytes" => "100MB"
  },
  "server" => "127.0.0.1",
  "redis_type" => "single",
  "pool_size" => 8,
  "database" => 0,
  "ssl" => %{
    "enable" => false,
    "verify" => "verify_peer"
  },
  "type" => "redis_single",
  "name" => "test_single"
}

create_rule = %{
  "id" => "rule_test_single",
  "sql" => "SELECT\n  *\nFROM\n  \"t/#\"",
  "actions" => ["redis_single:test_single"],
  "description" => ""
}

req = Req.new(base_url: "http://localhost:18083")

n_loops = 1000
n_messages = 50


for n_loop <- 1..n_loops do

  IO.puts("iter #{n_loop}")

  Req.post!(
    req,
    url: "/api/v5/bridges",
    auth: {api_key, api_secret},
    json: create_bridge
  )

  Req.post!(
    req,
    url: "/api/v5/rules",
    auth: {api_key, api_secret},
    json: create_rule
  )


  {:ok, conn} = :emqtt.start_link()
  _ = :emqtt.connect(conn)

  for n_message <- 1..n_messages do
      {:ok, _} = :emqtt.publish(conn, "t/#{n_message}", "#{n_message}", 1)
      IO.write(".")
  end
  IO.puts("")
  :ok = :emqtt.stop(conn)

  Req.delete!(
    req,
    url: "/api/v5/rules/rule_test_single",
    auth: {api_key, api_secret}
  )
  # |> dbg()

  Req.delete!(
    req,
    url: "/api/v5/bridges/redis_single:test_single",
    auth: {api_key, api_secret}
  )
#  |> dbg()

end
