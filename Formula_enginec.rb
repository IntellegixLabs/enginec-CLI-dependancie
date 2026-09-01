class Enginec < Formula
  desc "EngineC compiler - transpile .ec files to Lua"
  homepage "https://github.com/IntellegixLabs/enginec-CLI-dependancie"
  url "https://github.com/IntellegixLabs/enginec-CLI-dependancie/archive/refs/tags/v0.0.1.tar.gz"
  sha256 "9d8f8c6a6f2c1b5a4e3d2c1b0a9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f"
  license "MIT"

  depends_on "node"

  def install
    bin.install "cli/enginec"
    chmod 0755, bin/"enginec"
  end

  test do
    system bin/"enginec", "--help"
  end
end
