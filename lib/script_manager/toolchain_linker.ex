defmodule ScriptManager.ToolchainLinker do
  @moduledoc "Manages symlinks for hyperpolymath language tools and compilers"

  @bin_dir Path.expand("~/.local/bin")
  
  @tools [
    %{
      name: "affinescript",
      source: "/var/mnt/eclipse/repos/nextgen-languages/affinescript/_build/default/bin/main.exe"
    },
    %{
      name: "ephapax",
      source: "/var/mnt/eclipse/repos/developer-ecosystem/nextgen-languages/ephapax/target/debug/ephapax"
    }
  ]

  @doc "Run the toolchain linker"
  def run do
    IO.puts("\n🔗 TOOLCHAIN LINKER")
    IO.puts("===================")
    
    File.mkdir_p!(@bin_dir)
    
    Enum.each(@tools, fn tool ->
      link_tool(tool)
    end)
    
    update_shell_config()
    
    IO.puts("\n✅ Toolchain setup complete!")
    IO.puts("To use in current session, run: export PATH=\"#{@bin_dir}:$PATH\"")
  end

  defp link_tool(%{name: name, source: source}) do
    IO.write("Linking #{name}... ")
    
    if File.exists?(source) do
      target = Path.join(@bin_dir, name)
      # Using System.cmd to handle symbolic linking with -f
      case System.cmd("ln", ["-sf", source, target]) do
        {_, 0} -> IO.puts("✅")
        {_, code} -> IO.puts("❌ (ln failed with code #{code})")
      end
    else
      IO.puts("❌ (Source not found: #{source})")
    end
  end

  defp update_shell_config do
    IO.puts("Updating shell configuration...")
    path_export = "export PATH=\"#{@bin_dir}:$PATH\""
    
    ["~/.bashrc", "~/.zshrc"]
    |> Enum.map(&Path.expand/1)
    |> Enum.each(fn rc_file ->
      if File.exists?(rc_file) do
        content = File.read!(rc_file)
        if !String.contains?(content, path_export) do
          File.write!(rc_file, content <> "\n" <> path_export <> "\n")
          IO.puts("  ✓ Added to #{Path.basename(rc_file)}")
        else
          IO.puts("  ✓ Already present in #{Path.basename(rc_file)}")
        end
      end
    end)
  end
end
