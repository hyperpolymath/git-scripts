defmodule ScriptManager.MDConverter do
  @moduledoc "MD to ADOC converter"

  def run do
    IO.puts("\n📄 MD TO ADOC CONVERTER")
    IO.puts("=======================")
    ScriptManager.ScriptRunner.run_script("md_to_adoc_converter.sh")
  end
end
