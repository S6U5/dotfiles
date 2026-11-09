# notify.sh から -EncodedCommand で渡され、Windows 側の PowerShell で実行される。
# HERDR_PLUGIN_EVENT_JSON(herdr の pane.agent_status_changed イベント)を読み、
# Windows のトースト通知を出す。
$ErrorActionPreference = 'Stop'

$payload = $env:HERDR_PLUGIN_EVENT_JSON | ConvertFrom-Json
$data = $payload.data
$status = $data.agent_status
if ($status -ne 'done' -and $status -ne 'blocked') { exit 0 }

# ターミナルを見ている間は herdr のアプリ内トーストに任せ、Windows の通知は出さない
# (ターミナルが最前面でないときだけ出す)。
if ($env:DOTFILES_HERDR_NOTIFY_TEST -ne '1') {
  Add-Type -Namespace DotfilesHerdrNotify -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@
  $foregroundPid = [uint32]0
  [void][DotfilesHerdrNotify.Win32]::GetWindowThreadProcessId(
    [DotfilesHerdrNotify.Win32]::GetForegroundWindow(), [ref]$foregroundPid)
  $foreground = Get-Process -Id $foregroundPid -ErrorAction SilentlyContinue
  if ($foreground -and @('wezterm-gui', 'WindowsTerminal') -contains $foreground.ProcessName) { exit 0 }
}

$agent = if ($data.display_agent) { $data.display_agent } elseif ($data.agent) { $data.agent } else { 'Agent' }
$heading = if ($status -eq 'blocked') { "$agent is waiting for input" } else { "$agent finished" }
$lines = @($heading)
if ($data.title) { $lines += $data.title }
$texts = ($lines | ForEach-Object { '<text>' + [System.Security.SecurityElement]::Escape([string]$_) + '</text>' }) -join ''

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml("<toast><visual><binding template=`"ToastGeneric`">$texts</binding></visual></toast>")
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
# 同じペインの通知は積み上げず置き換える
if ($data.pane_id) {
  $toast.Tag = ([string]$data.pane_id -replace '[^\w.-]', '_')
  $toast.Group = 'herdr'
}
# トーストの送信元には登録済みの AppUserModelID が必要なため、Windows PowerShell のものを借りる
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
