param (
    [string]$CacheDir = "$HOME/AppData/Local/nvim-plugins/"
)

# dein.vimのリポジトリURL
$deinRepoUrl = "https://github.com/Shougo/dein.vim"
$deinInstallPath = Join-Path $CacheDir "dein/repos/github.com/Shougo/dein.vim"

# キャッシュディレクトリが存在しない場合は作成
if (-not (Test-Path $CacheDir)) {
    Write-Host "Creating cache directory at $CacheDir"
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

# dein.vimがすでにインストールされているか確認
if (-not (Test-Path $deinInstallPath)) {
    Write-Host "Cloning dein.vim into $deinInstallPath"
    git clone $deinRepoUrl $deinInstallPath
} else {
    Write-Host "dein.vim is already installed at $deinInstallPath"
}

# runtimepathの設定はNeoVimのinit.vimで行う必要があります
Write-Host "`n✅ dein.vim installation complete."
Write-Host "📌 Please ensure your init.vim includes the correct runtimepath:"
Write-Host "    set runtimepath^=$deinInstallPath"
