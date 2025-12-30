defmodule Cli do
  def main(args) do
    message = Enum.join(args, " ")
    IO.puts("Running at: #{DateTime.utc_now()}")
    IO.puts("Message: #{message}")
    IO.puts("---")

    if message != "" do
      escaped_message = String.replace(message, "'", "'\\''")
      {output, status} = System.shell("claude -p '#{escaped_message}' --output-format text", close_stdin: true)
      IO.write(output)
      System.halt(status)
    else
      IO.puts("No message provided, skipping Claude")
    end
  end
end
