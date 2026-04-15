defmodule ScriptManager.MediaFinder do
  @moduledoc "Media repository finder using rclone generalized for any remote/path"

  @media_exts ~w(jpg jpeg png gif bmp webp tiff mp4 mkv mov avi flv wmv webm m4v mp3 wav flac aac ogg m4a)

  @doc "Run the media finder"
  def run do
    IO.puts("\n🎥 MEDIA FINDER")
    IO.puts("===============")
    
    IO.puts("[1] Scan top-level directories (gdrive:)")
    IO.puts("[2] Scan subdirectories (Dropbox residue, Dropbox-Archive, files, gaming)")
    IO.puts("[3] Custom Scan")
    IO.puts("[0] Back")
    
    IO.write("\nSelect option: ")
    choice = String.trim(IO.gets("") || "0")
    
    case choice do
      "1" -> find_media("gdrive:", false)
      "2" -> 
        dirs = ["Dropbox residue", "Dropbox-Archive", "files", "gaming"]
        Enum.each(dirs, fn dir -> find_media("gdrive:#{dir}", true) end)
      "3" -> 
        IO.write("Enter rclone remote/path (e.g. gdrive:): ")
        remote = String.trim(IO.gets("") || "")
        if remote != "", do: find_media(remote, true)
      "0" -> :back
      _ -> IO.puts("\nInvalid choice")
    end
  end

  def find_media(remote, _scan_subdirs) do
    IO.puts("\nScanning: #{remote}...")
    
    case list_dirs(remote) do
      {:ok, dirs} ->
        Enum.each(dirs, fn dir ->
          full_path = if String.ends_with?(remote, ":"), do: "#{remote}#{dir}", else: "#{remote}/#{dir}"
          check_directory(full_path)
        end)
      {:error, msg} -> IO.puts("Error: #{msg}")
    end
  end

  defp list_dirs(remote) do
    case System.cmd("rclone", ["lsd", remote]) do
      {output, 0} ->
        dirs = output
        |> String.split("\n", trim: true)
        |> Enum.map(fn line ->
          # rclone lsd output format: "          -1 2024-01-01 12:00:00        -1 dirname"
          # We take the part after the last space or fixed offset if available
          # Bash used: awk '{print substr($0, 44)}'
          if String.length(line) > 43 do
            String.slice(line, 43..-1//1) |> String.trim()
          else
            # Fallback if line is short
            line |> String.split() |> List.last()
          end
        end)
        {:ok, dirs}
      {_, code} -> {:error, "rclone lsd failed with code #{code}"}
    end
  end

  defp check_directory(path) do
    IO.write("  Checking #{path}... ")
    
    case System.cmd("rclone", ["lsf", "-R", path]) do
      {output, 0} ->
        files = String.split(output, "\n", trim: true)
        total_count = length(files)
        
        if total_count >= 5 do
          media_count = Enum.count(files, fn file ->
            ext = Path.extname(file) |> String.downcase() |> String.replace(".", "")
            ext in @media_exts
          end)
          
          ratio = if total_count > 0, do: media_count / total_count, else: 0
          
          if ratio > 0.95 do
            IO.puts(">>> FOUND MEDIA REPO: #{path} (Ratio: #{Float.round(ratio, 2)})")
            # Log to routing_dir
            routing_file = Path.join(ScriptManager.RepoHelper.routing_dir(), "found_media_repos.txt")
            File.write!(routing_file, "#{path} (Ratio: #{ratio})\n", [:append])
          else
            IO.puts("Total: #{total_count}, Media: #{media_count}, Ratio: #{Float.round(ratio, 2)}")
          end
        else
          IO.puts("Too few files (#{total_count})")
        end
        
      {_, code} -> IO.puts("Error: rclone lsf failed with code #{code}")
    end
  end
end
