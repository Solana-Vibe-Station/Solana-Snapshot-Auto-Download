# Solana-Snapshot-Auto-Download
Solana Validator/RPC systemd service file script to auto download a snapshot from a custom RPC node of your choice.


## Usage
You will need to change the following variables in the script to match your enviroment
- SNAPSHOT_DIR (Your configured snapshot directory for your Solana node)
- RPC_NODE     (The RPC API URL where you want to download your snapshot from)
- LOG_FILE     (File to log output to)


Additionally, you will need to add the following lines to your systemd service file that manages your Solana node.
```
TimeoutStartSec=1800
TimeoutStopSec=300
ExecStartPre=/opt/Solana-Snapshot-Auto-Download/solana-snapshot-auto-download.sh
```

Make sure that the user who runs the the Solana systemd service also has ownsership and execution privileges for the solana-snapshot-auto-download.sh bash script.
