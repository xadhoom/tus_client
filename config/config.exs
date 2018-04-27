use Mix.Config

config :tus_client, TusClient,
  # 4 MiB
  chunk_len: 4_194_304,
  max_retries: 3

import_config "#{Mix.env()}.exs"
